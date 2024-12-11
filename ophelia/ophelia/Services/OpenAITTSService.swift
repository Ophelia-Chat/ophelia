//
//  OpenAITTSService.swift
//  ophelia
//

import Foundation
import AVFoundation

public final class OpenAITTSService: NSObject, VoiceServiceProtocol {
    private var apiKey: String
    private var voiceId: String
    private let baseURL = "https://api.openai.com/v1/audio/speech"

    private var player: AVAudioPlayer?
    private let audioSession = AVAudioSession.sharedInstance()
    private var isAudioSessionActive = false
    private var audioDelegate: AudioPlayerDelegate?

    private var currentTask: Task<Void, Error>?
    private var state: PlaybackState = .idle

    private let maxRetries = 3
    private let initialBackoff: UInt64 = 500_000_000 // 0.5s

    private enum PlaybackState: String {
        case idle, preparing, playing, cancelled
    }

    public init(apiKey: String, voiceId: String = "alloy") {
        self.apiKey = apiKey
        self.voiceId = voiceId
        super.init()
        setupAudioSession()
        setupNotifications()
    }

    public func updateVoice(_ newVoiceId: String) {
        self.voiceId = newVoiceId
    }

    public func speak(_ text: String) async throws {
        guard !text.isEmpty else { return }

        // Stop any existing playback if needed
        await stopOnMain()

        state = .preparing
        let task = Task {
            do {
                let audioData = try await fetchAudioWithRetries(for: text)
                try await playAudioData(audioData)
            } catch {
                print("[OpenAITTS] OpenAI TTS failed after retries: \(error)")
                // Fallback to system voice
                let systemService = SystemVoiceService(voiceIdentifier: VoiceHelper.getDefaultVoiceIdentifier())
                try await systemService.speak(text)
            }
        }

        currentTask = task
        try await task.value
    }

    public nonisolated func stop() {
        Task { @MainActor in
            stopOnMain()
        }
    }

    @MainActor
    private func stopOnMain() {
        state = .cancelled
        currentTask?.cancel()
        currentTask = nil
        cleanup()
    }

    private func cleanup() {
        player?.stop()
        player = nil
        audioDelegate = nil

        if isAudioSessionActive {
            try? audioSession.setActive(false)
            isAudioSessionActive = false
        }

        state = .idle
    }

    private func setupAudioSession() {
        do {
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        } catch {
            print("[OpenAITTS] Failed to configure audio session: \(error)")
        }
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: audioSession
        )
    }

    private func fetchAudioWithRetries(for text: String) async throws -> Data {
        var attempt = 0
        var backoff = initialBackoff

        while attempt < maxRetries {
            do {
                let data = try await fetchAudioData(for: text)
                return data
            } catch let error as VoiceError {
                // Check if error is transient
                if shouldRetry(error: error) && attempt < maxRetries - 1 {
                    attempt += 1
                    try await Task.sleep(nanoseconds: backoff)
                    backoff *= 2
                } else {
                    throw error
                }
            } catch {
                // Non-VoiceError error, not retrying
                throw error
            }
        }

        throw VoiceError.serverError("Failed after \(maxRetries) attempts.")
    }

    private func shouldRetry(error: VoiceError) -> Bool {
        switch error {
        case .rateLimitExceeded, .invalidResponse, .serverError:
            // Treat as transient
            return true
        default:
            return false
        }
    }

    private func fetchAudioData(for text: String) async throws -> Data {
        guard let url = URL(string: baseURL) else {
            throw VoiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "model": "tts-1",
            "voice": voiceId,
            "input": text,
            "response_format": "mp3"
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw VoiceError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            guard !data.isEmpty else { throw VoiceError.invalidAudioData }
            return data
        case 401:
            throw VoiceError.unauthorized
        case 429:
            throw VoiceError.rateLimitExceeded
        default:
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw VoiceError.serverError("Status: \(httpResponse.statusCode), \(errorMessage)")
        }
    }

    private func playAudioData(_ audioData: Data) async throws {
        guard state == .preparing else { return }

        try audioSession.setActive(true)
        isAudioSessionActive = true

        let player = try AVAudioPlayer(data: audioData)
        self.player = player

        let delegate = AudioPlayerDelegate { [weak self] success in
            Task { @MainActor in
                guard let self = self else { return }
                self.state = success ? .idle : .cancelled
                self.cleanup()
            }
        }

        self.audioDelegate = delegate
        player.delegate = delegate

        guard player.prepareToPlay() else {
            throw VoiceError.playbackFailed
        }

        state = .playing
        guard player.play() else {
            state = .idle
            throw VoiceError.playbackFailed
        }

        // Poll until finished or cancelled
        while player.isPlaying && state == .playing {
            try await Task.sleep(nanoseconds: 100_000_000)
        }

        if state == .cancelled {
            throw VoiceError.cancelled
        }
    }

    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        Task { @MainActor in
            handleInterruptionOnMain(type: type, options: userInfo[AVAudioSessionInterruptionOptionKey].flatMap {
                AVAudioSession.InterruptionOptions(rawValue: $0 as? UInt ?? 0)
            })
        }
    }

    @MainActor
    private func handleInterruptionOnMain(type: AVAudioSession.InterruptionType, options: AVAudioSession.InterruptionOptions?) {
        switch type {
        case .began:
            print("[OpenAITTS] Audio session interrupted")
            stopOnMain()
        case .ended:
            if let options = options, options.contains(.shouldResume), state == .playing {
                player?.play()
            }
        @unknown default:
            break
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.stopOnMain()
            }
    }
}

private final class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    private let onComplete: (Bool) -> Void

    init(onComplete: @escaping (Bool) -> Void) {
        self.onComplete = onComplete
        super.init()
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onComplete(flag)
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("[OpenAITTS] Playback error: \(error?.localizedDescription ?? "unknown")")
        onComplete(false)
    }
}
