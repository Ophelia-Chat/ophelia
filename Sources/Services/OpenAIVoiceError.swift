//
//  OpenAIVoiceError.swift
//  ophelia
//
//  Created by rob on 2024-11-27.
//

import Foundation

public enum OpenAIVoiceError: Error {
    case playbackFailed
    case invalidResponse
    case unauthorized
    case rateLimitExceeded
    case serverError(String)
    case cancelled
    case invalidAudioData
}
