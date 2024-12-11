# Ophelia 🌸

Ophelia is a minimalist, SwiftUI-based chatbot interface designed for smooth and engaging conversations. It supports both OpenAI and Anthropic models and offers speech synthesis, customizable settings, and a system message field to tailor the AI’s behavior.

> [!NOTE]
> The app is under active development and debugging. Some features may be unstable or require further configuration.

---

## Features ✨

- **Multiple Providers**: Seamlessly switch between OpenAI’s GPT models and Anthropic’s Claude models.
- **Model Selection & System Message**: Choose from various AI models and set a system message to guide the assistant’s style and behavior.
- **Speech Integration**: Autoplay responses using system voices or OpenAI-based TTS.
- **Automatic Settings Persistence**: Settings changes are saved automatically, so your provider, model, and API keys persist across sessions.

---

## Requirements 🗝️

**API Keys**:  
You must provide a valid API key for the selected provider. If you toggle from OpenAI to Anthropic (or vice versa), ensure you’ve entered the corresponding API key in the Settings screen.

- OpenAI key: [https://platform.openai.com](https://platform.openai.com)
- Anthropic key: [https://console.anthropic.com](https://console.anthropic.com)

Without a valid key, the app will not be able to fetch AI responses.

---

## Getting Started 🚀

1. **Clone the repository:**
   ```bash
   git clone https://github.com/kroonen/ophelia.git
   ```

2. **Open in Xcode:**
   Open `ophelia.xcodeproj` or `ophelia.xcworkspace` in Xcode.

3. **Run the App:**
   Build and run on a simulator or device. Go to the Settings screen, select a provider, and enter a valid API key before chatting.

---

## Tips & Troubleshooting 🛠️

- **Switching Providers**: When toggling between OpenAI and Anthropic, make sure you have the correct API key set for that provider. The send button will be disabled if no valid key is present.
- **Speech Errors**: If OpenAI TTS fails, the app will automatically fall back to system voices.
- **Debugging**: Check the Xcode console logs for detailed error messages if something goes wrong.

---

## License 📄

Ophelia is open source under the MIT License.

Feedback and contributions are welcome! 🤗

<div align="center">
  <p>Built with ✨ by <a href="https://kroonen.ai">Robin Kroonen</a></p>
</div>
