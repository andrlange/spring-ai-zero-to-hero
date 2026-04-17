package com.example.dashboard;

import com.example.dashboard.mcp.McpDemoCatalog;
import jakarta.servlet.http.HttpServletRequest;
import java.net.URI;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Profile;
import org.springframework.core.env.Environment;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseBody;
import org.springframework.web.client.RestClient;

@Profile("ui")
@Controller
@RequestMapping("/dashboard")
public class DashboardController {

  private final OpenApiSpecReader specReader;
  private final Environment environment;
  private final RestClient restClient;
  private final DocMappingService docMappingService;
  private final McpDemoCatalog mcpCatalog;

  public DashboardController(
      OpenApiSpecReader specReader,
      Environment environment,
      RestClient.Builder restClientBuilder,
      DocMappingService docMappingService,
      @Autowired(required = false) McpDemoCatalog mcpCatalog,
      @Value("${server.port:8080}") int port) {
    this.specReader = specReader;
    this.environment = environment;
    this.restClient = restClientBuilder.baseUrl("http://localhost:" + port).build();
    this.docMappingService = docMappingService;
    this.mcpCatalog = mcpCatalog;
  }

  @GetMapping
  public String home(Model model) {
    List<StageDefinition> stages = specReader.getStages();
    int totalEndpoints = stages.stream().mapToInt(s -> s.endpoints().size()).sum();
    model.addAttribute("stages", stages);
    model.addAttribute("totalEndpoints", totalEndpoints);
    model.addAttribute("activeProfiles", List.of(environment.getActiveProfiles()));
    model.addAttribute("providerName", detectProvider());
    model.addAttribute("chatModel", getChatModel());
    model.addAttribute("activePage", "dashboard");
    return "dashboard/index";
  }

  @GetMapping("/stage/6")
  public String stageMcp(Model model) {
    List<StageDefinition> stages = specReader.getStages();
    model.addAttribute("stage", StageDefinition.mcpStage());
    model.addAttribute("stages", stages);
    model.addAttribute("demos", mcpCatalog == null ? List.of() : mcpCatalog.all());
    model.addAttribute("activePage", "stage-6");
    model.addAttribute("providerName", detectProvider());
    model.addAttribute("activeProfiles", List.of(environment.getActiveProfiles()));
    return "stage/mcp";
  }

  @GetMapping("/stage/{number:[1-5]}")
  public String stage(@PathVariable int number, Model model) {
    List<StageDefinition> stages = specReader.getStages();
    StageDefinition stage =
        stages.stream()
            .filter(s -> s.number() == number)
            .findFirst()
            .orElseThrow(() -> new IllegalArgumentException("Unknown stage: " + number));
    Map<String, List<StageDefinition.EndpointInfo>> grouped =
        stage.endpoints().stream()
            .collect(
                Collectors.groupingBy(
                    StageDefinition.EndpointInfo::group,
                    java.util.LinkedHashMap::new,
                    Collectors.toList()));
    // Build a map of endpoint path+method -> params JSON for use in templates
    Map<String, String> paramsJson = new java.util.LinkedHashMap<>();
    for (StageDefinition.EndpointInfo ep : stage.endpoints()) {
      String key = ep.method() + " " + ep.path();
      StringBuilder sb = new StringBuilder("[");
      for (int i = 0; i < ep.params().size(); i++) {
        StageDefinition.ParamInfo p = ep.params().get(i);
        if (i > 0) {
          sb.append(",");
        }
        sb.append("{\"name\":\"")
            .append(escapeJson(p.name()))
            .append("\",\"description\":\"")
            .append(escapeJson(p.description()))
            .append("\",\"example\":\"")
            .append(escapeJson(p.example()))
            .append("\",\"required\":")
            .append(p.required())
            .append(",\"allowedValues\":[");
        for (int j = 0; j < p.allowedValues().size(); j++) {
          if (j > 0) sb.append(",");
          sb.append("\"").append(escapeJson(p.allowedValues().get(j))).append("\"");
        }
        sb.append("]}");
      }
      sb.append("]");
      paramsJson.put(key, sb.toString());
    }

    model.addAttribute("stage", stage);
    model.addAttribute("stages", stages);
    model.addAttribute("groupedEndpoints", grouped);
    model.addAttribute("groupDescriptions", getGroupDescriptions());
    model.addAttribute("paramsJson", paramsJson);
    model.addAttribute("activePage", "stage-" + number);
    model.addAttribute("providerName", detectProvider());
    model.addAttribute("activeProfiles", List.of(environment.getActiveProfiles()));
    model.addAttribute(
        "spyEnabled", Arrays.asList(environment.getActiveProfiles()).contains("spy"));
    return "stage/detail";
  }

  @GetMapping("/docs")
  @ResponseBody
  public ResponseEntity<Map<String, String>> docs(@RequestParam String path) {
    return docMappingService
        .getDocForPath(path)
        .map(
            doc ->
                ResponseEntity.ok(
                    Map.of("fullSection", doc.fullSection(), "codeSnippet", doc.codeSnippet())))
        .orElse(ResponseEntity.notFound().build());
  }

  @GetMapping("/proxy")
  @ResponseBody
  public ResponseEntity<String> proxy(@RequestParam String path, HttpServletRequest request) {
    StringBuilder targetUrl = new StringBuilder(path);
    String queryString = request.getQueryString();
    if (queryString != null) {
      String filtered =
          Arrays.stream(queryString.split("&"))
              .filter(p -> !p.startsWith("path="))
              .collect(Collectors.joining("&"));
      if (!filtered.isEmpty()) {
        targetUrl.append("?").append(filtered);
      }
    }
    try {
      long start = System.currentTimeMillis();
      String body =
          restClient.get().uri(URI.create(targetUrl.toString())).retrieve().body(String.class);
      long elapsed = System.currentTimeMillis() - start;
      return ResponseEntity.ok().header("X-Response-Time", elapsed + "ms").body(body);
    } catch (Exception e) {
      return ResponseEntity.status(500).body("Error: " + e.getMessage());
    }
  }

  private String detectProvider() {
    String appName = environment.getProperty("spring.application.name", "unknown");
    return appName.replace("-provider", "").replace("provider-", "");
  }

  private static String escapeJson(String value) {
    if (value == null) {
      return "";
    }
    return value.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n");
  }

  private static Map<String, String> getGroupDescriptions() {
    return Map.ofEntries(
        Map.entry("chat_01", "Basic ChatModel — simplest AI call"),
        Map.entry("chat_02", "ChatClient vs ChatModel API comparison"),
        Map.entry("chat_03", "Prompt templates with {variables}"),
        Map.entry("chat_04", "Structured output — List, Map, Java records"),
        Map.entry("chat_05", "Tool/function calling — AI invokes your Java methods"),
        Map.entry("chat_06", "System roles — AI personality via system prompt"),
        Map.entry("chat_07", "Multimodal — image + text input"),
        Map.entry("chat_08", "Streaming — server-sent events, token by token"),
        Map.entry("embed_01", "Basic embeddings — vector from text"),
        Map.entry("embed_02", "Cosine similarity — semantic comparison"),
        Map.entry("embed_03", "Large documents — context limits and chunking"),
        Map.entry("embed_04", "Document readers — JSON, text, PDF"),
        Map.entry("vector_01", "Vector store — load and semantic search"),
        Map.entry("stuffit_01", "Stuff-the-prompt — inject context manually"),
        Map.entry("rag_01", "Manual RAG — search, stuff, generate"),
        Map.entry("rag_02", "Advisor RAG — QuestionAnswerAdvisor"),
        Map.entry("mem_01", "Stateless chat — no memory baseline"),
        Map.entry("mem_02", "Chat memory — conversation history"),
        Map.entry("cot_bio", "Chain of thought — single vs multi-step"),
        Map.entry("reflection_bio", "Self-reflection — writer + critic loop"));
  }

  private String getChatModel() {
    String[] prefixes = {
      "spring.ai.ollama.chat.options.model",
      "spring.ai.openai.chat.options.model",
      "spring.ai.anthropic.chat.options.model"
    };
    for (String prefix : prefixes) {
      String val = environment.getProperty(prefix);
      if (val != null) {
        return val;
      }
    }
    return "default";
  }
}
