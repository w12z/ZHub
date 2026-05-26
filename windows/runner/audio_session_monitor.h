#ifndef RUNNER_AUDIO_SESSION_MONITOR_H_
#define RUNNER_AUDIO_SESSION_MONITOR_H_

#include <flutter/method_channel.h>
#include <memory>

class AudioSessionMonitor {
 public:
  explicit AudioSessionMonitor(flutter::BinaryMessenger* messenger);
  ~AudioSessionMonitor();

 private:
  void HandleMethodCall(
      const flutter::MethodCall<>& call,
      std::unique_ptr<flutter::MethodResult<>> result);
  bool HasOtherAudioPlaying();

  std::unique_ptr<flutter::MethodChannel<>> channel_;
};

#endif
