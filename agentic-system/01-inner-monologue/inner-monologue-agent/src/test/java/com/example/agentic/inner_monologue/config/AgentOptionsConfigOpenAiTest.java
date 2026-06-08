package com.example.agentic.inner_monologue.config;

import static org.assertj.core.api.Assertions.assertThat;

import com.openai.models.chat.completions.ChatCompletionToolChoiceOption;
import org.junit.jupiter.api.Test;
import org.springframework.ai.chat.prompt.ChatOptions;
import org.springframework.ai.openai.OpenAiChatOptions;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

@SpringBootTest(classes = AgentOptionsConfig.class)
@ActiveProfiles("openai")
class AgentOptionsConfigOpenAiTest {

  // Spring AI 2.0.0-M6: bean exposes a ChatOptions.Builder so the chat client can merge defaults.
  @Autowired ChatOptions.Builder chatOptionsBuilder;

  @Test
  void selectsOpenAiOptionsWithRequiredToolChoice() {
    ChatOptions chatOptions = chatOptionsBuilder.build();
    assertThat(chatOptions).isInstanceOf(OpenAiChatOptions.class);
    OpenAiChatOptions opts = (OpenAiChatOptions) chatOptions;
    // Spring AI 2.0.0-RC1: OpenAiChatModel rejects the "required" string; we pass the typed option.
    assertThat(opts.getToolChoice())
        .isEqualTo(
            ChatCompletionToolChoiceOption.ofAuto(ChatCompletionToolChoiceOption.Auto.REQUIRED));
  }
}
