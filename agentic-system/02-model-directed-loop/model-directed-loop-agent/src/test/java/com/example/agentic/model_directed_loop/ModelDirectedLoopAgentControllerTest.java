package com.example.agentic.model_directed_loop;

import static org.mockito.Mockito.mock;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

import com.openai.models.chat.completions.ChatCompletionToolChoiceOption;
import org.junit.jupiter.api.Test;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.ai.chat.prompt.ChatOptions;
import org.springframework.ai.openai.OpenAiChatOptions;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.SpringBootConfiguration;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.ComponentScan;
import org.springframework.context.annotation.FilterType;
import org.springframework.test.web.servlet.MockMvc;

@WebMvcTest(ModelDirectedLoopAgentController.class)
class ModelDirectedLoopAgentControllerTest {

  @SpringBootConfiguration
  @ComponentScan(
      basePackageClasses = ModelDirectedLoopAgentController.class,
      includeFilters =
          @ComponentScan.Filter(
              type = FilterType.ASSIGNABLE_TYPE,
              classes = ModelDirectedLoopAgentController.class),
      useDefaultFilters = false)
  static class Config {
    @Bean
    ChatClient.Builder builder() {
      return mock(ChatClient.Builder.class);
    }

    @Bean
    ChatOptions.Builder chatOptions() {
      // Spring AI 2.0.0-M6: ChatClient.Builder.defaultOptions() takes a ChatOptions.Builder.
      // Spring AI 2.0.0-RC1: pass the typed tool choice (the "required" string is rejected).
      return OpenAiChatOptions.builder()
          .toolChoice(
              ChatCompletionToolChoiceOption.ofAuto(ChatCompletionToolChoiceOption.Auto.REQUIRED));
    }
  }

  @Autowired MockMvc mvc;

  @Test
  void resetOnUnknownAgentReturns404() throws Exception {
    mvc.perform(post("/agents/model-directed-loop/ghost/reset")).andExpect(status().isNotFound());
  }

  @Test
  void logOnUnknownAgentReturns404() throws Exception {
    mvc.perform(get("/agents/model-directed-loop/ghost/log")).andExpect(status().isNotFound());
  }

  @Test
  void listStartsEmpty() throws Exception {
    mvc.perform(get("/agents/model-directed-loop/"))
        .andExpect(status().isOk())
        .andExpect(content().json("[]"));
  }
}
