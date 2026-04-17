package com.example.dashboard.mcp;

import java.util.List;
import org.springframework.stereotype.Component;

@Component
public class McpDemoCatalog {

  private static final List<McpDemo> DEMOS =
      List.of(
          new McpDemo(
              "01",
              "STDIO Server",
              "Weather tools over stdin/stdout — subprocess per request",
              McpDemo.Transport.STDIO,
              null,
              "mcp/01-mcp-stdio-server",
              List.of(McpDemo.Capability.TOOLS)),
          new McpDemo(
              "02",
              "HTTP Server",
              "Weather tools over Streamable HTTP",
              McpDemo.Transport.HTTP,
              8081,
              "mcp/02-mcp-http-server",
              List.of(McpDemo.Capability.TOOLS)),
          new McpDemo(
              "03",
              "MCP Client",
              "ChatClient + ToolCallbackProvider using local or external MCP servers",
              McpDemo.Transport.STDIO,
              null,
              "mcp/03-mcp-client",
              List.of()),
          new McpDemo(
              "04",
              "Dynamic Tool Calling",
              "Register tools at runtime via McpSyncServer.addTool()",
              McpDemo.Transport.HTTP,
              8082,
              "mcp/04-dynamic-tool-calling/server",
              List.of(McpDemo.Capability.TOOLS)),
          new McpDemo(
              "05",
              "Full Capabilities",
              "Tools + Resources + Prompts + Completions",
              McpDemo.Transport.HTTP,
              8083,
              "mcp/05-mcp-capabilities",
              List.of(
                  McpDemo.Capability.TOOLS,
                  McpDemo.Capability.RESOURCES,
                  McpDemo.Capability.PROMPTS)));

  public List<McpDemo> all() {
    return DEMOS;
  }

  public McpDemo get(String id) {
    return DEMOS.stream()
        .filter(d -> d.id().equals(id))
        .findFirst()
        .orElseThrow(() -> new IllegalArgumentException("Unknown MCP demo: " + id));
  }
}
