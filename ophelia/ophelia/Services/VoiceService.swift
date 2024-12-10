//
//  VoiceService.swift
//  ophelia
//
//  Created by rob on 2024-11-27.
//

import Foundation
import AVFoundation

// MARK: - Voice Provider
public enum VoiceProvider: String, Codable, CaseIterable, Identifiable {
    case system = "System"
    case openAI = "OpenAI"
    
    public var id: String { rawValue }
}

// MARK: - Voice Error
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
    
    public var errorDescription: String? {
        switch self {
        case .voiceNotFound:
            return "Selected voice not found, using default voice."
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
        }
    }
}

// MARK: - Voice Service Protocol
@MainActor
public protocol VoiceServiceProtocol: AnyObject {
    nonisolated func stop()
    func speak(_ text: String) async throws
}

// MARK: - Voice Helper
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
        
        let englishVoices = allVoices.filter { voice in
            voice.language.starts(with: "en")
        }.sorted { voice1, voice2 in
            if voice1.quality != voice2.quality {
                return voice1.quality.rawValue > voice2.quality.rawValue
            }
            return voice1.language < voice2.language
        }
        
        return !englishVoices.isEmpty ? englishVoices : allVoices
    }
    
    public static func voiceDisplayName(for voice: AVSpeechSynthesisVoice) -> String {
        let quality = voice.quality == .enhanced ? " (Enhanced)" : ""
        return "\(voice.name)\(quality) - \(voice.language)"
    }
}

// MARK: - System Voice Service
@MainActor
public final class SystemVoiceService: NSObject, VoiceServiceProtocol {
    private let synthesizer: AVSpeechSynthesizer
    private let voiceIdentifier: String
    private var isCurrentlySpeaking = false
    private var continuation: CheckedContinuation<Void, Error>?
    private var isCancelled = false
    private var activeUtterance: AVSpeechUtterance?
    private let audioSession: AVAudioSession
    
    private var currentVoice: AVSpeechSynthesisVoice? {
        didSet {
            if let voice = currentVoice {
                if oldValue?.identifier != voice.identifier {
                    print("Voice changed to: \(VoiceHelper.voiceDisplayName(for: voice))")
                }
            }
        }
    }
    
    public init(voiceIdentifier: String) {
        self.voiceIdentifier = voiceIdentifier
        self.synthesizer = AVSpeechSynthesizer()
        self.audioSession = .sharedInstance()
        super.init()
        Task { await self.setupService() }
    }
    
    private func setupService() async {
        synthesizer.delegate = self
        updateCurrentVoice()
        
        do {
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try audioSession.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error.localizedDescription)")
        }
    }
    
    private func updateCurrentVoice() {
        if let voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier) {
            currentVoice = voice
        } else if let defaultVoice = VoiceHelper.getAvailableVoices().first {
            print("Requested voice not found, using default: \(VoiceHelper.voiceDisplayName(for: defaultVoice))")
            currentVoice = defaultVoice
        }
    }
    
    public func speak(_ text: String) async throws {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        updateCurrentVoice()
        
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
            self.activeUtterance = utterance
            self.isCancelled = false
            self.isCurrentlySpeaking = true
            
            synthesizer.speak(utterance)
        }
    }
    
    public nonisolated func stop() {
        Task { @MainActor [weak self] in
            await self?.stopSpeaking()
        }
    }
    
    private func stopSpeaking() async {
        guard isCurrentlySpeaking else { return }
        
        isCancelled = true
        synthesizer.stopSpeaking(at: .immediate)
        isCurrentlySpeaking = false
        
        if let continuation = continuation {
            self.continuation = nil
            continuation.resume(throwing: VoiceError.cancelled)
        }
        
        activeUtterance = nil
    }
    
    deinit {
        let session = audioSession
        Task {
            try? session.setActive(false)
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate
extension SystemVoiceService: AVSpeechSynthesizerDelegate {
    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            guard utterance === self.activeUtterance else { return }
            
            self.isCurrentlySpeaking = false
            
            if let continuation = self.continuation {
                self.continuation = nil
                if !self.isCancelled {
                    continuation.resume()
                }
            }
            
            self.activeUtterance = nil
        }
    }
    
    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            guard utterance === self.activeUtterance else { return }
            
            self.isCurrentlySpeaking = false
            
            if let continuation = self.continuation {
                self.continuation = nil
                if !self.isCancelled {
                    continuation.resume(throwing: VoiceError.playbackFailed)
                }
            }
            
            self.activeUtterance = nil
        }
    }
}
