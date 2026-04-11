package com.example.chat_05;

import com.example.chat_05.tool.annotations.TimeTools;
import com.example.chat_05.tool.return_direct.Restaurant;
import com.example.chat_05.tool.return_direct.RestaurantSearch;
import com.example.tracing.TracedEndpoint;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.ExampleObject;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.util.List;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "Stage 1: Chat")
@TracedEndpoint
@RestController
@RequestMapping("/chat/05")
class ToolController {
  private final ChatClient chatClient;

  public ToolController(ChatClient.Builder builder) {
    this.chatClient = builder.build();
  }

  @Operation(
      summary = "Get current time for a city",
      description = "Tool/function calling: AI invokes a Java method to get the time")
  @ApiResponse(
      responseCode = "200",
      description = "Current time in the specified city",
      content =
          @Content(
              examples = @ExampleObject(value = "The current time in Toronto is 3:45 PM EST.")))
  @GetMapping("/time")
  public String time(
      @Parameter(description = "City name to get the time for", example = "Toronto")
          @RequestParam(value = "city", defaultValue = "Toronto")
          String city) {

    return chatClient
        .prompt()
        .tools(new TimeTools())
        .user(
            u ->
                u.text(
                        """
                What is the current time in {city}?
                """)
                    .param("city", city))
        .call()
        .content();
  }

  @Operation(
      summary = "Get day of week for a city",
      description = "Tool calling with timezone lookup")
  @ApiResponse(
      responseCode = "200",
      description = "Day of week for tomorrow in the specified city",
      content =
          @Content(examples = @ExampleObject(value = "Tomorrow in Toronto will be Wednesday.")))
  @GetMapping("/dayOfWeek")
  public String tomorrow(
      @Parameter(description = "City name to get the day of week for", example = "Toronto")
          @RequestParam(value = "city", defaultValue = "Toronto")
          String city) {

    return chatClient
        .prompt()
        .tools(new TimeTools())
        .system("You must call the currentTimeIn tool. Answer in one short sentence.")
        .user(
            u ->
                u.text(
                        """
                What day of the week is tomorrow in {city}?
                """)
                    .param("city", city))
        .call()
        .content();
  }

  @Operation(
      summary = "Get weather for a city",
      description = "Tool calling: AI invokes weatherFunction bean")
  @ApiResponse(
      responseCode = "200",
      description = "Current weather in the specified city",
      content =
          @Content(
              examples =
                  @ExampleObject(value = "The current weather in Toronto is 15°C and cloudy.")))
  @GetMapping("/weather")
  public String getWeather(
      @Parameter(description = "City name to get the weather for", example = "Toronto")
          @RequestParam(value = "city", defaultValue = "Toronto")
          String city) {

    return chatClient
        .prompt()
        .toolNames("weatherFunction")
        .user(
            u ->
                u.text(
                        """
                What is the current weather in {city}?
                """)
                    .param("city", city))
        .call()
        .content();
  }

  @Operation(
      summary = "Get packing suggestions",
      description = "Tool calling: combines weather + packing advice")
  @ApiResponse(
      responseCode = "200",
      description = "Clothing packing suggestions for the specified city",
      content =
          @Content(
              examples =
                  @ExampleObject(
                      value =
                          "For Toronto's 15°C weather, pack a light jacket, jeans, and layers.")))
  @GetMapping("/pack")
  public String getClothingRecommendation(
      @Parameter(description = "City name to get packing suggestions for", example = "Toronto")
          @RequestParam(value = "city", defaultValue = "Toronto")
          String city) {

    return chatClient
        .prompt()
        .toolNames("weatherFunction")
        .user(
            u ->
                u.text(
                        """
                I am traveling to {city} tomorrow. what kind of clothes should I pack?
                """)
                    .param("city", city))
        .call()
        .content();
  }

  @Operation(
      summary = "Search for restaurants",
      description =
          "Tool calling with returnDirect: AI calls search function and returns results directly")
  @ApiResponse(
      responseCode = "200",
      description = "List of matching restaurants",
      content =
          @Content(
              examples =
                  @ExampleObject(
                      value =
                          "[{\"name\": \"La Piazza\", \"cuisine\": \"Italian\", \"stars\": 4, \"description\": \"Cozy Italian restaurant\"}]")))
  @GetMapping("/search")
  public List<Restaurant> search(
      @Parameter(
              description = "Natural language search query for restaurants",
              example = "find me an italian restaurant for lunch for 4 people today")
          @RequestParam(
              value = "query",
              defaultValue = "find me an italian restaurant for lunch for 4 people today")
          String query) {

    // RestaurantSearch uses returnDirect=true, so the tool result is returned directly
    // We use content() and parse it, since entity() conflicts with returnDirect in Spring AI 2.0
    String content =
        this.chatClient
            .prompt()
            .tools(new RestaurantSearch(), new TimeTools())
            .system(
                "Today is "
                    + java.time.LocalDate.now()
                    + ". Default time is 12:00. Default star rating is 3. "
                    + "Always call the search tool with all required parameters.")
            .user(query)
            .call()
            .content();

    try {
      return java.util.Arrays.asList(
          new tools.jackson.databind.json.JsonMapper().readValue(content, Restaurant[].class));
    } catch (Exception e) {
      // If the LLM returned prose instead of JSON, wrap it in a single result
      return java.util.List.of(new Restaurant("Search Result", "various", 0, content));
    }
  }
}
