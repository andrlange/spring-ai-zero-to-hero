# Upgrade Plan — Spring Boot 4.0.5 + Spring AI 2.0.0-M4

Precise step-by-step migration from the current stack to the target stack.

## Version Matrix

| Component | Current | Target |
|-----------|---------|--------|
| Spring Boot | 3.5.6 | 4.0.5 |
| Spring AI | 1.0.3 | 2.0.0-M4 |
| Spring Framework | 6.2.x | 7.x |
| Java | 21 | 25 |
| Maven (wrapper) | 3.9.9 | 3.9.14 |
| Spring Cloud | 2025.0.0 | 2025.1.x |
| Spring Shell | 3.4.1 | 4.0.x |
| Jackson | 2.x | 3.0 |
| Hibernate | 6.x | 7.1 |
| Flyway | 10.x | 11.11 |
| Micrometer | 1.14.x | 1.16 |
| Brave | 5.x | 6.3 |
| pgvector Docker | pg17 | pg18 |

---

## Phase 1: Root POM & Build Tooling

**Priority: CRITICAL — everything depends on this**

### 1.1 Update root `pom.xml`

```xml
<!-- Parent: 3.5.6 → 4.0.5 -->
<parent>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-parent</artifactId>
    <version>4.0.5</version>
</parent>

<!-- Properties -->
<properties>
    <java.version>25</java.version>
    <spring-ai.version>2.0.0-M4</spring-ai.version>
    <spring-cloud.version>2025.1.2</spring-cloud.version>
    <spring-cloud-azure.version>6.1.0</spring-cloud-azure.version>  <!-- verify compatibility -->
    <spring-shell.version>4.0.2</spring-shell.version>
    <spotless.version>2.46.1</spotless.version>  <!-- verify google-java-format JDK 25 -->
    <!-- REMOVE loki-logback-appender.version — replaced by OTel -->
</properties>
```

Remove from `<dependencyManagement>`:
```xml
<!-- REMOVE — no longer needed with OTel -->
<dependency>
    <groupId>com.github.loki4j</groupId>
    <artifactId>loki-logback-appender</artifactId>
    <version>${loki-logback-appender.version}</version>
</dependency>
```

### 1.2 Update Maven Wrapper

**File: `.mvn/wrapper/maven-wrapper.properties`**

```properties
distributionUrl=https://repo.maven.apache.org/maven2/org/apache/maven/apache-maven/3.9.14/apache-maven-3.9.14-bin.zip
```

### 1.3 Verification

```bash
./mvnw help:effective-pom -pl . -N | grep -E "<spring-boot|<java.version|<spring-ai"
./mvnw dependency:resolve -N
```

---

## Phase 2: Flyway Dependency Migration

**Priority: CRITICAL — Spring Boot 4 will not auto-configure Flyway without the starter**

Reference: Confirmed working in profi-ota with Spring Boot 4.0.5.

### 2.1 `applications/provider-openai/pom.xml`

Replace:
```xml
<!-- REMOVE -->
<dependency>
    <groupId>org.flywaydb</groupId>
    <artifactId>flyway-core</artifactId>
</dependency>

<!-- ADD -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-flyway</artifactId>
</dependency>
```

Keep `flyway-database-postgresql` unchanged.

### 2.2 `applications/provider-ollama/pom.xml`

Same change: `flyway-core` → `spring-boot-starter-flyway`.

### 2.3 Verification

```bash
./mvnw dependency:tree -pl applications/provider-openai | grep flyway
# Should show: spring-boot-starter-flyway → spring-boot-flyway → flyway-core (transitive)
```

---

## Phase 3: MCP Transport — SSE to Streamable HTTP

**Priority: HIGH — SSE transport is deprecated/removed in Spring AI 2.0**

### 3.1 Affected Modules

| Module | Current | Change To |
|--------|---------|-----------|
| `mcp/01-basic-stdio-mcp-server` | STDIO | No change |
| `mcp/02-basic-http-mcp-server` | SSE (webflux) | Streamable HTTP (webmvc) |
| `mcp/03-basic-mcp-client` | STDIO | No change |
| `mcp/04-dynamic-tool-calling/server` | SSE (webflux) | Streamable HTTP (webmvc) |
| `mcp/04-dynamic-tool-calling/client` | SSE config | HTTP config |
| `mcp/05-mcp-capabilities` | SSE (webmvc) | Streamable HTTP (webmvc) |

### 3.2 Module: `mcp/02-basic-http-mcp-server`

**pom.xml:**
```xml
<!-- REPLACE -->
<artifactId>spring-ai-starter-mcp-server-webflux</artifactId>
<!-- WITH -->
<artifactId>spring-ai-starter-mcp-server-webmvc</artifactId>
```

**src/test/java/.../ClientHttp.java:**
- Replace `WebFluxSseClientTransport` with Streamable HTTP client transport
- Update connection URL/config accordingly

**application.yaml:**
- Remove any SSE-specific config
- Configure Streamable HTTP transport

### 3.3 Module: `mcp/04-dynamic-tool-calling`

**server/pom.xml:**
```xml
<!-- REPLACE -->
<artifactId>spring-ai-starter-mcp-server-webflux</artifactId>
<!-- WITH -->
<artifactId>spring-ai-starter-mcp-server-webmvc</artifactId>
```

**client/application.yaml:**
```yaml
# REPLACE
spring.ai.mcp.client.sse:
  connections:
    04-dynamic-tool-calling:
      url: http://localhost:8080

# WITH
spring.ai.mcp.client.http:
  connections:
    04-dynamic-tool-calling:
      url: http://localhost:8080
```

### 3.4 Module: `mcp/05-mcp-capabilities`

**src/test/java/.../ClientSse.java:**
- Replace `HttpClientSseClientTransport` with Streamable HTTP client transport
- Rename file to `ClientHttp.java`

### 3.5 Verification

```bash
./mvnw compile -pl mcp/02-basic-http-mcp-server
./mvnw compile -pl mcp/04-dynamic-tool-calling/server,mcp/04-dynamic-tool-calling/client
./mvnw compile -pl mcp/05-mcp-capabilities
```

---

## Phase 4: Spring AI 2.0.0-M4 API Changes

### 4.1 MCP Annotations Migration (`mcp/05-mcp-capabilities`)

**pom.xml — Remove external dependency:**
```xml
<!-- REMOVE entire dependency -->
<dependency>
    <groupId>com.logaritex.mcp</groupId>
    <artifactId>spring-ai-mcp-annotations</artifactId>
    <version>0.1.0</version>
</dependency>
```

**Java import changes (4 files):**

| File | Old Import | New Import |
|------|-----------|------------|
| `McpServerApplication.java` | `com.logaritex.mcp.spring.SpringAiMcpAnnotationProvider` | `org.springframework.ai.mcp.annotation.provider.*` (verify exact class) |
| `PromptProvider.java` | `com.logaritex.mcp.annotation.McpPrompt` | `org.springframework.ai.mcp.annotation.McpPrompt` |
| `PromptProvider.java` | `com.logaritex.mcp.annotation.McpArg` | `org.springframework.ai.mcp.annotation.McpArg` |
| `UserProfileResourceProvider.java` | `com.logaritex.mcp.annotation.McpResource` | `org.springframework.ai.mcp.annotation.McpResource` |
| `AutocompleteProvider.java` | `com.logaritex.mcp.annotation.McpComplete` | `org.springframework.ai.mcp.annotation.McpComplete` |

Note: The `SpringAiMcpAnnotationProvider.createSync*Specifications()` factory methods may have changed API in Spring AI 2.0. Verify the replacement in the 2.0.0-M4 javadocs.

### 4.2 Google Vertex AI Provider

**`applications/provider-google/pom.xml`:**

Check if starter artifact renamed:
```xml
<!-- May need to change from -->
<artifactId>spring-ai-starter-model-vertex-ai-gemini</artifactId>
<!-- to -->
<artifactId>spring-ai-starter-model-google-genai</artifactId>
```

**Properties (in creds.yaml or application.yaml):**
```yaml
# OLD
spring.ai.vertex.ai.gemini.project-id: my-project
spring.ai.vertex.ai.gemini.location: us-central1
spring.ai.vertex.ai.gemini.chat.options.model: gemini-pro

# NEW
spring.ai.google.genai.project-id: my-project
spring.ai.google.genai.location: us-central1
spring.ai.google.genai.chat.options.model: gemini-2.0-flash
# Or use API key mode (new!):
spring.ai.google.genai.api-key: your-api-key
```

### 4.3 Verify All Spring AI Artifact Names

Run after Phase 1 to check all artifacts resolve:

```bash
./mvnw dependency:resolve 2>&1 | grep "Could not find artifact"
```

Artifacts to validate against 2.0.0-M4 BOM:
- `spring-ai-client-chat` (11 modules)
- `spring-ai-openai` (4 modules)
- `spring-ai-vector-store` (4 modules)
- `spring-ai-advisors-vector-store` (1 module)
- `spring-ai-pdf-document-reader` (3 modules)
- `spring-ai-tika-document-reader` (2 modules)
- `spring-ai-azure-store` (1 module)

### 4.4 Spring AI 2.0 API Changes in Code

| Pattern | Old (1.0.3) | New (2.0.0-M4) | Files |
|---------|------------|-----------------|-------|
| Tool calling options | `OpenAiChatOptions.builder().toolChoice("required")` | `ToolCallingChatOptions.builder()` (provider-agnostic) | `Agent.java` (inner-monologue, model-directed-loop) |
| Structured output | Prompt-based entity mapping | Add `AdvisorParams.ENABLE_NATIVE_STRUCTURED_OUTPUT` | `chat_04/StructuredOutputController.java` |
| Memory + Tools | Separate advisors | `ToolCallAdvisor.disableInternalConversationHistory()` | Agent classes |
| Chat memory constants | `CHAT_MEMORY_RETRIEVE_SIZE_KEY` | `TOP_K` | `ChatHistoryController.java` |
| DefaultUsage | `new DefaultUsage(Long, Long, Long)` | `new DefaultUsage(Integer, Integer, Integer)` | Check if used anywhere |

### 4.5 Verification

```bash
./mvnw compile
```

---

## Phase 5: Docker Infrastructure Updates

### 5.1 PostgreSQL — Upgrade to pg18

**File: `docker/postgres/docker-compose.yaml`**

```yaml
# CHANGE
image: pgvector/pgvector:pg17
# TO
image: pgvector/pgvector:pg18
```

```yaml
# CHANGE pgAdmin version
image: dpage/pgadmin4:9.8.0
# TO
image: dpage/pgadmin4:latest
```

Note: PostgreSQL 18 uses a new data directory structure. If upgrading an existing volume, you may need to drop and recreate:
```bash
docker compose -f docker/postgres/docker-compose.yaml down -v
docker compose -f docker/postgres/docker-compose.yaml up -d
```

### 5.2 Observability — Replace with LGTM Stack

**Replace `docker/observability-stack/docker-compose.yaml` entirely.**

Current (6 containers): maildev, loki, tempo, otel-collector, prometheus, grafana

New (2 containers): maildev + grafana-lgtm

```yaml
services:
  maildev:
    image: maildev/maildev:2.2.1
    container_name: maildev
    ports:
      - "1080:1080"
      - "1025:1025"
    restart: unless-stopped

  grafana-lgtm:
    image: grafana/otel-lgtm:latest
    container_name: grafana-lgtm
    ports:
      - "3000:3000"   # Grafana UI
      - "4317:4317"   # OTLP gRPC
      - "4318:4318"   # OTLP HTTP
    environment:
      - GF_AUTH_ANONYMOUS_ENABLED=true
      - GF_AUTH_ANONYMOUS_ORG_ROLE=Admin
    volumes:
      - grafana-data:/var/lib/grafana
      - ./grafana/dashboards:/otel-lgtm/grafana/conf/provisioning/dashboards/custom:ro
      - ./grafana/provisioning/dashboards.yaml:/otel-lgtm/grafana/conf/provisioning/dashboards/workshop.yaml:ro
      - ./grafana/provisioning/disable-default-dashboards.yaml:/otel-lgtm/grafana/conf/provisioning/dashboards/grafana-dashboards.yaml:ro
    healthcheck:
      test: ["CMD-SHELL", "curl -sf http://localhost:3000/api/health || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s
    labels:
      org.springframework.boot.service-connection: otel-collector
    restart: unless-stopped

volumes:
  grafana-data:
```

### 5.3 Create LGTM Provisioning Files

**New file: `docker/observability-stack/grafana/provisioning/dashboards.yaml`**
```yaml
apiVersion: 1
providers:
  - name: 'Spring AI Workshop Dashboards'
    orgId: 1
    folder: 'Workshop'
    folderUid: 'workshop'
    type: file
    disableDeletion: false
    updateIntervalSeconds: 30
    allowUiUpdates: true
    options:
      path: /otel-lgtm/grafana/conf/provisioning/dashboards/custom
```

**New file: `docker/observability-stack/grafana/provisioning/disable-default-dashboards.yaml`**
```yaml
apiVersion: 1
providers: []
```

### 5.4 Migrate Dashboard JSONs

Move existing dashboards:
```bash
mkdir -p docker/observability-stack/grafana/dashboards
mv docker/observability-stack/grafana/provisioning/dashboards/*.json \
   docker/observability-stack/grafana/dashboards/
```

Update datasource UIDs in each JSON file to match LGTM built-in datasource names. The LGTM image auto-configures datasources — check their UIDs after first start:

```bash
curl -s http://localhost:3000/api/datasources | jq '.[].uid'
```

### 5.5 Remove Obsolete Config Files

After LGTM migration, these files are no longer needed:
- `docker/observability-stack/config/otel-collector.yaml`
- `docker/observability-stack/config/prometheus.yaml`
- `docker/observability-stack/config/tempo.yaml`
- `docker/observability-stack/grafana/grafana.ini`
- `docker/observability-stack/grafana/provisioning/datasources/datasource.yml`
- `docker/observability-stack/grafana/provisioning/dashboards/dashboard.yml`
- `docker/observability-stack/grafana/provisioning/alerting/alerts.yml`

### 5.6 Verification

```bash
docker compose -f docker/observability-stack/docker-compose.yaml down -v
docker compose -f docker/observability-stack/docker-compose.yaml up -d
curl -sf http://localhost:3000/api/health
curl -sf http://localhost:4318/v1/traces -X POST -H "Content-Type: application/json" -d '{}'
```

---

## Phase 6: Application Observability — Brave/Zipkin to OpenTelemetry

### 6.1 Dependencies

**`applications/provider-openai/pom.xml` — Replace:**

```xml
<!-- REMOVE all three -->
<dependency>
    <groupId>io.micrometer</groupId>
    <artifactId>micrometer-tracing-bridge-brave</artifactId>
</dependency>
<dependency>
    <groupId>io.zipkin.reporter2</groupId>
    <artifactId>zipkin-reporter-brave</artifactId>
</dependency>
<dependency>
    <groupId>com.github.loki4j</groupId>
    <artifactId>loki-logback-appender</artifactId>
</dependency>

<!-- ADD -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-opentelemetry</artifactId>
</dependency>
<dependency>
    <groupId>io.opentelemetry.instrumentation</groupId>
    <artifactId>opentelemetry-logback-appender-1.0</artifactId>
    <version>2.24.0-alpha</version>
</dependency>
<!-- AOP for tracing aspects (spring-boot-starter-aop removed in Boot 4) -->
<dependency>
    <groupId>org.springframework</groupId>
    <artifactId>spring-aop</artifactId>
</dependency>
<dependency>
    <groupId>org.aspectj</groupId>
    <artifactId>aspectjweaver</artifactId>
</dependency>
```

Apply the same to any other provider that has observability dependencies.

### 6.2 Application YAML — Observation Profile

**`applications/provider-openai/src/main/resources/application.yaml`**

Replace the observation profile section:

```yaml
---
spring:
  config:
    activate:
      on-profile: observation
  ai:
    chat:
      client:
        observation:
          include-input: true
      observations:
        include-error-logging: true
    vector:
      store:
        observations:
          include-query-response: true

management:
  tracing:
    enabled: true
    sampling:
      probability: 1.0
    propagation:
      type: w3c
  metrics:
    tags:
      application: ${spring.application.name}
  opentelemetry:
    resource-attributes:
      "service.name": ${spring.application.name}
      "service.version": 1.0.0
      "deployment.environment": development
    tracing:
      export:
        otlp:
          endpoint: http://localhost:4318/v1/traces
    logging:
      export:
        otlp:
          endpoint: http://localhost:4318/v1/logs
  otlp:
    metrics:
      export:
        url: http://localhost:4318/v1/metrics
        step: 10s
  endpoints:
    web:
      exposure:
        include: health,info,metrics,prometheus
```

Apply the same pattern to `applications/provider-ollama/src/main/resources/application.yaml`.

### 6.3 Property Renames (Boot 4)

| Old Property | New Property |
|-------------|-------------|
| `management.tracing.enabled` | `management.tracing.export.enabled` |
| `management.zipkin.tracing.endpoint` | REMOVE (replaced by OTel config above) |

### 6.4 OpenTelemetry Configuration Class

Create in shared config or each provider app:

```java
@Configuration
public class OpenTelemetryConfig {

    @Bean
    public Tracer tracer(OpenTelemetry openTelemetry) {
        return openTelemetry.getTracer("spring-ai-workshop", "1.0.0");
    }

    @Bean
    public ObservedAspect observedAspect(ObservationRegistry registry) {
        return new ObservedAspect(registry);
    }
}

@Component
public class InstallOpenTelemetryAppender implements InitializingBean {
    private final OpenTelemetry openTelemetry;

    public InstallOpenTelemetryAppender(OpenTelemetry openTelemetry) {
        this.openTelemetry = openTelemetry;
    }

    @Override
    public void afterPropertiesSet() {
        OpenTelemetryAppender.install(openTelemetry);
    }
}
```

### 6.5 Verification

```bash
# Start LGTM stack
docker compose -f docker/observability-stack/docker-compose.yaml up -d

# Start app with observation
./mvnw spring-boot:run -pl applications/provider-ollama \
  -Dspring-boot.run.profiles=pgvector,observation

# Hit an endpoint
curl "http://localhost:8080/chat/01/joke?topic=spring"

# Check Grafana → Explore → Tempo for traces
open http://localhost:3000
```

---

## Phase 7: Distributed Tracing Pattern (New Module)

Add the vplan-style distributed tracing pattern as a new workshop module.

### 7.1 Create Module: `components/patterns/04-distributed-tracing/`

**Custom annotations:**
- `@TracedEndpoint` — Controller methods, creates root spans (SpanKind.SERVER)
- `@TracedService` — Service methods, creates child spans (SpanKind.INTERNAL)
- `@TracedRepository` — Repository methods, creates child spans (SpanKind.CLIENT)

**AOP Aspects (ordered execution):**
- `ControllerTracingAspect` (Order 1) — Root span with HTTP attributes
- `ServiceTracingAspect` (Order 2) — Child span with module/business attributes
- `RepositoryTracingAspect` (Order 3) — Client span with db.operation attributes

**Trace hierarchy:**
```
HTTP Request
  └→ @TracedEndpoint: "GET /rag/01/query" (SERVER)
      └→ @TracedService: "RagService.query" (INTERNAL)
          └→ @TracedRepository: "VectorStore.similaritySearch" (CLIENT)
              └→ Database query (OTel JDBC auto-instrumentation)
```

### 7.2 Wire Into Provider Apps

Add the tracing module as a dependency to provider apps and annotate existing controllers/services.

---

## Phase 8: Spring Boot 4 Compatibility Fixes

### 8.1 Test Annotations

If any test files use `@MockBean` or `@SpyBean`:

```java
// OLD
import org.springframework.boot.test.mock.mockito.MockBean;
@MockBean private MyService myService;

// NEW
import org.springframework.test.context.bean.override.mockito.MockitoBean;
@MockitoBean private MyService myService;
```

### 8.2 spring-boot-starter-aop Removed

If any module needs AOP (for tracing aspects), add explicit dependencies:
```xml
<dependency>
    <groupId>org.springframework</groupId>
    <artifactId>spring-aop</artifactId>
</dependency>
<dependency>
    <groupId>org.aspectj</groupId>
    <artifactId>aspectjweaver</artifactId>
</dependency>
```

### 8.3 Jackson 3.0

Spring Boot 4 ships Jackson 3.0. No custom serializers found in this project — should be transparent. If Spring AI 2.0.0-M4 still depends on Jackson 2 internally, Jackson 2 support ships in deprecated form.

### 8.4 Spring Cloud Gateway

Verify `spring-cloud-starter-gateway-mvc` resolves with the updated Spring Cloud BOM version. The gateway module (`applications/gateway/`) uses MVC variant.

### 8.5 Spring Shell

Verify `spring-shell-starter` works with Spring Shell 4.x for the CLI modules:
- `agentic-system/01-inner-monologue/inner-monologue-cli/`
- `agentic-system/02-model-directed-loop/model-directed-loop-cli/`

---

## Phase 9: Full Verification & Cleanup

### 9.1 Full Build

```bash
./mvnw clean verify
```

### 9.2 Runtime Smoke Tests

```bash
# 1. Start infrastructure
docker compose -f docker/postgres/docker-compose.yaml up -d
docker compose -f docker/observability-stack/docker-compose.yaml up -d
ollama serve  # in separate terminal

# 2. Test provider-ollama (most self-contained)
./mvnw spring-boot:run -pl applications/provider-ollama \
  -Dspring-boot.run.profiles=pgvector,observation

# Chat
curl "http://localhost:8080/chat/01/joke?topic=bikes"
curl "http://localhost:8080/chat/02/client/joke?topic=java"

# Embeddings
curl "http://localhost:8080/embed/01/text?text=hello+world"
curl "http://localhost:8080/embed/01/dimension"

# Vector Store + RAG
curl "http://localhost:8080/rag/01/load"
curl "http://localhost:8080/rag/01/query?topic=mountain+bike"

# Chat Memory
curl "http://localhost:8080/mem/02/hello?message=Hi+my+name+is+Alice"
curl "http://localhost:8080/mem/02/name"

# 3. Check observability
# Open http://localhost:3000 → Explore → Tempo → Search for traces
# Open http://localhost:3000 → Explore → Loki → Search for logs
# Open http://localhost:3000 → Dashboards → Workshop → JVM Micrometer

# 4. Test MCP (05-mcp-capabilities)
./mvnw spring-boot:run -pl mcp/05-mcp-capabilities

# 5. Test Gateway
./mvnw spring-boot:run -pl applications/gateway
```

### 9.3 Cleanup

- Remove `spring-boot-properties-migrator` if added as temporary aid
- Remove any Jackson 2 compatibility workarounds if not needed
- Update `README.md` with new version requirements
- Update `CLAUDE.md` to reflect post-migration state

---

## Risk Register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Spring AI 2.0.0-M4 is a milestone release | HIGH | API may change in M5/RC | Pin exact version, test thoroughly |
| Spring Cloud Azure may not have Boot 4 release | MEDIUM | Azure provider won't compile | Check release calendar, use snapshot or exclude temporarily |
| MCP `SpringAiMcpAnnotationProvider` API changed | MEDIUM | mcp-capabilities won't compile | Check 2.0 javadocs, may need significant refactor |
| Jackson 3.0 incompatibility with Spring AI | MEDIUM | Runtime serialization errors | Use deprecated Jackson 2 fallback |
| google-java-format may not support JDK 25 | LOW | Spotless fails at compile | Update or temporarily disable |
| Grafana dashboard datasource UIDs mismatch | LOW | Dashboards show "No data" | Query LGTM datasource UIDs and update JSONs |
