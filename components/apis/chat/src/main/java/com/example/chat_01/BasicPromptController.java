package com.example.chat_01;

import com.example.tracing.TracedEndpoint;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.ExampleObject;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.ai.chat.model.ChatModel;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "Stage 1: Chat")
@TracedEndpoint
@RestController
@RequestMapping("/chat/01")
public class BasicPromptController {

  // ChatModel is the primary interfaces for interacting with an LLM
  // it is a request/response interface that implements the ModelModel
  // interface. Make sure to visit the source code of the ChatModel and
  // checkout the interfaces in the core spring ai package.
  private final ChatModel chatModel;

  public BasicPromptController(ChatModel chatModel) {
    this.chatModel = chatModel;
  }

  @Operation(summary = "Generate a joke", description = "Simplest AI call: chatModel.call(String)")
  @ApiResponse(
      responseCode = "200",
      description = "Generated joke text",
      content =
          @Content(
              examples =
                  @ExampleObject(
                      value =
                          "Why did Spring Boot go to therapy? Because it had too many dependency issues!")))
  @GetMapping("joke")
  public String getJoke() {
    return this.chatModel.call("Tell me a joke");
  }
}
