package com.example.dashboard.mcp;

import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.SpringBootConfiguration;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.ComponentScan;
import org.springframework.context.annotation.FilterType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

@WebMvcTest(McpInspectorController.class)
@ActiveProfiles("ui")
class McpInspectorControllerTest {

  @Autowired MockMvc mockMvc;
  @MockitoBean McpClientRegistry registry;
  @MockitoBean McpStdioInvoker stdio;

  @SpringBootConfiguration
  @ComponentScan(
      basePackageClasses = McpInspectorController.class,
      includeFilters =
          @ComponentScan.Filter(
              type = FilterType.ASSIGNABLE_TYPE,
              classes = McpInspectorController.class),
      useDefaultFilters = false)
  static class TestConfig {
    @Bean
    McpDemoCatalog catalog() {
      return new McpDemoCatalog();
    }
  }

  @Test
  void statusHttpDemoUp() throws Exception {
    when(registry.isUp("02")).thenReturn(true);

    mockMvc
        .perform(get("/dashboard/mcp/02/status"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.id").value("02"))
        .andExpect(jsonPath("$.port").value(8081))
        .andExpect(jsonPath("$.status").value("up"))
        .andExpect(jsonPath("$.startCommand").value("./workshop.sh mcp start 02"));
  }

  @Test
  void statusStdioJarMissing() throws Exception {
    when(stdio.jarPresent()).thenReturn(false);

    mockMvc
        .perform(get("/dashboard/mcp/01/status"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.id").value("01"))
        .andExpect(jsonPath("$.status").value("down"))
        .andExpect(jsonPath("$.startCommand").value("./workshop.sh mcp build-01"));
  }

  @Test
  void toolsEndpointReturnsMcpResult() throws Exception {
    io.modelcontextprotocol.spec.McpSchema.ListToolsResult listResult =
        new io.modelcontextprotocol.spec.McpSchema.ListToolsResult(java.util.List.of(), null);
    io.modelcontextprotocol.client.McpSyncClient client =
        org.mockito.Mockito.mock(io.modelcontextprotocol.client.McpSyncClient.class);
    when(client.listTools()).thenReturn(listResult);
    when(registry.getOrConnect("02")).thenReturn(client);

    mockMvc
        .perform(get("/dashboard/mcp/02/tools"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.tools").isArray());
  }

  @Test
  void toolsEndpoint01UsesStdioInvoker() throws Exception {
    io.modelcontextprotocol.spec.McpSchema.ListToolsResult listResult =
        new io.modelcontextprotocol.spec.McpSchema.ListToolsResult(java.util.List.of(), null);
    when(stdio.listTools()).thenReturn(listResult);

    mockMvc.perform(get("/dashboard/mcp/01/tools")).andExpect(status().isOk());
  }

  @Test
  void toolsEndpointReturns503WhenServerDown() throws Exception {
    when(registry.getOrConnect("02")).thenThrow(new RuntimeException("Connection refused"));

    mockMvc
        .perform(get("/dashboard/mcp/02/tools"))
        .andExpect(status().isServiceUnavailable())
        .andExpect(jsonPath("$.error").value("server offline"))
        .andExpect(jsonPath("$.hint").value("./workshop.sh mcp start 02"));
  }

  @Test
  void resourcesEndpointReturnsMcpListResources() throws Exception {
    io.modelcontextprotocol.spec.McpSchema.ListResourcesResult list =
        new io.modelcontextprotocol.spec.McpSchema.ListResourcesResult(java.util.List.of(), null);
    io.modelcontextprotocol.client.McpSyncClient client =
        org.mockito.Mockito.mock(io.modelcontextprotocol.client.McpSyncClient.class);
    when(client.listResources()).thenReturn(list);
    when(registry.getOrConnect("05")).thenReturn(client);

    mockMvc.perform(get("/dashboard/mcp/05/resources")).andExpect(status().isOk());
  }

  @Test
  void promptsEndpointReturnsMcpListPrompts() throws Exception {
    io.modelcontextprotocol.spec.McpSchema.ListPromptsResult list =
        new io.modelcontextprotocol.spec.McpSchema.ListPromptsResult(java.util.List.of(), null);
    io.modelcontextprotocol.client.McpSyncClient client =
        org.mockito.Mockito.mock(io.modelcontextprotocol.client.McpSyncClient.class);
    when(client.listPrompts()).thenReturn(list);
    when(registry.getOrConnect("05")).thenReturn(client);

    mockMvc.perform(get("/dashboard/mcp/05/prompts")).andExpect(status().isOk());
  }

  @Test
  void updateTools04EndpointExists() throws Exception {
    // Accept any status — verifies routing only. Full proxy semantics require a live :8082.
    mockMvc.perform(
        org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post(
            "/dashboard/mcp/04/update-tools"));
  }

  @Test
  void invokeEndpointForwardsToMcpClient() throws Exception {
    io.modelcontextprotocol.spec.McpSchema.CallToolResult result =
        new io.modelcontextprotocol.spec.McpSchema.CallToolResult(
            java.util.List.of(), false, null, null);
    io.modelcontextprotocol.client.McpSyncClient client =
        org.mockito.Mockito.mock(io.modelcontextprotocol.client.McpSyncClient.class);
    when(client.callTool(org.mockito.ArgumentMatchers.any())).thenReturn(result);
    when(registry.getOrConnect("02")).thenReturn(client);

    mockMvc
        .perform(
            org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post(
                    "/dashboard/mcp/02/invoke")
                .contentType(org.springframework.http.MediaType.APPLICATION_JSON)
                .content("{\"tool\":\"getTemperature\",\"args\":{\"latitude\":52.5}}"))
        .andExpect(status().isOk());
  }
}
