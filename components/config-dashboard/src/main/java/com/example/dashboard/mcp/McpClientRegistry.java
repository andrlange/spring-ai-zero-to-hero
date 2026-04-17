package com.example.dashboard.mcp;

import io.modelcontextprotocol.client.McpClient;
import io.modelcontextprotocol.client.McpSyncClient;
import io.modelcontextprotocol.client.transport.HttpClientStreamableHttpTransport;
import jakarta.annotation.PreDestroy;
import java.net.Socket;
import java.time.Duration;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

@Component
@Profile("ui")
public class McpClientRegistry {

  private static final Logger log = LoggerFactory.getLogger(McpClientRegistry.class);
  private static final Duration REQUEST_TIMEOUT = Duration.ofSeconds(30);

  private final McpDemoCatalog catalog;
  private final ConcurrentMap<String, McpSyncClient> clients = new ConcurrentHashMap<>();

  public McpClientRegistry(McpDemoCatalog catalog) {
    this.catalog = catalog;
  }

  public McpSyncClient getOrConnect(String demoId) {
    return clients.computeIfAbsent(demoId, this::connect);
  }

  public boolean isUp(String demoId) {
    McpDemo demo = catalog.get(demoId);
    if (demo.port() == null) {
      return false;
    }
    return probePort(demo.port());
  }

  public void reset(String demoId) {
    McpSyncClient client = clients.remove(demoId);
    if (client != null) {
      try {
        client.closeGracefully();
      } catch (Exception e) {
        log.warn("Error closing MCP client for {}: {}", demoId, e.getMessage());
      }
    }
  }

  boolean probePort(int port) {
    try (Socket ignored = new Socket("localhost", port)) {
      return true;
    } catch (Exception e) {
      return false;
    }
  }

  @PreDestroy
  void shutdown() {
    clients.forEach(
        (id, client) -> {
          try {
            client.closeGracefully();
          } catch (Exception e) {
            log.warn("Error closing MCP client for {}: {}", id, e.getMessage());
          }
        });
    clients.clear();
  }

  private McpSyncClient connect(String demoId) {
    McpDemo demo = catalog.get(demoId);
    if (demo.port() == null) {
      throw new IllegalStateException(
          "Cannot connect to STDIO demo " + demoId + " via McpClientRegistry");
    }
    log.info("Connecting MCP client to {} at :{}", demoId, demo.port());
    var transport =
        HttpClientStreamableHttpTransport.builder("http://localhost:" + demo.port())
            .endpoint("/mcp")
            .build();
    McpSyncClient client = McpClient.sync(transport).requestTimeout(REQUEST_TIMEOUT).build();
    client.initialize();
    return client;
  }
}
