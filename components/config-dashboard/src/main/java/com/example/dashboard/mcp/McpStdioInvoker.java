package com.example.dashboard.mcp;

import io.modelcontextprotocol.client.McpClient;
import io.modelcontextprotocol.client.McpSyncClient;
import io.modelcontextprotocol.client.transport.ServerParameters;
import io.modelcontextprotocol.client.transport.StdioClientTransport;
import io.modelcontextprotocol.json.McpJsonDefaults;
import io.modelcontextprotocol.spec.McpSchema.CallToolRequest;
import io.modelcontextprotocol.spec.McpSchema.CallToolResult;
import io.modelcontextprotocol.spec.McpSchema.ListToolsResult;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.time.Duration;
import java.util.Map;
import java.util.function.Function;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

@Component
@Profile("ui")
public class McpStdioInvoker {

  private static final Logger log = LoggerFactory.getLogger(McpStdioInvoker.class);
  private static final Duration REQUEST_TIMEOUT = Duration.ofSeconds(10);

  private final String jarPath;

  public McpStdioInvoker(
      @Value(
              "${dashboard.mcp.stdio.jar-path:mcp/01-mcp-stdio-server/target/01-mcp-stdio-server-0.0.1-SNAPSHOT.jar}")
          String jarPath) {
    this.jarPath = jarPath;
  }

  public boolean jarPresent() {
    return Files.exists(Paths.get(jarPath));
  }

  public String jarPath() {
    return jarPath;
  }

  public ListToolsResult listTools() {
    return withClient(McpSyncClient::listTools);
  }

  public CallToolResult callTool(String name, Map<String, Object> args) {
    return withClient(c -> c.callTool(new CallToolRequest(name, args)));
  }

  <T> T withClient(Function<McpSyncClient, T> fn) {
    if (!jarPresent()) {
      throw new IllegalStateException("STDIO jar not built at " + jarPath);
    }
    var params =
        ServerParameters.builder("java")
            .args(
                "-Dspring.ai.mcp.server.stdio=true",
                "-Dspring.main.web-application-type=none",
                "-Dlogging.pattern.console=",
                "-jar",
                jarPath)
            .build();
    var transport = new StdioClientTransport(params, McpJsonDefaults.getMapper());
    McpSyncClient client = McpClient.sync(transport).requestTimeout(REQUEST_TIMEOUT).build();
    try {
      client.initialize();
      return fn.apply(client);
    } finally {
      try {
        client.closeGracefully();
      } catch (Exception e) {
        log.warn("Error closing STDIO client: {}", e.getMessage());
      }
    }
  }
}
