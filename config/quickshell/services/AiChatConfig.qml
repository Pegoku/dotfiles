pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    // Put your preferred OpenRouter models here.
    // 'id' must be the OpenRouter model id.
    property var models: [
        { "id": "openai/gpt-4o-mini", "label": "GPT-4o mini" },
        { "id": "anthropic/claude-3.5-sonnet", "label": "Claude 3.5 Sonnet" },
        { "id": "meta-llama/llama-3.1-8b-instruct", "label": "Llama 3.1 8B" }
    ]

    // Optional system prompt applied on each request.
    property string systemPrompt: "You are a concise assistant."

    // Optional OpenRouter metadata headers.
    property string siteUrl: "https://localhost"
    property string appTitle: "Quickshell AI Chat"
}
