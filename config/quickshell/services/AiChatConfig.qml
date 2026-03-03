pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    // Put your preferred OpenRouter models here.
    // 'id' must be the OpenRouter model id.
    property var models: [
        { "id": "moonshotai/kimi-k2.5", "label": "Kimi K2.5" },
        { "id": "qwen/qwen3.5-35b-a3b", "label": "Qwen 3.5 35B A3B" },
        { "id": "minimax/minimax-m2-her", "label": "MiniMax M2 Her" },
        { "id": "z-ai/glm-4.7-flash", "label": "GLM 4.7 Flash" },
        { "id": "openai/gpt-5.2", "label": "GPT-5.2" },
        { "id": "anthropic/claude-haiku-4.5", "label": "Claude Haiku 4.5" }
    ]

    // Optional system prompt applied on each request.
    property string systemPrompt: "You are a concise assistant."

    // Optional OpenRouter metadata headers.
    property string siteUrl: "https://localhost"
    property string appTitle: "Quickshell AI Chat"
}
