import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      setupAudioFocusHandler(messenger: controller.binaryMessenger)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func setupAudioFocusHandler(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "com.filehub/audio_focus",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { (call, result) in
      if call.method == "hasOtherAudio" {
        result(AVAudioSession.sharedInstance().secondaryAudioShouldBeSilencedHint)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    do {
      try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
      try AVAudioSession.sharedInstance().setActive(true)
    } catch { }
  }
}
