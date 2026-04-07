package com.example.dashboard;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicReference;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;

@Component
public class OpenApiSpecReader {

  private static final Logger log = LoggerFactory.getLogger(OpenApiSpecReader.class);
  private static final ObjectMapper mapper = new ObjectMapper();

  private final RestClient restClient;
  private final AtomicReference<List<StageDefinition>> cache = new AtomicReference<>();

  public OpenApiSpecReader(@Value("${server.port:8080}") int port) {
    this.restClient = RestClient.builder().baseUrl("http://localhost:" + port).build();
  }

  public List<StageDefinition> getStages() {
    List<StageDefinition> cached = cache.get();
    if (cached != null) {
      return cached;
    }
    List<StageDefinition> stages = loadStages();
    cache.set(stages);
    return stages;
  }

  public void invalidateCache() {
    cache.set(null);
  }

  private List<StageDefinition> loadStages() {
    List<StageDefinition> defaults = StageDefinition.defaults();
    try {
      String json = restClient.get().uri("/v3/api-docs").retrieve().body(String.class);

      if (json == null || json.isBlank()) {
        log.warn("Empty response from /v3/api-docs, returning defaults");
        return defaults;
      }

      JsonNode root = mapper.readTree(json);
      JsonNode paths = root.get("paths");
      if (paths == null) {
        return defaults;
      }

      List<StageDefinition> enriched = new ArrayList<>();
      for (StageDefinition stage : defaults) {
        List<StageDefinition.EndpointInfo> endpoints = new ArrayList<>();

        for (Map.Entry<String, JsonNode> pathEntry : paths.properties()) {
          String path = pathEntry.getKey();
          JsonNode pathNode = pathEntry.getValue();

          for (Map.Entry<String, JsonNode> methodEntry : pathNode.properties()) {
            String method = methodEntry.getKey().toUpperCase();
            JsonNode operation = methodEntry.getValue();

            if (matchesStage(operation, stage.tagName())) {
              endpoints.add(buildEndpointInfo(path, method, operation));
            }
          }
        }

        endpoints.sort(
            Comparator.comparing(StageDefinition.EndpointInfo::group)
                .thenComparingInt(e -> endpointOrder(e.path())));

        enriched.add(
            new StageDefinition(
                stage.number(),
                stage.name(),
                stage.shortName(),
                stage.tagName(),
                stage.description(),
                stage.accentColor(),
                endpoints));
      }
      return enriched;

    } catch (Exception e) {
      log.warn("Failed to load OpenAPI spec: {}", e.getMessage());
      return defaults;
    }
  }

  private boolean matchesStage(JsonNode operation, String tagName) {
    JsonNode tags = operation.get("tags");
    if (tags == null || !tags.isArray()) {
      return false;
    }
    for (JsonNode tag : tags) {
      if (tagName.equals(tag.asText())) {
        return true;
      }
    }
    return false;
  }

  private StageDefinition.EndpointInfo buildEndpointInfo(
      String path, String method, JsonNode operation) {
    String summary = textOrEmpty(operation, "summary");
    String description = textOrEmpty(operation, "description");
    String group = extractGroup(path);
    List<StageDefinition.ParamInfo> params = extractParams(operation);
    String viewType = inferViewType(path);

    return new StageDefinition.EndpointInfo(
        path, method, summary, description, group, params, viewType);
  }

  private String extractGroup(String path) {
    // e.g. /chat/02/client/joke -> chat_02, /embed/01/text -> embed_01
    String[] parts = path.split("/");
    if (parts.length >= 3) {
      return parts[1] + "_" + parts[2];
    }
    if (parts.length > 1) {
      return parts[1];
    }
    return "";
  }

  private List<StageDefinition.ParamInfo> extractParams(JsonNode operation) {
    List<StageDefinition.ParamInfo> params = new ArrayList<>();
    JsonNode parameters = operation.get("parameters");
    if (parameters != null && parameters.isArray()) {
      for (JsonNode param : parameters) {
        String name = textOrEmpty(param, "name");
        String desc = textOrEmpty(param, "description");
        String example = "";
        // Check param-level example first, then schema-level
        if (param.has("example")) {
          example = param.get("example").asText();
        }
        List<String> allowedValues = new ArrayList<>();
        JsonNode schema = param.get("schema");
        if (schema != null) {
          if (example.isEmpty() && schema.has("example")) {
            example = schema.get("example").asText();
          }
          if (schema.has("enum") && schema.get("enum").isArray()) {
            for (JsonNode v : schema.get("enum")) {
              allowedValues.add(v.asText());
            }
            if (example.isEmpty() && !allowedValues.isEmpty()) {
              example = allowedValues.getLast();
            }
          }
        }
        boolean required = param.has("required") && param.get("required").asBoolean();
        params.add(new StageDefinition.ParamInfo(name, desc, example, required, allowedValues));
      }
    }
    return params;
  }

  String inferViewType(String path) {
    if (path.contains("/chat/08")) {
      return "streaming";
    }
    if (path.contains("/chat/04")) {
      return "json";
    }
    if (path.contains("/embed/02")) {
      return "similarity";
    }
    if (path.contains("/embed/01") || path.contains("/embed/03") || path.contains("/embed/04")) {
      return "json";
    }
    if (path.contains("/vector/01/query")) {
      return "text";
    }
    if (path.contains("/vector/")) {
      return "json";
    }
    if (path.contains("/mem/")
        || path.contains("/stuffit/")
        || path.contains("/rag/01/query")
        || path.contains("/rag/02/query")) {
      return "chat";
    }
    if (path.contains("/cot/bio/flow")) {
      return "accordion";
    }
    if (path.contains("/reflection/bio/agent")) {
      return "accordion";
    }
    return "text";
  }

  private static int endpointOrder(String path) {
    // Explicit ordering to match the workshop guide (docs/guide.md).
    // Within a group, endpoints follow pedagogical order rather than alphabetical.
    return switch (path) {
      // Stage 1: chat_05 — time before weather before search
      case "/chat/05/time" -> 0;
      case "/chat/05/dayOfWeek" -> 1;
      case "/chat/05/weather" -> 2;
      case "/chat/05/pack" -> 3;
      case "/chat/05/search" -> 4;
      // Stage 2: embed_01 — text before dimension
      case "/embed/01/text" -> 0;
      case "/embed/01/dimension" -> 1;
      // Stage 2: embed_02 — words before quotes
      case "/embed/02/words" -> 0;
      case "/embed/02/quotes" -> 1;
      // Stage 2: embed_04 — json, text, pdf/pages, pdf/para
      case "/embed/04/json/bikes" -> 0;
      case "/embed/04/text/works" -> 1;
      case "/embed/04/pdf/pages" -> 2;
      case "/embed/04/pdf/para" -> 3;
      // Stage 5: oneshot before multi-step variants
      default -> path.endsWith("/oneshot") ? 0 : 50;
    };
  }

  private String textOrEmpty(JsonNode node, String field) {
    JsonNode child = node.get(field);
    return (child != null && !child.isNull()) ? child.asText() : "";
  }
}
