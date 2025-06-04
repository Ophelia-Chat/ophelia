# Ophelia

<div align="center">
  <img alt="License" src="https://img.shields.io/github/license/kroonen/ophelia?style=flat-square">
  <img alt="TestFlight Beta" src="https://img.shields.io/badge/TestFlight-Beta-blue?style=flat-square">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-5.9+-orange?style=flat-square">
  <img alt="iOS" src="https://img.shields.io/badge/iOS-18.0+-blue?style=flat-square">
</div>

<br>

**Ophelia** is a modern, minimalist SwiftUI-based chat application designed for seamless conversations with multiple AI providers. Built with clean architecture principles and featuring advanced capabilities like memory persistence, voice synthesis, and dynamic theme support.

> **🚀 Now available on TestFlight!**  
> [Join the beta](https://testflight.apple.com/join/3T2qSW7h) to explore cutting-edge features and help shape the future of AI interaction.

---

## ✨ Features

### Multi-Provider AI Support
- **OpenAI**: GPT-4o, GPT-4o mini, o1-preview, o1-mini
- **Anthropic**: Claude 3.5 Haiku, Claude 3.5 Sonnet, Claude 3 Opus
- **GitHub/Azure Models**: Access to 25+ models including Llama, Mistral, Cohere, and more
- **Ollama**: Local inference with your own models

### Advanced Capabilities
- **🧠 Memory System**: Persistent conversation memory with semantic retrieval
- **🔊 Speech Integration**: OpenAI TTS and system voice synthesis with auto-play
- **🎨 Dynamic Theming**: System, light, and dark mode support
- **📝 Markdown Rendering**: Rich text formatting in conversations
- **💾 Export Functionality**: JSON export for conversations and memories
- **⚙️ Custom System Messages**: Fine-tune AI behavior and personality

### Developer-Focused Architecture
- **SwiftUI + Combine**: Modern reactive UI framework
- **Actor-based Services**: Thread-safe networking and state management
- **Protocol-oriented Design**: Extensible service architecture
- **Comprehensive Error Handling**: Robust error management with user feedback
- **Persistent Storage**: UserDefaults and file-based persistence

---

## 🏗️ Architecture

### Core Components

#### ChatViewModel
Central coordinator managing conversation flow, memory integration, and service orchestration.

```swift
@MainActor
class ChatViewModel: ObservableObject {
    @Published private(set) var messages: [MutableMessage] = []
    @Published var appSettings: AppSettings
    @Published var memoryStore: MemoryStore
    // ... additional properties
}
```

#### Service Layer
- **ChatServiceProtocol**: Unified interface for all AI providers
- **VoiceServiceProtocol**: Text-to-speech abstraction
- **MemoryStore**: Semantic memory management with optional embeddings
- **ModelListService**: Dynamic model discovery and caching

#### UI Architecture
- **Theme System**: Consistent color palette with dark/light mode support
- **Keyboard Adaptive**: Smart keyboard handling for optimal UX
- **Message Streaming**: Real-time token display with haptic feedback

---

## 🚀 Quick Start

### Prerequisites
- Xcode 15.0+
- iOS 18.0+ deployment target
- API keys for your chosen providers

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/Ophelia-Chat/ophelia.git
   cd ophelia
   ```

2. **Open in Xcode**
   ```bash
   open ophelia.xcodeproj
   ```

3. **Configure providers**
   - Build and run the app
   - Navigate to Settings
   - Select your preferred AI provider
   - Enter your API credentials
   - Choose a model and start chatting!

### Supported Providers

| Provider | Setup Instructions | Models Available |
|----------|-------------------|------------------|
| **OpenAI** | Get API key from [platform.openai.com](https://platform.openai.com) | GPT-4o, GPT-4o mini, o1-preview, o1-mini |
| **Anthropic** | Get API key from [console.anthropic.com](https://console.anthropic.com) | Claude 3.5 Haiku, Sonnet, Opus |
| **GitHub Models** | Generate GitHub token with model access | Llama, Mistral, Cohere, Phi, JAIS, and more |
| **Ollama** | Install Ollama locally at `localhost:11434` | Any locally installed model |

---

## 🎯 Usage Examples

### Memory Commands
Ophelia includes an intelligent memory system for persistent context:

```
remember that I'm a Swift developer working on iOS apps
remember that I prefer functional programming patterns
what do you remember about me?
forget that I mentioned functional programming
forget everything
```

### Voice Features
- **Auto-play**: Enable in settings for hands-free conversations
- **Multiple voices**: System voices or OpenAI TTS (alloy, echo, fable, onyx, nova, shimmer)
- **Interruption handling**: Smart pause/resume during interruptions

### Export & Sharing
- Export conversations as structured JSON
- Export memories for backup or analysis
- Copy individual messages or entire conversations

---

## 🔧 Configuration

### Environment Variables
For development builds, you can set default API keys:

```swift
// In AppSettings.swift
#if DEBUG
private let defaultOpenAIKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
#endif
```

### Ollama Setup
1. Install Ollama: `brew install ollama`
2. Start the service: `ollama serve`
3. Pull a model: `ollama pull llama3.2`
4. Configure URL in Ophelia (default: `http://localhost:11434`)

---

## 🎨 Theming

Ophelia features a sophisticated theming system built on color semantics:

```swift
// Example theme usage
Color.Theme.primaryGradient(isDarkMode: isDarkMode)
Color.Theme.bubbleBackground(isDarkMode: isDarkMode, isUser: true)
Color.Theme.textPrimary(isDarkMode: isDarkMode)
```

Themes automatically adapt to:
- System appearance changes
- User preference overrides
- Context-aware color schemes

---

## 🏆 Best Practices

### Performance Optimization
- Lazy loading of conversation history
- Efficient message tokenization and streaming
- Memory management with automatic cleanup
- Concurrent model fetching where supported

### Security
- Secure API key storage
- Input validation and sanitization
- Network request timeout handling
- Error boundary implementation

### User Experience
- Haptic feedback during message streaming
- Smooth keyboard animations
- Contextual error messages
- Progressive loading states

---

## 🤝 Contributing

We welcome contributions! Here's how to get started:

1. **Fork the repository**
2. **Create a feature branch**
   ```bash
   git checkout -b feature/amazing-feature
   ```
3. **Make your changes**
4. **Add tests** (when applicable)
5. **Commit with conventional commits**
   ```bash
   git commit -m "feat: add amazing feature"
   ```
6. **Push and create a PR**

### Development Guidelines
- Follow Swift API Design Guidelines
- Use SwiftUI best practices
- Implement proper error handling
- Add documentation for public APIs
- Ensure thread safety with actors

---

## 📋 Roadmap

### Upcoming Features
- [ ] **Vision Support**: Image analysis and generation
- [ ] **Plugin System**: Extensible tool integration
- [ ] **Cloud Sync**: Cross-device conversation sync
- [ ] **Advanced Memory**: Vector embeddings and semantic search
- [ ] **Custom Models**: Fine-tuned model support
- [ ] **Collaboration**: Shared conversations and workspaces

### Performance Improvements
- [ ] Message virtualization for large conversations
- [ ] Improved caching mechanisms
- [ ] Background model loading
- [ ] Enhanced streaming performance

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

```
MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software...
```

---

## 🙏 Acknowledgments

- **SwiftUI Community**: For excellent frameworks and inspiration
- **AI Providers**: OpenAI, Anthropic, GitHub, and Ollama teams
- **Beta Testers**: TestFlight community feedback and contributions
- **Open Source**: Built on the shoulders of amazing open source projects

---

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/Ophelia-Chat/ophelia/issues)
- **Discussions**: [GitHub Discussions](https://github.com/Ophelia-Chat/ophelia/discussions)
- **TestFlight**: [Join Beta Program](https://testflight.apple.com/join/3T2qSW7h)
- **Company**: [KROONEN AI](https://www.kroonen.ai)

---

<div align="center">
  <p><strong>Built with ❤️ by the Ophelia team</strong></p>
  <p>Enhancing AI-human interaction, one conversation at a time.</p>
  
  [![GitHub stars](https://img.shields.io/github/stars/kroonen/ophelia?style=social)](https://github.com/kroonen/ophelia/stargazers)
  [![GitHub forks](https://img.shields.io/github/forks/kroonen/ophelia?style=social)](https://github.com/kroonen/ophelia/network/members)
</div>
