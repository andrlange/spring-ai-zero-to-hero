package com.example.agentic.inner_monologue.config;

import com.openai.models.chat.completions.ChatCompletionToolChoiceOption;
import org.springframework.ai.chat.prompt.ChatOptions;
import org.springframework.ai.ollama.api.OllamaChatOptions;
import org.springframework.ai.openai.OpenAiChatOptions;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;

/**
 * Selects the per-provider {@link ChatOptions} at agent construction time. The {@code openai} path
 * forces the model to always invoke {@code send_message} via a "required" tool choice; the {@code
 * ollama} path selects a tool-capable model via the {@code agent.ollama.model} property (defaults
 * to {@code qwen3}).
 *
 * <p>Spring AI 2.0.0-RC1: {@code OpenAiChatModel} no longer accepts the plain {@code
 * toolChoice("required")} string (it throws {@code UnsupportedOperationException} in {@code
 * createRequest}); pass the typed {@link ChatCompletionToolChoiceOption} instead.
 */
@Configuration("innerMonologueAgentOptionsConfig")
public class AgentOptionsConfig {

  // Spring AI 2.0.0-M6: ChatClient.Builder.defaultOptions() now takes a ChatOptions.Builder
  // (so the chat client can merge with its own defaults). Beans return the builder, not a built
  // instance.

  @Bean
  @Profile("!ollama")
  public ChatOptions.Builder openAiAgentOptions() {
    return OpenAiChatOptions.builder()
        .toolChoice(
            ChatCompletionToolChoiceOption.ofAuto(ChatCompletionToolChoiceOption.Auto.REQUIRED));
  }

  @Bean
  @Profile("ollama")
  public ChatOptions.Builder ollamaAgentOptions(
      @Value("${agent.ollama.model:qwen3}") String model) {
    return OllamaChatOptions.builder().model(model);
  }
}
