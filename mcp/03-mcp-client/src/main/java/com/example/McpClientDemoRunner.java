package com.example;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.ai.tool.ToolCallbackProvider;
import org.springframework.stereotype.Component;

@Component
public class McpClientDemoRunner {

  private static final Logger logger = LoggerFactory.getLogger(McpClientDemoRunner.class);

  private final ChatClient.Builder chatClientBuilder;
  private final ToolCallbackProvider tools;

  public McpClientDemoRunner(ChatClient.Builder chatClientBuilder, ToolCallbackProvider tools) {
    this.chatClientBuilder = chatClientBuilder;
    this.tools = tools;
  }

  public Result run(String mode) {
    String question =
        "external".equals(mode)
            ? "Does the Spring IO 2025 conference have sessions about Spring AI and Model"
                + " Context Protocol? Please provide references."
            : "Call the weather tool for Berlin (latitude 52.52, longitude 13.41) and summarize.";
    logger.info("Running 03 demo in '{}' mode — question: {}", mode, question);

    String response =
        chatClientBuilder
            .build()
            .prompt()
            .system("You are a useful assistant that can call MCP tools.")
            .user(question)
            .toolCallbacks(tools)
            .call()
            .content();

    logger.info("Response: {}", response);
    return new Result(mode, question, response);
  }

  public record Result(String mode, String question, String response) {}
}
