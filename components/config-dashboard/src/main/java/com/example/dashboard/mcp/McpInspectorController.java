package com.example.dashboard.mcp;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.context.annotation.Profile;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/dashboard/mcp")
@Profile("ui")
public class McpInspectorController {

  private final McpDemoCatalog catalog;
  private final McpClientRegistry registry;
  private final McpStdioInvoker stdio;
  private final org.springframework.web.client.RestClient restClient =
      org.springframework.web.client.RestClient.create();

  @org.springframework.beans.factory.annotation.Autowired(required = false)
  private org.springframework.ai.chat.client.ChatClient.Builder chatClientBuilder;

  public McpInspectorController(
      McpDemoCatalog catalog, McpClientRegistry registry, McpStdioInvoker stdio) {
    this.catalog = catalog;
    this.registry = registry;
    this.stdio = stdio;
  }

  @GetMapping("/{id}/status")
  public ResponseEntity<Map<String, Object>> status(@PathVariable String id) {
    McpDemo demo = catalog.get(id);
    boolean up;
    String startCommand;
    if (demo.port() == null) {
      up = stdio.jarPresent();
      startCommand = "./workshop.sh mcp build-01";
    } else {
      up = registry.isUp(id);
      startCommand = "./workshop.sh mcp start " + id;
    }
    Map<String, Object> body = new LinkedHashMap<>();
    body.put("id", id);
    body.put("title", demo.title());
    body.put("transport", demo.transport().name());
    body.put("port", demo.port());
    body.put("modulePath", demo.modulePath());
    body.put("capabilities", demo.capabilities().stream().map(Enum::name).toList());
    body.put("status", up ? "up" : "down");
    body.put("startCommand", startCommand);
    return ResponseEntity.ok(body);
  }

  public record InvokeRequest(String tool, Map<String, Object> args) {}

  @org.springframework.web.bind.annotation.PostMapping("/{id}/invoke")
  public ResponseEntity<?> invoke(
      @PathVariable String id,
      @org.springframework.web.bind.annotation.RequestBody InvokeRequest body) {
    McpDemo demo = catalog.get(id);
    Map<String, Object> args = body.args() == null ? Map.of() : body.args();
    try {
      if (demo.port() == null) {
        return ResponseEntity.ok(stdio.callTool(body.tool(), args));
      }
      return ResponseEntity.ok(
          registry
              .getOrConnect(id)
              .callTool(
                  new io.modelcontextprotocol.spec.McpSchema.CallToolRequest(body.tool(), args)));
    } catch (Exception e) {
      return offlineResponse(id, demo, e);
    }
  }

  @GetMapping("/{id}/tools")
  public ResponseEntity<?> tools(@PathVariable String id) {
    McpDemo demo = catalog.get(id);
    try {
      if (demo.port() == null) {
        return ResponseEntity.ok(stdio.listTools());
      }
      return ResponseEntity.ok(registry.getOrConnect(id).listTools());
    } catch (Exception e) {
      return offlineResponse(id, demo, e);
    }
  }

  @GetMapping("/{id}/resources")
  public ResponseEntity<?> resources(@PathVariable String id) {
    McpDemo demo = catalog.get(id);
    if (demo.port() == null) {
      return ResponseEntity.status(400)
          .body(Map.of("error", "resources not supported for STDIO demo"));
    }
    try {
      var client = registry.getOrConnect(id);
      // MCP splits concrete resources and URI templates into two separate calls.
      // The 05 demo only registers templates (user-profile://{username}), so
      // calling only listResources() would return an empty list and look broken.
      var concrete = client.listResources();
      var templates = client.listResourceTemplates();
      Map<String, Object> merged = new LinkedHashMap<>();
      merged.put(
          "resources",
          concrete == null || concrete.resources() == null ? List.of() : concrete.resources());
      merged.put(
          "resourceTemplates",
          templates == null || templates.resourceTemplates() == null
              ? List.of()
              : templates.resourceTemplates());
      return ResponseEntity.ok(merged);
    } catch (Exception e) {
      return offlineResponse(id, demo, e);
    }
  }

  @GetMapping("/{id}/resources/read")
  public ResponseEntity<?> readResource(
      @PathVariable String id, @org.springframework.web.bind.annotation.RequestParam String uri) {
    McpDemo demo = catalog.get(id);
    try {
      return ResponseEntity.ok(
          registry
              .getOrConnect(id)
              .readResource(new io.modelcontextprotocol.spec.McpSchema.ReadResourceRequest(uri)));
    } catch (Exception e) {
      return offlineResponse(id, demo, e);
    }
  }

  @GetMapping("/{id}/prompts")
  public ResponseEntity<?> prompts(@PathVariable String id) {
    McpDemo demo = catalog.get(id);
    if (demo.port() == null) {
      return ResponseEntity.status(400)
          .body(Map.of("error", "prompts not supported for STDIO demo"));
    }
    try {
      return ResponseEntity.ok(registry.getOrConnect(id).listPrompts());
    } catch (Exception e) {
      return offlineResponse(id, demo, e);
    }
  }

  public record PromptGetRequest(String name, Map<String, Object> args) {}

  @org.springframework.web.bind.annotation.PostMapping("/{id}/prompts/get")
  public ResponseEntity<?> getPrompt(
      @PathVariable String id,
      @org.springframework.web.bind.annotation.RequestBody PromptGetRequest body) {
    McpDemo demo = catalog.get(id);
    try {
      Map<String, Object> args = body.args() == null ? Map.of() : body.args();
      return ResponseEntity.ok(
          registry
              .getOrConnect(id)
              .getPrompt(
                  new io.modelcontextprotocol.spec.McpSchema.GetPromptRequest(body.name(), args)));
    } catch (Exception e) {
      return offlineResponse(id, demo, e);
    }
  }

  @org.springframework.web.bind.annotation.PostMapping("/03/run")
  public ResponseEntity<?> run03(
      @org.springframework.web.bind.annotation.RequestParam(defaultValue = "local") String mode) {
    if (chatClientBuilder == null) {
      return ResponseEntity.ok(
          Map.of(
              "mode",
              mode,
              "response",
              "ChatClient not available — run the CLI demo with ./mvnw spring-boot:run -pl"
                  + " mcp/03-mcp-client",
              "degraded",
              true));
    }
    if ("external".equals(mode)) {
      return ResponseEntity.status(400)
          .body(
              Map.of(
                  "error", "external mode not available from the dashboard",
                  "hint",
                      "./mvnw spring-boot:run -pl mcp/03-mcp-client -Dspring-boot.run.profiles=mcp-external",
                  "mode", mode));
    }

    // Local mode: assemble tool callbacks on-demand from whichever MCP servers are live.
    // 01 STDIO is spawned as a subprocess for the duration of the ChatClient call.
    // 02 HTTP uses the long-lived client from McpClientRegistry.
    java.util.List<io.modelcontextprotocol.client.McpSyncClient> clients =
        new java.util.ArrayList<>();
    io.modelcontextprotocol.client.McpSyncClient stdioClient = null;
    try {
      if (stdio.jarPresent()) {
        stdioClient = stdio.openClient();
        clients.add(stdioClient);
      }
      if (registry.isUp("02")) {
        clients.add(registry.getOrConnect("02"));
      }
      if (clients.isEmpty()) {
        return ResponseEntity.status(503)
            .body(
                Map.of(
                    "error", "no local MCP servers available",
                    "hint", "./workshop.sh mcp start all",
                    "mode", mode));
      }

      // Multiple MCP servers may expose identically-named tools (01 and 02 both ship
      // getTemperature). Use DefaultMcpToolNamePrefixGenerator so each tool gets a
      // server-scoped name; without it SyncMcpToolCallbackProvider throws on duplicates.
      org.springframework.ai.tool.ToolCallbackProvider provider =
          org.springframework.ai.mcp.SyncMcpToolCallbackProvider.builder()
              .mcpClients(clients)
              .toolNamePrefixGenerator(
                  new org.springframework.ai.mcp.DefaultMcpToolNamePrefixGenerator())
              .build();

      String question = McpClientDemoPrompts.LOCAL_DEMO_QUESTION;
      String response =
          chatClientBuilder
              .build()
              .prompt()
              .system(McpClientDemoPrompts.SYSTEM)
              .user(question)
              .toolCallbacks(provider)
              .call()
              .content();

      String toolsFrom =
          (stdioClient != null && clients.size() == 2)
              ? "01+02"
              : (stdioClient != null ? "01" : "02");
      return ResponseEntity.ok(
          Map.of(
              "mode", mode,
              "question", question,
              "response", response,
              "toolsFrom", toolsFrom));
    } catch (Exception e) {
      return ResponseEntity.status(500)
          .body(
              Map.of(
                  "error",
                  "MCP demo run failed",
                  "detail",
                  e.getMessage() == null ? "" : e.getMessage(),
                  "mode",
                  mode));
    } finally {
      if (stdioClient != null) {
        try {
          stdioClient.closeGracefully();
        } catch (Exception ignored) {
          // best-effort cleanup
        }
      }
    }
  }

  @org.springframework.web.bind.annotation.PostMapping("/04/update-tools")
  public ResponseEntity<?> trigger04Update() {
    McpDemo demo = catalog.get("04");
    try {
      String response =
          restClient
              .get()
              .uri("http://localhost:" + demo.port() + "/updateTools")
              .retrieve()
              .body(String.class);
      registry.reset("04");
      return ResponseEntity.ok(Map.of("signal", response == null ? "" : response));
    } catch (Exception e) {
      return offlineResponse("04", demo, e);
    }
  }

  private ResponseEntity<Map<String, Object>> offlineResponse(
      String id, McpDemo demo, Exception cause) {
    registry.reset(id);
    String hint =
        demo.port() == null ? "./workshop.sh mcp build-01" : "./workshop.sh mcp start " + id;
    return ResponseEntity.status(503)
        .body(
            Map.of(
                "error",
                "server offline",
                "demo",
                id,
                "hint",
                hint,
                "detail",
                cause.getMessage() == null ? "" : cause.getMessage()));
  }
}
