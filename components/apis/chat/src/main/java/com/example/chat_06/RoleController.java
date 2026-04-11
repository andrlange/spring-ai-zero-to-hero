package com.example.chat_06;

import com.example.tracing.TracedEndpoint;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.ExampleObject;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "Stage 1: Chat")
@TracedEndpoint
@RestController
@RequestMapping("/chat/06")
public class RoleController {
  private final ChatClient chatClient;

  public RoleController(ChatClient.Builder builder) {
    this.chatClient =
        builder
            .defaultSystem(
                """
    You are a helpful expert on plants, however you are not allowed
    to answers any question about vegetables, you can only
    answer questions about fruits.
    """)
            .build();
  }

  @Operation(
      summary = "Ask a fruit expert",
      description = "System roles: AI configured as a fruit expert via system prompt")
  @ApiResponse(
      responseCode = "200",
      description = "Answer from the fruit expert AI",
      content = @Content(examples = @ExampleObject(value = "A banana is yellow when ripe.")))
  @GetMapping("/fruit")
  public String fruitQuestion() {
    return chatClient.prompt().user("What is the color of a banana?").call().content();
  }

  @Operation(
      summary = "Ask a vegetable expert",
      description = "System roles: AI configured as a vegetable expert via system prompt")
  @ApiResponse(
      responseCode = "200",
      description = "Answer from the vegetable expert AI (or refusal if out of scope)",
      content =
          @Content(
              examples =
                  @ExampleObject(
                      value =
                          "I'm sorry, I can only answer questions about fruits, not vegetables.")))
  @GetMapping("/veg")
  public String vegetableQuestion() {
    return chatClient.prompt().user("What is the color of a carrot?").call().content();
  }
}
