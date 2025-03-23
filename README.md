# Ophelia &nbsp; <img alt="License" src="https://img.shields.io/github/license/kroonen/ophelia?style=flat-square"> <img alt="TestFlight Beta" src="https://img.shields.io/badge/TestFlight-Beta-blue?style=flat-square">

Ophelia is a minimalist, SwiftUI-based chatbot interface created for smoother, more engaging conversations.  
It supports multiple AI providers—OpenAI, Anthropic, GitHub/Azure-based models—and offers a TestFlight beta for convenient early access. Enjoy speech synthesis, customizable settings, and a dedicated system message field to shape the AI’s behavior.

> **Now available on TestFlight!**  
> [Join the beta](https://testflight.apple.com/join/3T2qSW7h) to explore upcoming features and help us refine the app.  
> The app is under active development; some features may be unstable or require additional configuration.

---

## Key Highlights ✨

| **Multiple AI Providers** | **Rich Model Library** | **Speech Integration** | **System Message Customization** | **Auto-Saved Settings** |
| :-----------------------: | :--------------------: | :--------------------: | :-----------------------------: | :----------------------: |
| Integrate seamlessly with OpenAI, Anthropic, or GitHub/Azure-based models. | Access a variety of AI engines (Llama, AI21, Cohere, Mistral, Phi, JAIS, etc.) using a GitHub token. | Enjoy hands-free interactions with built-in speech synthesis (with automatic fallback to system voices). | Fine-tune your AI’s style and behavior via an editable system message. | All credentials, model selections, and custom settings are automatically saved and restored on relaunch. |

---

## Feature Details

| **OpenAI** | **Anthropic** | **GitHub/Azure Integration** |
| :--------: | :-----------: | :--------------------------: |
| Supports GPT-3.5 Turbo, GPT-4o mini, and more. | Built-in support for Claude models. | Provide a GitHub token to unlock Azure-hosted models (Llama, AI21, Cohere, Mistral, Phi, JAIS, etc.). |

<details>
<summary><strong>Example Models</strong></summary>

### OpenAI-like
- `OpenAI GPT-4o`  
- `OpenAI GPT-4o mini`  
- `OpenAI o1-mini`  
- `OpenAI o1-preview`  

### AI21 Labs
- `AI21-Jamba-1.5-Large`  
- `AI21-Jamba-1.5-Mini`

### Cohere
- `Cohere-command-r`  
- `Cohere-command-r-08-2024`  
- `Cohere-command-r-plus`  
- `Cohere-command-r-plus-08-2024`

### Llama
- `Llama-3.2-11B-Vision-Instruct`  
- `Llama-3.2-90B-Vision-Instruct`  
- `Llama-3.3-70B-Instruct`

### Meta-Llama
- `Meta-Llama-3.1-405B-Instruct`  
- `Meta-Llama-3.1-70B-Instruct`  
- `Meta-Llama-3.1-8B-Instruct`  
- `Meta-Llama-3-70B-Instruct`  
- `Meta-Llama-3-8B-Instruct`

### Mistral AI
- `Ministral-3B`  
- `Mistral-large`  
- `Mistral-large-2407`  
- `Mistral-Large-2411`  
- `Mistral-Nemo`  
- `Mistral-small`

### Phi
- `Phi-3.5-MoE-instruct (128k)`  
- `Phi-3.5-mini-instruct (128k)`  
- `Phi-3.5-vision-instruct (128k)`  
- Various `Phi-3-*` models

### JAIS
- `jais-30b-chat`

</details>

---

## Quick Start 🚀

| **Step**            | **Action**                                                                                                                                                                                                 |
| :-----------------: | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **1. Clone**        | ```bash<br>git clone https://github.com/Ophelia-Chat/ophelia.git<br>```                                                                                                                                   |
| **2. Open in Xcode**| Open the cloned folder (`ophelia.xcodeproj` or `ophelia.xcworkspace`) in Xcode.                                                                                                                            |
| **3. Run the App**  | - Build and run on a simulator or physical device.<br>- In **Settings**, select a provider (OpenAI, Anthropic, or GitHub), enter the corresponding credentials, pick a model, set a system message, and chat! |

---

## Requirements 🗝️

| **API Keys**                                                                    | **GitHub Token**                                                            |
| :-----------------------------------------------------------------------------: | :--------------------------------------------------------------------------: |
| - [OpenAI](https://platform.openai.com) <br> - [Anthropic](https://console.anthropic.com) | Generate or use a GitHub token that grants access to Azure-hosted models. |

> **Important:** Without valid API keys or a GitHub token, the app cannot fetch AI responses.

---

## TestFlight Beta 🍏

Help shape the future of Ophelia by joining the TestFlight beta. You’ll get exclusive access to the latest features before they’re released to the App Store.

[Join TestFlight Beta](https://testflight.apple.com/join/3T2qSW7h)

---

## Tips & Troubleshooting 🛠️

| **Scenario**             | **Advice**                                                                                                                                                                                                     |
| :----------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Switching Providers**  | Make sure to provide the correct credentials for whichever provider you select. If switching to GitHub, remember to supply your GitHub token.                                                                    |
| **Speech Errors**        | If OpenAI-based TTS fails, Ophelia automatically switches to system voices.                                                                                                                                    |
| **Debugging**            | For more detailed logs, check the Xcode console while running the app.                                                                                                                                         |

---

## License 📄

Ophelia.Chat is open source under MIT License.

---

<div align="center">
  <p><strong>We do this for the good—enhancing AI-human synergy responsibly.</strong></p>
  <p>Feedback and contributions are always appreciated! 🤗</p>
  <p>Built by <a href="https://kroonen.ai">Kroonen AI, Inc.</a></p>
</div>
