# Ophelia

Ophelia is a minimalist, SwiftUI-based chatbot interface designed for smooth and engaging conversations. It supports multiple AI providers—OpenAI, Anthropic, and GitHub/Azure-based models—and now includes a TestFlight beta for convenient early access. Experience speech synthesis, customizable settings, and a system message field to tailor the AI’s behavior.

> [!NOTE]
> **Now available on TestFlight!**  
> [Join the beta](https://testflight.apple.com/join/3T2qSW7h) to try out new features and help refine the app.  
> The app remains under active development and debugging. Some features may be unstable or require further configuration.

---

## Features ✨

- **Multiple Providers**:  
  - **OpenAI**: GPT-3.5 Turbo, GPT-4o mini, and more.
  - **Anthropic**: Claude models.
  - **GitHub/Azure Integration**: A wide range of models available via a GitHub token.
  
- **GitHub Model Integration**:  
  By providing a GitHub token, you gain access to an extensive array of models served through Azure. This includes various Llama, AI21, Cohere, Mistral, Phi, and JAIS models. For example:

  **Available GitHub/Azure Models**:
  - **OpenAI-like Models**: `OpenAI GPT-4o`, `OpenAI GPT-4o mini`, `OpenAI o1-mini`, `OpenAI o1-preview`
  - **AI21 Labs**: `AI21-Jamba-1.5-Large`, `AI21-Jamba-1.5-Mini`
  - **Cohere**: `Cohere-command-r`, `Cohere-command-r-08-2024`, `Cohere-command-r-plus`, `Cohere-command-r-plus-08-2024`
  - **Llama**: `Llama-3.2-11B-Vision-Instruct`, `Llama-3.2-90B-Vision-Instruct`, `Llama-3.3-70B-Instruct`
  - **Meta-Llama**: `Meta-Llama-3.1-405B-Instruct`, `Meta-Llama-3.1-70B-Instruct`, `Meta-Llama-3.1-8B-Instruct`, `Meta-Llama-3-70B-Instruct`, `Meta-Llama-3-8B-Instruct`
  - **Mistral AI**: `Ministral-3B`, `Mistral-large`, `Mistral-large-2407`, `Mistral-Large-2411`, `Mistral-Nemo`, `Mistral-small`
  - **Phi Models**: `Phi-3.5-MoE-instruct (128k)`, `Phi-3.5-mini-instruct (128k)`, `Phi-3.5-vision-instruct (128k)`, plus `Phi-3-medium-128k-instruct`, `Phi-3-medium-4k-instruct`, `Phi-3-mini-128k-instruct`, `Phi-3-mini-4k-instruct`, `Phi-3-small-128k-instruct`, `Phi-3-small-8k-instruct`
  - **JAIS**: `jais-30b-chat`

- **Model Selection & System Message**: Choose from numerous AI models and set a system message to guide the assistant’s style and behavior.
- **Speech Integration**: Autoplay responses using system voices or OpenAI-based TTS.
- **Automatic Settings Persistence**: Settings changes are saved automatically so your chosen provider, model, and keys persist.

---

## Requirements 🗝️

**API Keys & GitHub Token**:
- For OpenAI: [https://platform.openai.com](https://platform.openai.com)
- For Anthropic: [https://console.anthropic.com](https://console.anthropic.com)
- For GitHub Model (Azure-based): Generate or use a GitHub token that grants access to the available Azure-hosted models.

Without a valid key/token, the app will not be able to fetch AI responses.

---

## Getting Started 🚀

1. **Clone the repository:**
   ```bash
   git clone https://github.com/kroonen/ophelia.git
   ```

2. **Open in Xcode:**
   Open `ophelia.xcodeproj` or `ophelia.xcworkspace` in Xcode.

3. **Run the App:**
   Build and run on a simulator or device.
   - Go to Settings.
   - Select a provider (OpenAI, Anthropic, or GitHub Model).
   - Enter the corresponding API key or GitHub token.
   - Choose a model, set a system message if desired, and start chatting.

---

## TestFlight Beta 🍏

Try out the latest features and help shape the app’s future:
[Join TestFlight Beta](https://testflight.apple.com/join/3T2qSW7h)

---

## Tips & Troubleshooting 🛠️

- **Switching Providers**: Ensure that you have the correct credentials for the selected provider. When switching to GitHub Model, enter your GitHub token to access the Azure-based models.
- **Speech Errors**: If OpenAI TTS fails, the app will automatically fall back to system voices.
- **Debugging**: Check the Xcode console logs for detailed error messages.

---

## License 📄

Ophelia is open source under the [GNU Affero General Public License v3.0](LICENSE).

[Learn more about AGPL v3](https://www.gnu.org/licenses/agpl-3.0.html)

Any use of this software over a network must provide access to the source code.

Feedback and contributions are welcome! 🤗

<div align="center">
  <p>Built with ✨ by <a href="https://kroonen.ai">Robin Kroonen</a></p>
</div>
