import Flutter
import AVFoundation

class AudioFocusHandler {
    private var isInterrupted = false

    init(messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(
            name: "com.filehub/audio_focus",
            binaryMessenger: messenger
        )

        channel.setMethodCallHandler { [weak self] (call, result) in
            guard let self = self else {
                result(FlutterMethodNotImplemented)
                return
            }
            if call.method == "hasOtherAudio" {
                result(self.hasOtherAudio())
            } else {
                result(FlutterMethodNotImplemented)
            }
        }

        // Listen for audio session interruptions
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )

        // Activate audio session
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Audio session setup failed
        }
    }

    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            isInterrupted = true
        case .ended:
            isInterrupted = false
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    isInterrupted = false
                }
            }
        @unknown default:
            break
        }
    }

    private func hasOtherAudio() -> Bool {
        if isInterrupted { return true }
        return AVAudioSession.sharedInstance().secondaryAudioShouldBeSilencedHint
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
