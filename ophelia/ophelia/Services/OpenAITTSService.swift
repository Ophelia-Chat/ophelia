//
//  OpenAITTSService.swift
//  ophelia
//
//  Created by rob on 2024-11-27.
//

import Foundation
import AVFoundation

// Ensure you import the protocol and error definitions
// If these are in another module, adjust the import statements accordingly
// import YourModuleName

@MainActor
public final class OpenAITTSService: NSObject, VoiceServiceProtocol {
    // MARK: - Properties

    private let apiKey: String
    private var voiceId: String {
        didSet {
            print("[OpenAITTS] Voice updated to: \(voiceId)")
        }
    }
    private let baseURL = "https://api.openai.com/v1/audio/speech"

    // Audio playback state management
    private var player: AVAudioPlayer?
    private let audioSession = AVAudioSession.sharedInstance()
    private var isAudioSessionActive = false
    private var audioDelegate: AudioPlayerDelegate?

    // Task management for concurrent operations
    private var currentTask: Task<Void, Error>?
    private var state: PlaybackState = .idle

    private enum PlaybackState: String {
        case idle, preparing, playing, cancelled
    }

    // MARK: - Initialization

    public init(apiKey: String, voiceId: String = "alloy") {
        self.apiKey = apiKey
        self.voiceId = voiceId
        super.init()

        setupAudioSession()
        setupNotifications()
        print("[OpenAITTS] Service initialized with voice ID: \(voiceId)")
    }

    private func setupAudioSession() {
        do {
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            print("[OpenAITTS] Audio session configured successfully")
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

    // MARK: - Public Interface

    public func speak(_ text: String) async throws {
        guard !text.isEmpty else {
            print("[OpenAITTS] Empty text provided, ignoring request")
            return
        }

        print("[OpenAITTS] Starting speech for: \(text.prefix(50))...")

        // Stop any existing playback
        stopOnMain()
        try? await currentTask?.value

        state = .preparing
        let task = Task { @MainActor in
            try await playText(text)
        }
        currentTask = task
        try await task.value
    }

    public func updateVoice(_ newVoiceId: String) {
        self.voiceId = newVoiceId
    }

    public func stop() {
        Task { @MainActor in
            stopOnMain()
        }
    }

    // MARK: - Private Implementation

    @MainActor
    private func stopOnMain() {
        state = .cancelled
        currentTask?.cancel()
        Task {
            try? await cleanup()
        }
    }

    private func playText(_ text: String) async throws {
        guard state == .preparing else {
            print("[OpenAITTS] Invalid state for playback: \(state)")
            return
        }

        // Configure audio session
        try audioSession.setActive(true)
        isAudioSessionActive = true
        print("[OpenAITTS] Audio session activated")

        // Fetch and validate audio data
        let audioData = try await fetchAudioData(for: text)
        guard !audioData.isEmpty else {
            throw OpenAIVoiceError.invalidAudioData
        }

        guard state == .preparing else { return }

        // Initialize player with audio data
        let player = try AVAudioPlayer(data: audioData)
        self.player = player

        let delegate = AudioPlayerDelegate { [weak self] success in
            Task { @MainActor in
                guard let self else { return }
                self.state = success ? .idle : .cancelled
                try? await self.cleanup()
            }
        }

        self.audioDelegate = delegate
        player.delegate = delegate

        guard player.prepareToPlay() else {
            throw OpenAIVoiceError.playbackFailed
        }

        state = .playing
        guard player.play() else {
            state = .idle
            throw OpenAIVoiceError.playbackFailed
        }

        print("[OpenAITTS] Playback started")

        // Wait for playback to finish or be cancelled
        while player.isPlaying && state == .playing {
            try await Task.sleep(nanoseconds: 100_000_000) // Sleep for 0.1 seconds
        }

        if state == .cancelled {
            throw OpenAIVoiceError.cancelled
        }
    }

    private func cleanup() async throws {
        player?.stop()
        player = nil
        audioDelegate = nil

        if isAudioSessionActive {
            try audioSession.setActive(false)
            isAudioSessionActive = false
        }

        state = .idle
        print("[OpenAITTS] Cleanup completed")
    }

    private func fetchAudioData(for text: String) async throws -> Data {
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "model": "tts-1",
            "voice": voiceId,
            "input": text,
            "response_format": "mp3" // Default format, can be changed if needed
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        print("[OpenAITTS] Sending request to OpenAI TTS API...")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIVoiceError.invalidResponse
        }

        print("[OpenAITTS] Received response with status code: \(httpResponse.statusCode)")

        switch httpResponse.statusCode {
        case 200:
            return data
        case 401:
            print("[OpenAITTS] Authentication failed")
            throw OpenAIVoiceError.unauthorized
        case 429:
            print("[OpenAITTS] Rate limit exceeded")
            throw OpenAIVoiceError.rateLimitExceeded
        default:
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("[OpenAITTS] Server error: \(errorMessage)")
            throw OpenAIVoiceError.serverError("Status: \(httpResponse.statusCode), Message: \(errorMessage)")
        }
    }

    // MARK: - Interruption Handling

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
            if let options = options, options.contains(.shouldResume) {
                print("[OpenAITTS] Resuming playback after interruption")
                player?.play()
            }
        @unknown default:
            break
        }
    }

    deinit {
        print("[OpenAITTS] Service being deinitialized")
        NotificationCenter.default.removeObserver(self)
        let stopOnMain = self.stopOnMain
        Task { @MainActor in
            stopOnMain()
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
        print("[OpenAITTS] Playback completed successfully: \(flag)")
        onComplete(flag)
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("[OpenAITTS] Playback error occurred: \(error?.localizedDescription ?? "unknown error")")
        onComplete(false)
    }
}
