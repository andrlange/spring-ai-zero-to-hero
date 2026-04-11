package com.example.chat_02;

import com.example.tracing.TracedEndpoint;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.ExampleObject;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.util.ArrayList;
import java.util.List;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.ai.chat.messages.AssistantMessage;
import org.springframework.ai.chat.model.ChatResponse;
import org.springframework.ai.chat.model.Generation;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "Stage 1: Chat")
@TracedEndpoint
@RestController
@RequestMapping("/chat/02/client")
public class ChatClientController {

  private final ChatClient chatClient;

  public ChatClientController(ChatClient.Builder chatClientBuilder) {
    this.chatClient = chatClientBuilder.build();
  }

  @Operation(
      summary = "Generate a joke (ChatClient)",
      description = "Fluent ChatClient API: .prompt().user().call().content()")
  @ApiResponse(
      responseCode = "200",
      description = "Generated joke text",
      content =
          @Content(
              examples =
                  @ExampleObject(
                      value =
                          "Why did Spring Boot go to therapy? Because it had too many dependency issues!")))
  @GetMapping("/joke")
  public String getJoke(
      @Parameter(description = "Topic for the joke", example = "cows")
          @RequestParam(value = "topic", defaultValue = "cows")
          String topic) {

    ChatResponse response =
        chatClient
            .prompt()
            // Prompt is the primary class that represents a request to an LLM.
            // it can be configured with more options to enable more complex interactions
            // with the AI service. We will see more options later.
            .user("Tell me a joke about " + topic)
            // chat model takes a prompt and returns a chat response
            .call()
            .chatResponse();

    // The response object contains a result object called a generation
    // containing the text from the AI LLM
    Generation generation = response.getResult();

    // The actual data from an LLM is stored in a Message object, there
    // are different types of messages. AssistantMessage indicates that the
    // contents came from the AI service.
    AssistantMessage assistantMessage = generation.getOutput();

    // All these layers of objects might seem to be overkills. However,
    // keep in mind that the same interfaces are used for dealing with
    // text, audio, video, images, and raw numbers. As such the underlying
    // low level interfaces need to be factored out in way, that enables
    // higher level interfaces to be built. The API you are see in this
    // controller is more like JDBC API as apposed to a higher level Spring
    // data jpa. Spring AI will be adding higher level interfaces on top
    // the low level interfaces you have seen so far.
    return assistantMessage.getText();
  }

  @Operation(
      summary = "Generate three jokes (ChatClient)",
      description = "Returns a list of jokes using ChatClient")
  @ApiResponse(
      responseCode = "200",
      description = "List of generated jokes",
      content =
          @Content(
              examples =
                  @ExampleObject(
                      value =
                          "[\"Why did Spring Boot go to therapy? Because it had too many dependency issues!\"]")))
  @GetMapping("/threeJokes")
  public List<String> getThreeJokes() {

    // Make three separate calls to get three different jokes.
    // Each call produces one Generation — most providers only return
    // one result per request (unlike OpenAI's n parameter).
    List<String> jokes = new ArrayList<>();
    for (int i = 0; i < 3; i++) {
      String joke = chatClient.prompt().user("Tell me a short joke").call().content();
      jokes.add(joke);
    }

    return jokes;
  }

  // Generic request-response designed to show what happens without any other Spring-AI wrappers or
  // guardrails
  @GetMapping("/query")
  public String getResponse(@RequestParam(value = "input") String input) {
    return this.chatClient.prompt().user(input).call().content();
  }
}
