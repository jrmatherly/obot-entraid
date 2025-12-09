module github.com/jrmatherly/obot-entraid/custom-obot-tools/anthropic-model-provider

go 1.24.1

replace github.com/jrmatherly/obot-entraid/custom-obot-tools/openai-model-provider => ../openai-model-provider

require (
	github.com/gptscript-ai/chat-completion-client v0.0.0-20250123123106-c86554320789
	github.com/jrmatherly/obot-entraid/custom-obot-tools/openai-model-provider v0.0.0-20250327233502-e281d9bc8d01
)
