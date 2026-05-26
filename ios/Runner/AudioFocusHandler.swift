import Flutter
import AVFoundation

class AudioFocusHandler {

    init(messenger: FlutterBinaryMessenger) {
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

        // Activate audio session
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Audio session setup failed
        }
    }
}
