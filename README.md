
# Ophelia &nbsp; <img alt="License" src="https://img.shields.io/github/license/kroonen/ophelia?style=flat-square"> <img alt="TestFlight Beta" src="https://img.shields.io/badge/TestFlight-Beta-blue?style=flat-square">

Ophelia is a minimalist, SwiftUI-based chatbot interface created for smooth, engaging conversations. It supports multiple AI providers—OpenAI, Anthropic, and GitHub/Azure-based models—and now offers a TestFlight beta for quick, convenient early access. Enjoy speech synthesis, customizable settings, and a dedicated system message field to shape the AI’s behavior.

> **Now available on TestFlight!**  
> [Join the beta](https://testflight.apple.com/join/3T2qSW7h) to experiment with upcoming features and help refine the app.  
> The app is under active development; some features may be unstable or require additional configuration.

---

## Key Highlights ✨

- **Multiple AI Providers**: Seamlessly integrate with OpenAI, Anthropic, or GitHub/Azure-based models.  
- **Rich Model Library**: Access a broad range of AI models (Llama, AI21, Cohere, Mistral, Phi, JAIS, and more) by using a GitHub token.
- **Speech Integration**: Enjoy hands-free interactions with automatic speech synthesis (including fallback to system voices).
- **System Message Customization**: Tailor the AI’s style and behavior with your own system message.
- **Auto-Saved Settings**: All credentials, model selections, and custom settings are preserved on relaunch.

---

## Features Details

1. **OpenAI**  
   Supported models include GPT-3.5 Turbo, GPT-4o mini, and others.

2. **Anthropic**  
   Built-in support for Claude models.

3. **GitHub/Azure Integration**  
   - Provide a GitHub token to unlock a wide array of Azure-hosted models.
   - Includes Llama, AI21, Cohere, Mistral, Phi, and JAIS models.

   **Example Models**  
   - **OpenAI-like**: `OpenAI GPT-4o`, `OpenAI GPT-4o mini`, `OpenAI o1-mini`, `OpenAI o1-preview`  
   - **AI21 Labs**: `AI21-Jamba-1.5-Large`, `AI21-Jamba-1.5-Mini`  
   - **Cohere**: `Cohere-command-r`, `Cohere-command-r-08-2024`, `Cohere-command-r-plus`, `Cohere-command-r-plus-08-2024`  
   - **Llama**: `Llama-3.2-11B-Vision-Instruct`, `Llama-3.2-90B-Vision-Instruct`, `Llama-3.3-70B-Instruct`  
   - **Meta-Llama**: `Meta-Llama-3.1-405B-Instruct`, `Meta-Llama-3.1-70B-Instruct`, `Meta-Llama-3.1-8B-Instruct`, `Meta-Llama-3-70B-Instruct`, `Meta-Llama-3-8B-Instruct`  
   - **Mistral AI**: `Ministral-3B`, `Mistral-large`, `Mistral-large-2407`, `Mistral-Large-2411`, `Mistral-Nemo`, `Mistral-small`  
   - **Phi**: `Phi-3.5-MoE-instruct (128k)`, `Phi-3.5-mini-instruct (128k)`, `Phi-3.5-vision-instruct (128k)`, plus various `Phi-3-*` models  
   - **JAIS**: `jais-30b-chat`

---

## Quick Start 🚀

1. **Clone the repository:**
   ```bash
   git clone https://github.com/Ophelia-Chat/ophelia.git
   ```

2. **Open in Xcode:**
   Open `ophelia.xcodeproj` or `ophelia.xcworkspace` in Xcode.

3. **Run the App:**
   - Build and run on a simulator or physical device.
   - In the app, go to **Settings**:
     1. Select a provider: **OpenAI**, **Anthropic**, or **GitHub**.
     2. Enter the corresponding API key or GitHub token.
     3. Choose a model, set an optional system message, and start chatting!

---

## Requirements 🗝️

- **API Keys**  
  - [OpenAI](https://platform.openai.com)  
  - [Anthropic](https://console.anthropic.com)
- **GitHub Token**  
  - Generate or use a GitHub token that grants access to Azure-hosted models.

> **Important:** Without a valid API key or token, the app cannot fetch AI responses.

---

## TestFlight Beta 🍏

Help shape the future of Ophelia by joining the TestFlight beta. You’ll get exclusive access to the latest features before they reach the App Store.

[Join TestFlight Beta](https://testflight.apple.com/join/3T2qSW7h)

---

## Tips & Troubleshooting 🛠️

- **Switching Providers**  
  Make sure to provide the correct credentials for the provider you select. If switching to the GitHub provider, remember to supply your GitHub token.
- **Speech Errors**  
  If OpenAI-based TTS encounters a problem, Ophelia automatically uses system voices to continue playback.
- **Debugging**  
  For detailed logs, check the Xcode console while running the app.

---

## License 📄

Ophelia is open source under the [GNU Affero General Public License v3.0](LICENSE).  
[Learn more about AGPL v3](https://www.gnu.org/licenses/agpl-3.0.html)

Any use of this software over a network must provide access to the source code.

---

Feedback and contributions are always appreciated! 🤗  

<div align="center">
  <p>Built with ✨ by <a href="https://kroonen.ai">Robin Kroonen</a></p>
</div>
