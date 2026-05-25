#include "audio_session_monitor.h"
#include <windows.h>
#include <mmdeviceapi.h>
#include <audiopolicy.h>
#include <endpointvolume.h>
#include <objbase.h>
#include <flutter/standard_method_codec.h>

AudioSessionMonitor::AudioSessionMonitor(flutter::BinaryMessenger* messenger)
    : channel_(std::make_unique<flutter::MethodChannel<>>(
          messenger, "com.filehub/audio_focus",
          &flutter::StandardMethodCodec::GetInstance())) {
  channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) { HandleMethodCall(call, std::move(result)); });
}

AudioSessionMonitor::~AudioSessionMonitor() = default;

void AudioSessionMonitor::HandleMethodCall(
    const flutter::MethodCall<>& call,
    std::unique_ptr<flutter::MethodResult<>> result) {
  if (call.method_name() == "hasOtherAudio") {
    result->Success(HasOtherAudioPlaying());
  } else {
    result->NotImplemented();
  }
}

bool AudioSessionMonitor::HasOtherAudioPlaying() {
  bool comInitialized = SUCCEEDED(CoInitializeEx(nullptr, COINIT_MULTITHREADED));
  bool result = false;

  IMMDeviceEnumerator* enumerator = nullptr;
  HRESULT hr = CoCreateInstance(
      __uuidof(MMDeviceEnumerator), nullptr, CLSCTX_ALL,
      __uuidof(IMMDeviceEnumerator), (void**)&enumerator);
  if (FAILED(hr)) goto cleanup;

  {
    IMMDevice* device = nullptr;
    hr = enumerator->GetDefaultAudioEndpoint(eRender, eConsole, &device);
    enumerator->Release();
    enumerator = nullptr;
    if (FAILED(hr)) goto cleanup;

    IAudioSessionManager2* sessionManager = nullptr;
    hr = device->Activate(__uuidof(IAudioSessionManager2), CLSCTX_ALL,
        nullptr, (void**)&sessionManager);
    device->Release();
    if (FAILED(hr)) goto cleanup;

    IAudioSessionEnumerator* sessionList = nullptr;
    hr = sessionManager->GetSessionEnumerator(&sessionList);
    sessionManager->Release();
    if (FAILED(hr)) goto cleanup;

    int count = 0;
    sessionList->GetCount(&count);

    DWORD ourPid = GetCurrentProcessId();

    for (int i = 0; i < count; i++) {
      IAudioSessionControl* sessionControl = nullptr;
      hr = sessionList->GetSession(i, &sessionControl);
      if (FAILED(hr)) continue;

      IAudioSessionControl2* sessionControl2 = nullptr;
      hr = sessionControl->QueryInterface(__uuidof(IAudioSessionControl2),
          (void**)&sessionControl2);
      sessionControl->Release();
      if (FAILED(hr)) continue;

      DWORD pid = 0;
      sessionControl2->GetProcessId(&pid);

      if (pid != 0 && pid != ourPid) {
        // Check actual audio output via peak meter (more reliable than session state)
        IAudioMeterInformation* meter = nullptr;
        hr = sessionControl2->QueryInterface(__uuidof(IAudioMeterInformation),
            (void**)&meter);
        if (SUCCEEDED(hr) && meter) {
          float peak = 0;
          meter->GetPeakValue(&peak);
          if (peak > 0.01f) {
            meter->Release();
            sessionControl2->Release();
            result = true;
            break;
          }
          meter->Release();
        }
      }

      sessionControl2->Release();
    }

    sessionList->Release();
  }

cleanup:
  if (comInitialized) CoUninitialize();
  return result;
}
