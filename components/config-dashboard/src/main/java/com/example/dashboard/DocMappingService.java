package com.example.dashboard;

import java.io.IOException;
import java.nio.file.DirectoryStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

@Component
@Profile("ui")
class DocMappingService {

  private static final Logger log = LoggerFactory.getLogger(DocMappingService.class);

  private static final Pattern ENDPOINT_PATH_PATTERN =
      Pattern.compile("`(?:GET|POST)\\s+(/[^`?|]+)");

  private record DocRef(String fileContent, int sectionStart, int sectionEnd) {}

  private final Map<String, DocRef> pathToDoc = new HashMap<>();

  DocMappingService(@Value("${dashboard.docs.path:docs/spring-ai}") String docsPath) {
    Path basePath = resolveDocsPath(docsPath);
    if (basePath == null) {
      log.warn("Documentation path not found — inline docs disabled");
      return;
    }
    log.info("DocMappingService using docs at: {}", basePath);

    try (DirectoryStream<Path> stream =
        Files.newDirectoryStream(basePath, "SPRING_AI_STAGE_*.md")) {
      for (Path file : stream) {
        parseFile(file);
      }
    } catch (IOException e) {
      log.warn("Failed to read documentation files: {}", e.getMessage());
    }

    log.info("DocMappingService loaded {} endpoint-to-doc mappings", pathToDoc.size());
  }

  Optional<DocSection> getDocForPath(String endpointPath) {
    String cleaned = endpointPath.split("\\?")[0];
    DocRef ref = pathToDoc.get(cleaned);

    if (ref == null) {
      String prefix = extractPrefix(cleaned);
      if (prefix != null) {
        for (Map.Entry<String, DocRef> entry : pathToDoc.entrySet()) {
          if (entry.getKey().startsWith(prefix)) {
            ref = entry.getValue();
            break;
          }
        }
      }
    }

    if (ref == null) {
      return Optional.empty();
    }

    String fullSection = ref.fileContent().substring(ref.sectionStart(), ref.sectionEnd()).trim();
    String codeSnippet = extractSubsection(fullSection, "### Key Code");
    return Optional.of(new DocSection(fullSection, codeSnippet));
  }

  private void parseFile(Path file) {
    String content;
    try {
      content = Files.readString(file);
    } catch (IOException e) {
      log.warn("Failed to read {}: {}", file, e.getMessage());
      return;
    }

    List<int[]> sections = findSections(content, "## Demo ");

    for (int[] section : sections) {
      String sectionText = content.substring(section[0], section[1]);
      List<String> paths = extractEndpointPaths(sectionText);

      DocRef ref = new DocRef(content, section[0], section[1]);
      for (String path : paths) {
        pathToDoc.put(path, ref);
      }
    }
  }

  private List<int[]> findSections(String content, String headingPrefix) {
    List<int[]> sections = new ArrayList<>();
    String[] lines = content.split("\n");
    int currentStart = -1;
    int charPos = 0;

    for (int i = 0; i < lines.length; i++) {
      String line = lines[i];
      if (line.startsWith(headingPrefix)) {
        if (currentStart >= 0) {
          sections.add(new int[] {currentStart, charPos});
        }
        currentStart = charPos;
      } else if (line.startsWith("## ") && currentStart >= 0) {
        sections.add(new int[] {currentStart, charPos});
        currentStart = -1;
      }
      charPos += line.length() + 1;
    }

    if (currentStart >= 0) {
      sections.add(new int[] {currentStart, content.length()});
    }

    return sections;
  }

  private List<String> extractEndpointPaths(String sectionText) {
    List<String> paths = new ArrayList<>();
    for (String line : sectionText.split("\n")) {
      if (line.contains("**Endpoint") && line.contains("`")) {
        extractPathsFromLine(line, paths);
      }
      if (line.startsWith("- `") && line.contains("GET /") || line.contains("POST /")) {
        extractPathsFromLine(line, paths);
      }
    }
    return paths;
  }

  private void extractPathsFromLine(String line, List<String> paths) {
    Matcher matcher = ENDPOINT_PATH_PATTERN.matcher(line);
    while (matcher.find()) {
      String path = matcher.group(1).trim();
      if (path.endsWith("/")) {
        path = path.substring(0, path.length() - 1);
      }
      paths.add(path);
    }
  }

  private String extractSubsection(String section, String heading) {
    int start = section.indexOf(heading);
    if (start < 0) {
      return "";
    }

    int end = section.length();
    int searchFrom = start + heading.length();
    int nextH3 = section.indexOf("\n### ", searchFrom);
    int nextH2 = section.indexOf("\n## ", searchFrom);

    if (nextH3 >= 0 && nextH3 < end) {
      end = nextH3;
    }
    if (nextH2 >= 0 && nextH2 < end) {
      end = nextH2;
    }

    return section.substring(start, end).trim();
  }

  private String extractPrefix(String path) {
    String[] parts = path.split("/");
    if (parts.length >= 3) {
      return "/" + parts[1] + "/" + parts[2];
    }
    return null;
  }

  private static Path resolveDocsPath(String docsPath) {
    // Try direct path first
    Path direct = Paths.get(docsPath);
    if (Files.isDirectory(direct)) {
      return direct;
    }
    // Walk up from cwd to find project root containing docs/spring-ai
    Path current = Paths.get("").toAbsolutePath();
    for (int i = 0; i < 5; i++) {
      Path candidate = current.resolve(docsPath);
      if (Files.isDirectory(candidate)) {
        return candidate;
      }
      current = current.getParent();
      if (current == null) {
        break;
      }
    }
    return null;
  }
}
