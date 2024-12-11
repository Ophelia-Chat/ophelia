//
//  VoiceService.swift
//  ophelia
//

import Foundation
import AVFoundation

public enum VoiceProvider: String, Codable, CaseIterable, Identifiable {
    case system = "System"
    case openAI = "OpenAI"
    public var id: String { rawValue }
}

public enum VoiceError: LocalizedError {
    case voiceNotFound
    case invalidURL
    case invalidRequest
    case invalidResponse
    case unauthorized
    case rateLimitExceeded
    case serverError(String)
    case playbackFailed
    case cancelled
    case invalidAudioData

    public var errorDescription: String? {
        switch self {
        case .voiceNotFound:
            return "Selected voice not found."
        case .invalidURL:
            return "Invalid URL configuration."
        case .invalidRequest:
            return "Invalid request configuration."
        case .invalidResponse:
            return "Invalid response from server."
        case .unauthorized:
            return "Invalid API key."
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please try again later."
        case .serverError(let message):
            return "Server error: \(message)"
        case .playbackFailed:
            return "Failed to play audio."
        case .cancelled:
            return "Speech was cancelled."
        case .invalidAudioData:
            return "Received invalid or empty audio data."
        }
    }
}

public protocol VoiceServiceProtocol: AnyObject {
    nonisolated func stop()
    func speak(_ text: String) async throws
}

public enum VoiceHelper {
    public static func getDefaultVoiceIdentifier() -> String {
        let preferredLanguages = ["en-US", "en-GB", "en-AU"]
        for language in preferredLanguages {
            if let voice = AVSpeechSynthesisVoice(language: language) {
                return voice.identifier
            }
        }
        return AVSpeechSynthesisVoice.speechVoices().first?.identifier ?? ""
    }

    public static func isValidVoiceIdentifier(_ identifier: String) -> Bool {
        return AVSpeechSynthesisVoice(identifier: identifier) != nil
    }

    public static func getAvailableVoices() -> [AVSpeechSynthesisVoice] {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        let englishVoices = allVoices.filter { $0.language.starts(with: "en") }.sorted { v1, v2 in
            if v1.quality != v2.quality {
                return v1.quality.rawValue > v2.quality.rawValue
            }
            return v1.language < v2.language
        }
        return !englishVoices.isEmpty ? englishVoices : allVoices
    }

    public static func voiceDisplayName(for voice: AVSpeechSynthesisVoice) -> String {
        let quality = voice.quality == .enhanced ? " (Enhanced)" : ""
        return "\(voice.name)\(quality) - \(voice.language)"
    }
}

// Note: Not marking SystemVoiceService as @MainActor because AVSpeechSynthesizerDelegate is non-isolated.
// We'll dispatch main-actor tasks inside delegate methods as needed.
public final class SystemVoiceService: NSObject, VoiceServiceProtocol, @unchecked Sendable {
    private let synthesizer: AVSpeechSynthesizer
    private var currentVoice: AVSpeechSynthesisVoice?
    private var continuation: CheckedContinuation<Void, Error>?
    private var isCancelled = false
    private let audioSession = AVAudioSession.sharedInstance()

    public init(voiceIdentifier: String) {
        self.synthesizer = AVSpeechSynthesizer()
        super.init()
        self.synthesizer.delegate = self
        updateCurrentVoice(voiceIdentifier: voiceIdentifier)

        do {
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try audioSession.setActive(true)
        } catch {
            print("Failed to setup audio session for system voice: \(error.localizedDescription)")
        }
    }

    public func speak(_ text: String) async throws {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard let voice = currentVoice else {
            throw VoiceError.voiceNotFound
        }

        await stopSpeaking()
        return try await withCheckedThrowingContinuation { continuation in
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = voice
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate
            utterance.pitchMultiplier = 1.0
            utterance.volume = 1.0
            utterance.preUtteranceDelay = 0.1
            utterance.postUtteranceDelay = 0.2

            self.continuation = continuation
            self.isCancelled = false
            synthesizer.speak(utterance)
        }
    }

    public nonisolated func stop() {
        Task { [weak self] in
            await self?.stopSpeaking()
        }
    }

    private func updateCurrentVoice(voiceIdentifier: String) {
        if let voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier) {
            currentVoice = voice
        } else if let defaultVoice = VoiceHelper.getAvailableVoices().first {
            print("Requested voice not found, using default: \(VoiceHelper.voiceDisplayName(for: defaultVoice))")
            currentVoice = defaultVoice
        }
    }

    @MainActor
    private func stopSpeaking() {
        guard synthesizer.isSpeaking else { return }
        isCancelled = true
        synthesizer.stopSpeaking(at: .immediate)
        if let continuation = continuation {
            self.continuation = nil
            continuation.resume(throwing: VoiceError.cancelled)
        }
    }

    deinit {
        Task { @MainActor [audioSession] in
            try? audioSession.setActive(false)
        }
    }
}

extension SystemVoiceService: AVSpeechSynthesizerDelegate {
    // Delegate methods are nonisolated; we'll dispatch main tasks if needed.
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        if isCancelled { return }
        if let continuation = continuation {
            continuation.resume()
            self.continuation = nil
        }
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        if isCancelled { return }
        if let continuation = continuation {
            continuation.resume(throwing: VoiceError.playbackFailed)
            self.continuation = nil
        }
    }
}
