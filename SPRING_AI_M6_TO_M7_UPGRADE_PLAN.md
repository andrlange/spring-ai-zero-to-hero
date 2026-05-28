# Spring AI 2.0.0-M6 → 2.0.0-M7 Upgrade Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bump the workshop from Spring AI 2.0.0-M6 → 2.0.0-M7 across all 29 reactor modules without regressing any of the 6 provider apps, the 5 MCP demos, or the 2 agentic-system demos.

**Architecture:** Single property-bump (`<spring-ai.version>`) drives the BOM upgrade for all modules. The migration work is (a) auditing each call site for the listed M7 breaking-change surface, (b) reacting to MCP Java SDK 2.0.0-M2 → 2.0.0-M3 if it bites, (c) bumping the `ToolCallAdvisor`-as-default behavioral change in observability/Stage 8, and (d) the usual non-historical version-label sweep + `[2.3.6]` `CHANGELOG.md` entry.

**Tech Stack:** Spring Boot 4.0.6 · Spring AI 2.0.0-M7 · Java 25 · Maven 3.9.14 · MCP Java SDK 2.0.0-M3

**Reference release notes:** <https://github.com/spring-projects/spring-ai/releases/tag/v2.0.0-M7>

**Companion docs:** [`SPRING_AI_M5_TO_M6_MIGRATION.md`](SPRING_AI_M5_TO_M6_MIGRATION.md), [`SPRING_AI_M4_TO_M5_MIGRATION.md`](SPRING_AI_M4_TO_M5_MIGRATION.md), [`migration/upgrade.md`](migration/upgrade.md).

---

## Part 1 — Impact summary (TL;DR)

| Risk | M7 change | Affects us? | Effort |
|---|---|---|---|
| 🟥 **HIGH** | **`ToolCallAdvisor` becomes the default tool-call management** (#5459 + #6096 + #6111) | **Yes — behavioral.** All 4 tool-using surfaces (chat_05 demos, both agentic Agent classes, 2 MCP client modules, dashboard McpInspector) execute tools through the advisor chain instead of the internal model loop. Observability traces (Stage 8 / Grafana) change shape. | **Smoke-test heavy.** No code change *required* but must verify behavior and update Stage 8 dashboard/doc if trace shape changed. |
| 🟨 **LOW** | **MCP Java SDK 2.0.0-M2 → 2.0.0-M3 — breaking API changes** (#6121) | **No, after audit.** M3's four named breaking changes are (a) `ResourceReference` record reduced `(type, uri)` → `(uri)` — we already use single-arg at `ClientSse.java:94`; (b) `PromptReference.equals/hashCode` key on name only — we construct but never use as map/set key; (c) `CompleteReference.identifier()` deprecated — we don't import it; (d) `CreateMessageRequest.maxTokens` / `CreateMessageResult.model` mandatory — we don't construct either. The catch-all "builders now require mandatory args in factory method" is also satisfied — all our call sites (`McpClient.sync(transport)`, `HttpClientStreamableHttpTransport.builder(url)`) already pass the mandatory arg in the factory. | Compile-test only — Task 2 below is conditional on a compile failure that we **do not expect**. |
| 🟧 **MEDIUM** | **Deprecate SSE transports; Streamable HTTP becomes default server protocol** (#5969) | **No effect on code paths.** All 4 MCP servers (`02`, `04-server`, `05`) already pin `protocol: STREAMABLE` + `streamable-http.mcp-endpoint`; the `01` server is `stdio`; no server uses SSE. **One cleanup:** the deprecated SSE classes our test code does *not* import shouldn't surface, but the misleadingly-named `ClientSse.java` in `mcp/05-mcp-capabilities/src/test/...` (already uses `HttpClientStreamableHttpTransport` internally — naming-only) is worth flagging in docs. | Doc-only; verify warnings during `mvn verify`. |
| 🟥 **HIGH (discovered post-bump)** | **`spring-ai-autoconfigure-mcp-client-common` artifact missing from M7 publication** | **Yes — runtime crash.** The M7 `spring-ai-autoconfigure-mcp-client-httpclient` jar's autoconfigs reference classes in the unpublished `mcp-client-common` artifact; every provider app crashes at startup with `ClassNotFoundException: McpSseClientProperties` (BEFORE `@ConditionalOnProperty` is evaluated, so `enabled=false` does not help). Reactor `mvn clean verify` did not catch this — unit tests use sliced contexts that don't load MCP autoconfig. | **See Part 5b below.** Workaround applied: `spring.autoconfigure.exclude` in each of the 6 provider yamls. Upstream bug reported; remove the workaround when GA / M7.1 ships the missing artifact. |
| 🟧 **MEDIUM** | **Validation of vector dimensions for PgVector** (#4868) | **Likely no-op, must verify.** Per-provider dimensions in `application.yaml` (`openai`, `azure` → 1536 for `text-embedding-3-small`; `ollama` → 768 for `nomic-embed-text`) already match what each embedding model returns. New validation should pass; if it doesn't, that's a pre-existing bug we want to know about. | Smoke-test each pgvector provider's `embed/04/store` endpoint. |
| 🟨 **LOW** | **`ChatOptions` setters removed** (#6025) | **No-op.** Per `SPRING_AI_M5_TO_M6_MIGRATION.md` §1.3 the codebase was already migrated to `ChatOptions.Builder` everywhere in M5. Verified by `grep`: no `setMaxTokens`/`setTemperature`/`setTopP`/`setModel`/`setMaxToolCalls` calls outside Spring AI internals. | Verify with grep. |
| 🟨 **LOW** | **`ChatClient#prompt` ignores chat options from prompt** — fix (#6072) | **No-op (verify).** Bug fix: previously, options on a `Prompt` instance were silently dropped. We pass options via `.options(builder)` on the request spec, not via `new Prompt(text, options)`. Sweep confirms no `new Prompt(..., options)` call sites. | Verify with grep. |
| 🟨 **LOW** | **Enforce single `ToolAdvisor` invariant in `DefaultChatClient`** (#6111) | **No-op (verify).** We never explicitly add a `ToolCallAdvisor` — auto-config installs one. Risk only if any module added one manually; grep confirms not. | Verify with grep. |
| 🟨 **LOW** | **Gemini default `GEMINI_2_0_FLASH` → `GEMINI_2_5_FLASH`** (#6003) | **No-op.** All Google references already use `gemini-2.5-flash`. | None. |
| 🟨 **LOW** | **Updated Gemini Models + Google Client Library BOM** (#6112) | **Possible transitive conflict.** `provider-google` already overrides `protobuf` and `okhttp` versions in its pom (per `migration/model_mapping.md`). Bumped Google BOM may shift these — re-test the manual overrides after the bump. | Verify build. |
| 🟨 **LOW** | **Sanitize Spring Boot related dependencies** (#6088) | **Possible.** Could reorganize auto-config or starter transitive deps. Latent surface: the M5 bump exposed missing `spring-boot-restclient`; another reorg could expose another missing-bean error. | Reactor build + provider boot smoke tests catch this. |
| 🟨 **LOW** | **`ToolSpec` fluent API introduced** (#6085) | **Additive.** New API surface; we keep using `@Tool` / `MethodToolCallbackProvider` / `FunctionToolCallback.builder()`. Optional: document `ToolSpec` as a forward-looking pattern in Stage 7 docs. | None. |
| 🟨 **LOW** | **OpenAI streaming preserves `ChatResponseMetadata`** + **OpenAI streaming drops chunks** fixes (#5929, #6014, #5120) | **Beneficial.** Affects `chat_08/StreamingChatModelController` — if it had been silently dropping chunks or losing metadata under load, that improves with no code change. | Smoke-test the streaming endpoint, expect improvement. |
| 🟩 **N/A** | Removed `spring-ai-spring-cloud-bindings` (#6079) | Not used. | — |
| 🟩 **N/A** | Removed CosmosDB components (#6080) | Not used. | — |
| 🟩 **N/A** | Ollama GraalVM native image fix (#6043) | We don't compile native images. | — |
| 🟩 **N/A** | Redis vector store `doDelete` fix (#5998) | We don't use Redis vector store. | — |
| 🟩 **N/A** | Kotlin MCP tool nullable-field fix (#5997, #5978) | We're Java-only. | — |
| 🟩 **N/A** | Per-call `customHeaders` not propagated in `OpenAiImageOptions` (#6082) | We don't customize image headers. | — |
| 🟩 **N/A** | `OpenAiChatOptions.AbstractBuilder#combineWith` fix (#6045, #6042) | We don't override OpenAI options at request time; only `MultiModalController` uses `ChatOptions.builder().model("llava")`. | — |
| 🟩 **N/A** | OpenAI generic options merging for image/audio/embedding/moderation (#6042) | Same — we don't merge per-call. | — |
| 🟩 **N/A** | Docker Model Runner fix (#6036) | Not used. | — |
| 🟩 **N/A** | Reuse `JsonSchemaGenerator` in `BeanOutputConverter` (#5897) | Internal; we use `.entity(Class)`, `.entity(ParameterizedTypeReference)`, `.entity(MapOutputConverter)`, `.entity(ListOutputConverter)` in `chat_04/StructuredOutputConverterController` — public API unchanged. | — |
| 🟩 **N/A** | `$ref` resolution for recursive tool input schema (#5888) | None of our tools have recursive types. | — |
| 🟩 **N/A** | `WebFluxSseClientTransport` validator (#5967) | We don't use WebFlux SSE. | — |
| 🟩 **N/A** | Google GenAI start.spring.io fix (#6005) | Not relevant. | — |
| 🟩 **N/A** | Anthropic SDK 2.30.0+ / Anthropic Java 2.27.0+ / OpenAI SDK transitive bumps | Pulled in via BOM; no code changes. | — |

**Workshop side effects (mechanical, same pattern as previous bumps):**

- Workshop version `2.3.5` → `2.3.6` in `VERSION`, `workshop.properties`, `prepare.sh`, `layout.html` placeholder.
- Non-historical version-label sweep `2.0.0-M6` → `2.0.0-M7` (README, workshop.sh banners, docs/, all provider/component readmes, dashboard slides, Grafana dashboard).
- New `[2.3.6]` entry in `CHANGELOG.md`.
- Update the pixel-art Spring AI History page (`/spring-ai-history.html`) timeline to include the new `v2.0.0-M7` release with its headlines.

**Reactor build target:** `./mvnw clean verify` → **BUILD SUCCESS** across 29 modules with no new warnings beyond M7's deprecation notices.

---

## Part 2 — File-by-file impact map

These are the *only* source files that may need a code change. Everything else is either (a) version-label-only (mechanical sweep) or (b) untouched.

### High-confidence: NO code change needed (verify only)

| File | Why audited | Expected outcome |
|---|---|---|
| `pom.xml` (root) | The single dependency bump | Property change: `<spring-ai.version>2.0.0-M6</spring-ai.version>` → `2.0.0-M7`. |
| `components/apis/chat/src/main/java/com/example/chat_05/ToolController.java` | Tool-calling controller — `ToolCallAdvisor` becomes default | Compile-only verification; smoke-test all 5 chat_05 endpoints. |
| `components/apis/chat/src/main/java/com/example/chat_05/tool/return_direct/RestaurantSearch.java` | `@Tool returnDirect=true` — most exposed to advisor behavioral change | Smoke-test `/chat/05/tool/return-direct` (or whichever path). |
| `components/apis/chat/src/main/java/com/example/chat_05/tool/annotations/TimeTools.java` | `@Tool` annotation discovery | Compile + smoke-test. |
| `components/apis/chat/src/main/java/com/example/chat_05/tool/function/FunctionConfiguration.java` | `FunctionToolCallback.builder()` — public API stable in M7 release notes | Compile-only. |
| `components/apis/chat/src/main/java/com/example/chat_08/StreamingChatModelController.java` | Beneficiary of streaming-chunk + metadata fixes | Smoke-test the streaming SSE endpoint. |
| `components/apis/chat/src/main/java/com/example/chat_04/StructuredOutputConverterController.java` | `BeanOutputConverter` internal refactor (#5897) | Smoke-test all 4 entity-extraction endpoints. |
| `mcp/01-mcp-stdio-server/src/main/java/com/example/WeatherTools.java` | `@Tool` discovery on the MCP server side | `mvn verify` + manual stdio test. |
| `mcp/01-mcp-stdio-server/src/test/java/com/example/ClientStdio.java` | Uses `StdioClientTransport`, `JacksonMcpJsonMapper`, `McpClient.sync(...)` — most exposed to MCP SDK M3 API changes | Compile-only. If MCP SDK M3 renamed any of these → fix imports. |
| `mcp/02-mcp-http-server/src/main/java/com/example/BasicHttpMcpServerApplication.java` | `MethodToolCallbackProvider.builder().toolObjects(...).build()` | Compile-only. |
| `mcp/02-mcp-http-server/src/test/java/com/example/ClientHttp.java` | `HttpClientStreamableHttpTransport.builder("http://localhost:8080").build()` | Compile-only. |
| `mcp/03-mcp-client/src/main/java/com/example/McpClientDemoRunner.java` | `ChatClient.Builder` + `ToolCallbackProvider` injection + `.toolCallbacks(tools)` | Compile + smoke-test (uses **default profile** = local stdio servers from `mcp-servers-local.json`). |
| `mcp/04-dynamic-tool-calling/server/src/main/java/org/springframework/ai/mcp/sample/server/ServerApplication.java` | Imports `io.modelcontextprotocol.server.McpServerFeatures.SyncToolSpecification` and calls `McpToolUtils.toSyncToolSpecifications(ToolCallbacks.from(new MathTools()))` — **highest MCP SDK M3 risk** | Compile-test carefully; if the SDK renamed/moved `SyncToolSpecification`, fix here. |
| `mcp/04-dynamic-tool-calling/client/src/main/java/org/springframework/ai/mcp/samples/client/ClientApplication.java` | `.toolCallbacks(tools)` + `.entity(ParameterizedTypeReference<...>)` | Compile + smoke-test. |
| `mcp/05-mcp-capabilities/src/main/java/mcp/capabilities/McpServerApplication.java` | Same `MethodToolCallbackProvider.builder()` pattern | Compile-only. |
| `mcp/05-mcp-capabilities/src/main/java/mcp/capabilities/PromptProvider.java` | Uses `PromptMessage`, `Role`, `TextContent`, `PromptReference` from MCP SDK | Compile-only. If MCP SDK M3 moved any of these → fix imports. |
| `mcp/05-mcp-capabilities/src/main/java/mcp/capabilities/WeatherService.java` | `@Tool` + custom resource/prompt providers | Compile + smoke-test. |
| `mcp/05-mcp-capabilities/src/test/java/mcp/capabilities/ClientSse.java` | **Misleadingly named** — uses `HttpClientStreamableHttpTransport`, not SSE. Not changed by M7's SSE deprecation. | Compile-only. *(Optional follow-up: rename class to `ClientStreamableHttp` to match what it actually does — flag in §Recommended follow-ups, do NOT do in this bump.)* |
| `components/config-dashboard/src/main/java/com/example/dashboard/mcp/McpInspectorController.java` | `SyncMcpToolCallbackProvider.builder()` + `.toolCallbacks(provider)` chain | Compile + smoke-test from the dashboard "MCP Inspector" page. |
| `components/config-dashboard/src/main/java/com/example/dashboard/mcp/McpStdioInvoker.java` | Comment refers to `SyncMcpToolCallbackProvider` | Compile-only. |
| `agentic-system/01-inner-monologue/inner-monologue-agent/src/main/java/com/example/agentic/inner_monologue/Agent.java` | Chat memory + tool callbacks per-Agent — biggest behavioral surface area for `ToolCallAdvisor` default | Compile + smoke-test `inner-monologue` (port 8091). |
| `agentic-system/01-inner-monologue/inner-monologue-agent/src/main/java/com/example/agentic/inner_monologue/AgentTools.java` | `@Tool` `send_message` | Compile + smoke-test. |
| `agentic-system/02-model-directed-loop/model-directed-loop-agent/src/main/java/com/example/agentic/model_directed_loop/Agent.java` | Same as above + multi-step loop | Compile + smoke-test `model-directed-loop` (port 8092). |
| `agentic-system/02-model-directed-loop/model-directed-loop-agent/src/main/java/com/example/agentic/model_directed_loop/AgentTools.java` | `@Tool` `send_message` with `requestReinvocation` field | Compile + smoke-test. |
| `applications/provider-openai/src/main/resources/application.yaml` | `vectorstore.pgvector.dimension: 1536` — new dimension validation | Smoke-test. |
| `applications/provider-azure/src/main/resources/application.yaml` | `vectorstore.pgvector.dimension: 1536` | Smoke-test. |
| `applications/provider-ollama/src/main/resources/application.yaml` | `vectorstore.pgvector.dimension: 768` | Smoke-test. |
| `applications/provider-google/pom.xml` | Carries the `protobuf` + `okhttp` overrides; new Google Client Library BOM in M7 may shift these | Re-run `./mvnw dependency:tree -pl applications/provider-google` and compare to current. |

### Likely affected: NEEDS code change (low confidence, only if M3 SDK or behavioral defaults bite)

These are *contingent* — only edit if compile fails or smoke test regresses:

| File | Trigger | Fix |
|---|---|---|
| `mcp/04-dynamic-tool-calling/server/src/main/java/org/springframework/ai/mcp/sample/server/ServerApplication.java` | If `McpToolUtils.toSyncToolSpecifications(...)` or `SyncToolSpecification` was renamed/relocated in MCP SDK 2.0.0-M3 | Update imports and call site to match new SDK shape. Cross-reference: <https://github.com/modelcontextprotocol/java-sdk/releases/tag/v2.0.0-M3>. |
| `mcp/01-mcp-stdio-server/src/test/java/com/example/ClientStdio.java` | If `JacksonMcpJsonMapper` constructor signature changed | Adapt the test builder. |
| `docs/spring-ai/SPRING_AI_STAGE_8.md` (if present) or workshop observability page | If `ToolCallAdvisor` as default changes the trace tree shape in Grafana | Update the screenshot/explanation; do **not** silently leave a wrong diagram. |
| Grafana dashboard `docker/observability-stack/grafana/dashboards/spring-ai-workshop-overview.json` | If new span names / metric labels appear | Add the new panel labels; keep the old ones too so we don't lose history. |

---

## Part 3 — Provider-by-provider checklist

| Provider | Module changed? | Code changed? | Config keys changed? | New deps? | Smoke-tests | Notes |
|---|---|---|---|---|---|---|
| **OpenAI** | — | — | — | — | `chat/02`, `chat/05`, `chat/08`, `embed/01`, `embed/04`, `vec/03`, `rag/01`, `mem/02` | All chat-tool + structured-output paths run through `ToolCallAdvisor` default. |
| **Anthropic** | — | — | — | — | `chat/02`, `chat/05` (if tool calls enabled), `mem/02` | Anthropic SDK pulled via BOM. |
| **Azure (Foundry)** | — | — | — | — | Same as OpenAI (uses unified `spring-ai-starter-model-openai`) | Endpoint and deployment-name semantics unchanged from M5/M6 (`SPRING_AI_M4_TO_M5_MIGRATION.md` §4). |
| **AWS Bedrock** | — | — | — | — | `chat/02` only (no embedding/vector by design — see `SPRING_AI_M4_TO_M5_MIGRATION.md` §3.5) | |
| **Google GenAI** | — | — | — | — | `chat/02` + dependency-tree re-check | New Google BOM (#6112). Re-verify the `protobuf` + `okhttp` overrides still resolve. |
| **Ollama** | — | — | — | — | Full local-only run with `pgvector,observation,ui` | All Stage 1–8 endpoints. |

The behavioral M7 changes (`ToolCallAdvisor` default, dimension validation, MCP SDK M3) cut **across** providers — they live in components shared by all 6 provider apps — so any provider's smoke test exercises them.

---

## Part 4 — Implementation tasks

> Convention: every code change ends with `./mvnw spotless:apply` before commit (the M6 bump caught us on lambda-line formatting; same trap remains). Run from repo root.

> Branching: do this on a `chore/spring-ai-m7-bump` branch off `main`, same pattern as `chore/spring-ai-m6-bump` (PR #5).

### Task 1: Branch + version bump

**Files:**
- Modify: `pom.xml:20`

- [ ] **Step 1: Create branch**

```bash
git checkout main && git pull --ff-only
git checkout -b chore/spring-ai-m7-bump
```

- [ ] **Step 2: Bump the BOM version property**

Change `pom.xml:20`:

```diff
-    <spring-ai.version>2.0.0-M6</spring-ai.version>
+    <spring-ai.version>2.0.0-M7</spring-ai.version>
```

- [ ] **Step 3: Verify the bump compiles the whole reactor**

```bash
./mvnw -q -DskipTests clean compile
```

Expected: **BUILD SUCCESS**. If a module fails to compile, **stop here** — it's one of the contingent files in Part 2; jump to Task 2 to triage.

- [ ] **Step 4: Commit the bump in isolation**

```bash
git add pom.xml
git commit -m "chore(spring-ai): bump 2.0.0-M6 → 2.0.0-M7 (BOM only)"
```

A standalone first commit keeps the diff readable in PR review and bisectable if a later task regresses.

---

### Task 2: Triage MCP SDK 2.0.0-M3 compile failures (contingent)

> **Skip this entire task if Task 1 Step 3 passed.** Otherwise: compile failure is almost certainly in `mcp/04-dynamic-tool-calling/server` or `mcp/01-mcp-stdio-server`'s test classpath.

**Files (potentially):**
- Modify: `mcp/04-dynamic-tool-calling/server/src/main/java/org/springframework/ai/mcp/sample/server/ServerApplication.java`
- Modify: `mcp/01-mcp-stdio-server/src/test/java/com/example/ClientStdio.java`
- Modify: `mcp/05-mcp-capabilities/src/main/java/mcp/capabilities/PromptProvider.java` (only if `PromptMessage` / `Role` / `TextContent` moved)

- [ ] **Step 1: Cross-reference MCP SDK 2.0.0-M3 changelog**

```bash
gh release view v2.0.0-M3 --repo modelcontextprotocol/java-sdk 2>/dev/null \
  || open https://github.com/modelcontextprotocol/java-sdk/releases/tag/v2.0.0-M3
```

Read the breaking-changes section. Spring AI release notes #6121 says "Update tests and docs for MCP SDK 2.0.0-M3 breaking API changes" — find the matching PR in spring-ai to see exactly what shape they migrated to:

```bash
gh pr view 6121 --repo spring-projects/spring-ai
```

- [ ] **Step 2: Adapt imports / call sites in the failing files**

Apply the same shape change that Spring AI applied in #6121. **Do not invent new patterns** — mirror what upstream did so future bumps stay easy.

- [ ] **Step 3: Re-run the compile**

```bash
./mvnw -q -DskipTests clean compile
```

Expected: **BUILD SUCCESS**.

- [ ] **Step 4: Run the MCP module unit tests**

```bash
./mvnw -pl mcp/01-mcp-stdio-server,mcp/02-mcp-http-server,mcp/03-mcp-client,mcp/04-dynamic-tool-calling/server,mcp/04-dynamic-tool-calling/client,mcp/05-mcp-capabilities test
```

Expected: all green.

- [ ] **Step 5: `spotless:apply` + commit**

```bash
./mvnw -q spotless:apply
git add mcp/
git commit -m "fix(mcp): adapt to MCP Java SDK 2.0.0-M3 API changes"
```

---

### Task 3: Full reactor verify

**Files:** none — this is the no-edit-touch-anything checkpoint.

- [ ] **Step 1: Full reactor build + test**

```bash
./mvnw clean verify
```

Expected: **BUILD SUCCESS**, 29 modules, all tests pass.

If `agentic-system/*/AgentTest.java` fails on `defaultAdvisors(Consumer)` mocking — that's leftover from the M5/M6 stubbing. The fix from `SPRING_AI_M5_TO_M6_MIGRATION.md` §1.3 should still hold; if Mockito complains about extra unstubbed methods, *add* a stub for the new method, **don't remove** the existing ones (they may still be called from base ChatClient internals).

- [ ] **Step 2: Capture and triage any new deprecation warnings**

```bash
./mvnw clean verify 2>&1 | grep -iE "deprecat|warning" | sort -u > /tmp/m7-warnings.txt
```

Read `/tmp/m7-warnings.txt`. Expected warnings:
- SSE transport deprecation notices in MCP starters (#5969) — **harmless**, we don't use SSE.
- Possible new javadoc / Lombok deprecations on transitively-bumped libs.

Anything mentioning `ChatOptions.set*` or `MessageChatMemoryAdvisor.Builder.conversationId` would be a regression — verify it doesn't appear (we should be clean from M5 + M6 cleanup).

---

### Task 4: Vector-dimension validation smoke test (per provider)

**Files:** none — runtime test only.

> Goal: confirm M7's new pgvector dimension validation (#4868) accepts the existing configured dimensions for each provider that has `vectorstore.pgvector.dimension` set (`openai: 1536`, `azure: 1536`, `ollama: 768`).

- [ ] **Step 1: Start Postgres**

```bash
./workshop.sh infra postgres
```

- [ ] **Step 2: For each pgvector-using provider, boot under the `pgvector` profile and hit a vector endpoint**

```bash
# OpenAI
./mvnw -q -pl applications/provider-openai spring-boot:run \
  -Dspring-boot.run.profiles=pgvector &
sleep 25
curl -sf 'http://localhost:8080/vec/03/load' \
  && curl -sf 'http://localhost:8080/vec/03/search?query=test' | head -50
kill %1 2>/dev/null; wait 2>/dev/null
```

Expected: HTTP 200, embeddings load + search returns results. **Failure mode to watch for:** a startup error of the form `dimension mismatch: configured X but model produces Y` would be the new M7 validation catching a real bug — investigate the provider's `embedding.options.model` vs `vectorstore.pgvector.dimension`.

- [ ] **Step 3: Repeat for `provider-azure` and `provider-ollama`**

Azure needs `creds.yaml` configured (see `SPRING_AI_M4_TO_M5_MIGRATION.md` §4.6 if not set up). Ollama needs the host Ollama running with `nomic-embed-text` pulled.

- [ ] **Step 4: Commit (no code changes — this is a verification gate)**

No commit unless a fix was needed. If a provider's dimension config was wrong: fix the `application.yaml` value to match the embedding model's real dimension and commit `fix(provider-X): correct pgvector dimension to match <model>`.

---

### Task 5: `ToolCallAdvisor`-as-default behavioral smoke test

**Files:** none — runtime test only.

> Goal: confirm that with `ToolCallAdvisor` now the **default tool-call management option** (#5459), the four tool-using surfaces still produce the same user-visible result. The internal trace tree changes; the result should not.

- [ ] **Step 1: Spin up provider-openai with `observation,ui` for tracing**

```bash
./workshop.sh infra all   # postgres + LGTM
./mvnw -q -pl applications/provider-openai spring-boot:run \
  -Dspring-boot.run.profiles=observation,ui &
sleep 25
```

- [ ] **Step 2: Exercise the 4 tool-using surfaces**

```bash
# chat_05 — @Tool annotation
curl -sf 'http://localhost:8080/chat/05/tool/time?timeZone=Europe/Berlin'

# chat_05 — returnDirect=true (RestaurantSearch)
curl -sf -X POST 'http://localhost:8080/chat/05/tool/restaurants' \
  -H 'Content-Type: application/json' \
  -d '{"prompt":"book Italian restaurant in Berlin tomorrow at 19:00 for 4 people, 4 stars"}'

# chat_05 — FunctionToolCallback
curl -sf 'http://localhost:8080/chat/05/tool/weather?city=Berlin'

# MCP client (Stage 6) — see endpoints via /dashboard/stage/6
curl -sf 'http://localhost:8080/dashboard/stage/6'   # confirm page renders
```

Expected: each returns its normal happy-path response shape (the same shape it returned on M6).

- [ ] **Step 3: Pull a trace from Tempo and verify span shape**

Open <http://localhost:3000/explore> → Tempo → search by service `openai`. Pick the most recent `/chat/05/tool/...` trace and capture the span tree. Compare against the M6 baseline (`docs/spring-ai/SPRING_AI_STAGE_8.md` reference screenshots).

**Expected delta in M7:** new spans for `tool.call.advisor` wrapping each tool invocation. **Not a regression** — this is the explicit M7 change.

- [ ] **Step 4: Update Stage 8 docs if span names changed**

If `docs/spring-ai/SPRING_AI_STAGE_8.md` (or its dashboard fragment) has screenshots / span-name examples that no longer match, update them. **Do not silently leave the old diagram in place.**

- [ ] **Step 5: Update the Grafana dashboard panel queries if needed**

Edit `docker/observability-stack/grafana/dashboards/spring-ai-workshop-overview.json` only if a panel filters on the old internal span names. Keep panels backwards-compatible (OR with the old name) so attendees on M6 can still use the dashboard.

- [ ] **Step 6: Commit observability updates if changed**

```bash
git add docs/ docker/observability-stack/
./mvnw -q spotless:apply
git commit -m "docs(stage-8): update trace tree for ToolCallAdvisor-as-default in M7"
```

---

### Task 6: Agentic-system end-to-end smoke test

**Files:** none — runtime test only.

> Goal: the agentic agents (Stage 7) wire `@Tool` + chat memory + ChatOptions all together; if any M7 change is going to bite us, this is where it shows up at runtime.

- [ ] **Step 1: Start inner-monologue agent**

```bash
./mvnw -q -pl agentic-system/01-inner-monologue/inner-monologue-agent spring-boot:run \
  -Dspring-boot.run.profiles=openai &
sleep 20

curl -sf -X POST 'http://localhost:8091/agents/inner-monologue/chat' \
  -H 'Content-Type: application/json' \
  -d '{"text":"Say hi and tell me your inner thoughts."}'

kill %1 2>/dev/null; wait 2>/dev/null
```

Expected: JSON response with `message`, `innerThoughts`, `isFallback: false`. The structured-output parsing must still produce a non-fallback response.

- [ ] **Step 2: Start model-directed-loop agent**

```bash
./mvnw -q -pl agentic-system/02-model-directed-loop/model-directed-loop-agent spring-boot:run \
  -Dspring-boot.run.profiles=openai &
sleep 20

curl -sf -X POST 'http://localhost:8092/agents/model-directed-loop/chat' \
  -H 'Content-Type: application/json' \
  -d '{"text":"Solve: what is 7*8 then 13+27 then summarize."}'

kill %1 2>/dev/null; wait 2>/dev/null
```

Expected: multi-step trace, `trace.steps` has size > 1, ends with `requestReinvocation: false`. **Watch for:** infinite reinvocation loop (would mean `ToolCallAdvisor`-default broke the inner agent's reinvocation signaling).

- [ ] **Step 3: Repeat both with `ollama` profile** (uses `OllamaChatOptions` path)

```bash
./mvnw -q -pl agentic-system/01-inner-monologue/inner-monologue-agent spring-boot:run \
  -Dspring-boot.run.profiles=ollama &
# ... same curl, same expectations
```

- [ ] **Step 4: No code commit unless a regression was found**

If a regression appears in step 1 or 2, the most likely culprit is the M7 `ToolCallAdvisor` default interacting with our agentic loop. Fix root cause — do **not** disable the new default. (If genuinely needed, the escape hatch is to explicitly configure `ChatModel.builder().toolCallingManager(...)` — but file an issue first.)

---

### Task 7: MCP demo end-to-end smoke test (Stage 6)

**Files:** none — runtime test only.

> Goal: confirm all 5 MCP demos still work post-SDK-M3 + new defaults.

- [ ] **Step 1: Stage 6 demo runner — runs each MCP submodule's own happy-path test**

```bash
./mvnw -q -pl mcp/01-mcp-stdio-server,mcp/02-mcp-http-server,mcp/03-mcp-client,\
mcp/04-dynamic-tool-calling/server,mcp/04-dynamic-tool-calling/client,mcp/05-mcp-capabilities \
  test
```

Expected: all green.

- [ ] **Step 2: From dashboard, run each demo**

```bash
./mvnw -q -pl applications/provider-openai spring-boot:run \
  -Dspring-boot.run.profiles=ui &
sleep 25
open http://localhost:8080/dashboard/stage/6   # macOS; xdg-open on Linux
```

Click through each of the 5 MCP demo cards. Each should show a successful run (tool call → result rendered).

- [ ] **Step 3: Test the McpInspector UI**

Open the "MCP Inspector" page from the dashboard sidebar. Connect to a local stdio or HTTP server, list tools, invoke one. Verify no errors in the browser console or `application.log`.

---

### Task 8: Provider-google dependency-tree re-check

**Files:**
- Audit only: `applications/provider-google/pom.xml`

> Goal: M7's Google Client Library BOM bump (#6112) may shift transitive `protobuf` / `okhttp` versions that this pom currently overrides. We don't want to silently keep an override that's now redundant *or* a missing override that breaks `gemini-2.5-flash` calls.

- [ ] **Step 1: Capture the current resolved tree**

```bash
./mvnw -pl applications/provider-google dependency:tree \
  -Dincludes=com.google.protobuf:protobuf-java,com.squareup.okhttp3:okhttp \
  > /tmp/m7-google-deps.txt
cat /tmp/m7-google-deps.txt
```

Expected: shows the manually-overridden versions in the resolved tree.

- [ ] **Step 2: Start the provider and hit a chat endpoint**

```bash
# Credentials in applications/provider-google/src/main/resources/creds.yaml must be valid
./mvnw -q -pl applications/provider-google spring-boot:run &
sleep 25
curl -sf 'http://localhost:8080/chat/02/client/joke?topic=cats'
kill %1 2>/dev/null; wait 2>/dev/null
```

Expected: a joke. **Failure mode to watch for:** `NoSuchMethodError` on protobuf or okhttp = transitive conflict, the override needs adjusting.

- [ ] **Step 3: If a conflict shows up**

Adjust the override version in `applications/provider-google/pom.xml`. Document the new version + why in an inline comment.

```bash
./mvnw -q spotless:apply
git add applications/provider-google/pom.xml
git commit -m "fix(provider-google): adjust protobuf/okhttp override for M7 Google BOM"
```

---

### Task 9: Bump workshop version 2.3.5 → 2.3.6

**Files:**
- Modify: `VERSION`
- Modify: `components/config-dashboard/src/main/resources/workshop.properties`
- Modify: `prepare.sh:71` and `prepare.sh:115`
- Modify: `components/config-dashboard/src/main/resources/templates/fragments/layout.html` (version placeholder)

- [ ] **Step 1: Bump `VERSION`**

```diff
-2.3.5
+2.3.6
```

- [ ] **Step 2: Bump `workshop.properties`**

```diff
-workshop.version=2.3.5
+workshop.version=2.3.6
```

- [ ] **Step 3: Bump `prepare.sh` defaults**

```diff
-SAI_VERSION="$(ask "Spring AI version"   "2.0.0-M6")"
+SAI_VERSION="$(ask "Spring AI version"   "2.0.0-M7")"
```

And:

```diff
-content = replace_once(content, "Spring AI 2.0.0-M6", f"Spring AI {sai}",   "Spring AI version")
+content = replace_once(content, "Spring AI 2.0.0-M7", f"Spring AI {sai}",   "Spring AI version")
```

- [ ] **Step 4: Update `layout.html` workshop-version placeholder**

Read the file to find the version-display line; update from `2.3.5` to `2.3.6`. *Do not* search-and-replace blindly — there may be other `2.3.5` strings (history file mentions of M6 ship, etc.) that should stay.

- [ ] **Step 5: Commit the workshop-version bump**

```bash
./mvnw -q spotless:apply
git add VERSION components/config-dashboard/src/main/resources/workshop.properties \
        prepare.sh components/config-dashboard/src/main/resources/templates/fragments/layout.html
git commit -m "chore(workshop): bump 2.3.5 → 2.3.6 for Spring AI M7"
```

---

### Task 10: Non-historical version-label sweep `M6 → M7`

**Files (audited list — confirmed by `grep -rn '2\.0\.0-M6'` excluding `target/`, `.git/`, `migration/`, prior `SPRING_AI_M*_TO_M*_MIGRATION.md` files):**

- Modify: `README.md:7` — "Spring Boot 4.0.6 | Spring AI 2.0.0-M6 | Java 25"
- Modify: `agentic-system/readme.md:3`
- Modify: `workshop.sh:5`, `workshop.sh:901`, `workshop.sh:1594`, `workshop.sh:1911` (4 banner occurrences)
- Modify: `WHATS_NEW_STAGE_06_MCP.md:218`
- Modify: `docs/README.md`, `docs/guide.md`, `docs/providers.md`, `docs/spring-ai/*.md` (all stages + intro), `support/{howto_windows11,os-compatibility-analysis,prerequisites}.md`
- Modify: all `applications/provider-*/readme.md`
- Modify: `applications/provider-azure/src/main/resources/creds-template.yaml:3` (comment refers to "Spring AI 2.0.0-M6")
- Modify: `components/config-dashboard/src/main/resources/templates/fragments/layout.html`
- Modify: `components/config-dashboard/src/main/resources/static/slides.html` + `slides.html.original` (the `prepare.sh` baseline)
- Modify: `docker/observability-stack/grafana/dashboards/spring-ai-workshop-overview.json`

**Deliberately NOT touched:**
- `migration/*.md` — historical
- `SPRING_AI_M4_TO_M5_MIGRATION.md`, `SPRING_AI_M5_TO_M6_MIGRATION.md` — historical
- This file (`SPRING_AI_M6_TO_M7_UPGRADE_PLAN.md`) — its references to M6 are intentional (the "from" version)
- `CHANGELOG.md` entries for `[2.3.5]` and earlier — historical
- Any docs sentence referring to "renamed in Spring AI 2.0.0-MX" where X is a prior milestone — those are historical facts, not version labels

- [ ] **Step 1: Run a controlled sweep**

```bash
grep -rl "2\.0\.0-M6" \
  --include="*.md" --include="*.xml" --include="*.html" \
  --include="*.yaml" --include="*.yml" --include="*.sh" \
  --include="*.json" --include="*.properties" --include="*.java" \
  --include="VERSION" . \
  | grep -v "/target/" | grep -v "/migration/" \
  | grep -v "SPRING_AI_M4_TO_M5_MIGRATION.md" \
  | grep -v "SPRING_AI_M5_TO_M6_MIGRATION.md" \
  | grep -v "SPRING_AI_M6_TO_M7_UPGRADE_PLAN.md" \
  | grep -v "CHANGELOG.md" \
  | grep -v "/.git/"
```

This is the working list. For each file: open, find the `2.0.0-M6`, change to `2.0.0-M7`. **Do not** `sed -i` over them blindly — some files have multiple M6 mentions and may include historical sentences ("introduced in M6") that should stay.

- [ ] **Step 2: After each edit, verify the file is still well-formed**

Especially the JSON dashboard (`grafana/dashboards/spring-ai-workshop-overview.json` — must remain valid JSON) and the YAML files.

```bash
# Quick syntax sanity:
jq empty docker/observability-stack/grafana/dashboards/spring-ai-workshop-overview.json
```

- [ ] **Step 3: Re-grep to confirm clean**

```bash
grep -rl "2\.0\.0-M6" \
  --include="*.md" --include="*.xml" --include="*.html" \
  --include="*.yaml" --include="*.yml" --include="*.sh" \
  --include="*.json" --include="*.properties" --include="*.java" \
  --include="VERSION" . \
  | grep -v "/target/" | grep -v "/migration/" \
  | grep -v "SPRING_AI_M4_TO_M5_MIGRATION.md" \
  | grep -v "SPRING_AI_M5_TO_M6_MIGRATION.md" \
  | grep -v "SPRING_AI_M6_TO_M7_UPGRADE_PLAN.md" \
  | grep -v "CHANGELOG.md" \
  | grep -v "/.git/"
```

Expected: **empty output**. (The CHANGELOG `[2.3.5]` entry legitimately mentions M5→M6 as history; that stays.)

- [ ] **Step 4: Commit the sweep**

```bash
./mvnw -q spotless:apply
git add -A
git commit -m "docs: sweep version labels 2.0.0-M6 → 2.0.0-M7"
```

---

### Task 11: Update Spring AI History pixel-art timeline

**Files:**
- Modify: `components/config-dashboard/src/main/resources/static/spring-ai-history.html` (or its data file — confirmed via `git log` / `grep` to locate the release-list array)

> Goal: the pixel-art `/spring-ai-history.html` page (introduced in [2.3.5]) walks through every Spring AI release tag chronologically. M7 is a new tag and must be appended in order.

- [ ] **Step 1: Locate the release data**

```bash
grep -rn "v2.0.0-M6" components/config-dashboard/src/main/resources/ | head
```

Open the file containing the release-list array.

- [ ] **Step 2: Add the M7 entry**

Insert (in chronological order, after `v2.0.0-M6`) a new release entry. Headline keys to capture from the release notes:

- "`ToolCallAdvisor` becomes the default tool-call management option (#5459)"
- "MCP Java SDK 2.0.0-M3 — breaking API changes absorbed (#6121)"
- "SSE transports deprecated; Streamable HTTP is the default server protocol (#5969)"
- "`ToolSpec` fluent API introduced (#6085)"
- "PgVector dimension validation added (#4868)"
- "CosmosDB + `spring-ai-spring-cloud-bindings` removed (#6079, #6080)"
- Release date: 2026-05-22

Mirror the visual style of the existing M6 entry exactly.

- [ ] **Step 3: Verify in browser**

```bash
./mvnw -q -pl applications/provider-openai spring-boot:run \
  -Dspring-boot.run.profiles=ui &
sleep 25
open http://localhost:8080/spring-ai-history.html
kill %1 2>/dev/null; wait 2>/dev/null
```

Confirm the M7 sign-post appears in the walk and reveals the new headlines.

- [ ] **Step 4: Commit**

```bash
git add components/config-dashboard/src/main/resources/static/
git commit -m "feat(history): add v2.0.0-M7 release to pixel-art timeline"
```

---

### Task 12: Add `[2.3.6]` `CHANGELOG.md` entry

**Files:**
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Prepend a new top entry**

Use the same shape as `[2.3.5]` and `[2.3.4]` — `Changed` and `Migrated (M7 breaking changes)` sections. Concretely:

```markdown
## [2.3.6] - 2026-05-28

### Changed
- Bumped Spring AI from `2.0.0-M6` → `2.0.0-M7` across the parent POM, workshop docs, dashboard, slides, Grafana dashboard, `workshop.sh` banners, and all provider/component readmes.

### Migrated (M7 changes audited)
- **`ToolCallAdvisor` is now the default tool-call management option (#5459).** Behavioral change: tool calls execute through the advisor chain rather than the internal model loop. No code changes needed — all tool-using surfaces (chat_05, both agentic agents, MCP client modules, dashboard MCP Inspector) continue to work. Observability spans gain a `tool.call.advisor` wrapper; Stage 8 docs and the Grafana dashboard updated to reflect the new span tree.
- **MCP Java SDK 2.0.0-M2 → 2.0.0-M3 (#6121).** [If §Task 2 changed code, list the affected files here. Otherwise: "All 5 `mcp/` submodules compile and pass tests on M3 without code changes."]
- **SSE transports deprecated, Streamable HTTP is the default (#5969).** No-op for this workshop — all MCP servers (`02`, `04`, `05`) already pin `protocol: STREAMABLE` and the `01` server uses `stdio`. The misleadingly-named `ClientSse.java` test in `mcp/05-mcp-capabilities` already uses `HttpClientStreamableHttpTransport`; class rename is left as a follow-up.
- **PgVector dimension validation added (#4868).** Configured dimensions (`openai: 1536`, `azure: 1536`, `ollama: 768`) already match each provider's embedding model output. Smoke-tested per provider.
- **`ChatOptions` setters removed (#6025).** No-op — the codebase migrated to `ChatOptions.Builder` in [2.3.4].
- **Gemini default `GEMINI_2_0_FLASH` → `GEMINI_2_5_FLASH` (#6003).** No-op — already on `gemini-2.5-flash`.
- **Other release-notes items not relevant here:** Removed `spring-ai-spring-cloud-bindings` (#6079) and CosmosDB components (#6080) — not used. Ollama GraalVM native-image fix (#6043) — we don't compile native images. OpenAI streaming chunk-loss and metadata-preservation fixes (#5120, #5929, #6014) — beneficial, no code change needed. Kotlin MCP nullable-fields fix (#5997) — Java-only. `OpenAi*Options` setters and `OpenAiChatOptions.AbstractBuilder#combineWith` fix (#6045, #6042) — we always use builders. New `ToolSpec` fluent API (#6085) — additive; we keep using `@Tool` + `MethodToolCallbackProvider`.
```

> **Important:** if Task 2 (MCP SDK M3 triage) made code changes, list them here. The dash "[If §Task 2..." above is a *placeholder for the author* — replace with the actual prose.

- [ ] **Step 2: Commit**

```bash
git add CHANGELOG.md
git commit -m "docs(changelog): [2.3.6] — Spring AI M6 → M7"
```

---

### Task 13: Final reactor verify + tag-clean grep

**Files:** none.

- [ ] **Step 1: Full clean build**

```bash
./mvnw clean verify
```

Expected: **BUILD SUCCESS**, 29 modules, all tests pass, no new red warnings.

- [ ] **Step 2: Confirm no stale `2.0.0-M6` references outside history**

```bash
grep -rl "2\.0\.0-M6" \
  --include="*.md" --include="*.xml" --include="*.html" \
  --include="*.yaml" --include="*.yml" --include="*.sh" \
  --include="*.json" --include="*.properties" --include="*.java" \
  --include="VERSION" . \
  | grep -v "/target/" | grep -v "/migration/" \
  | grep -v "SPRING_AI_M4_TO_M5_MIGRATION.md" \
  | grep -v "SPRING_AI_M5_TO_M6_MIGRATION.md" \
  | grep -v "SPRING_AI_M6_TO_M7_UPGRADE_PLAN.md" \
  | grep -v "CHANGELOG.md" \
  | grep -v "/.git/"
```

Expected: **empty**.

- [ ] **Step 3: Confirm no removed APIs are referenced**

```bash
# spring-cloud-bindings — removed in M7
grep -rn "spring-ai-spring-cloud-bindings\|spring-cloud-bindings" \
  --include="*.xml" --include="*.java" . | grep -v "/target/" | grep -v "/.git/"
# Expect: empty

# CosmosDB — removed in M7
grep -rn "CosmosDB\|cosmos-db\|spring-ai-cosmosdb" \
  --include="*.xml" --include="*.java" --include="*.yaml" . | grep -v "/target/"
# Expect: empty

# PromptChatMemoryAdvisor — removed in M6, must still be clean
grep -rn "PromptChatMemoryAdvisor" --include="*.java" --include="*.md" . \
  | grep -v "/target/" | grep -v "/migration/" \
  | grep -v "SPRING_AI_M5_TO_M6_MIGRATION.md" \
  | grep -v "SPRING_AI_M6_TO_M7_UPGRADE_PLAN.md" \
  | grep -v "CHANGELOG.md"
# Expect: empty
```

- [ ] **Step 4: Push branch + open PR**

```bash
git push -u origin chore/spring-ai-m7-bump
gh pr create --title "chore(spring-ai): bump 2.0.0-M6 → 2.0.0-M7" --body "$(cat <<'EOF'
## Summary
- Bumps `spring-ai.version` 2.0.0-M6 → 2.0.0-M7 across the reactor (29 modules).
- Absorbs MCP Java SDK 2.0.0-M2 → 2.0.0-M3 API changes (if any — see commits).
- Verifies `ToolCallAdvisor`-as-default behavioral change (Stage 8 trace tree updated).
- Bumps workshop version 2.3.5 → 2.3.6.

See `SPRING_AI_M6_TO_M7_UPGRADE_PLAN.md` for the full impact analysis and execution plan, and `CHANGELOG.md` [2.3.6] for the per-change rationale.

## Test plan
- [ ] `./mvnw clean verify` green (29 modules)
- [ ] Provider smoke tests (OpenAI / Anthropic / Azure / AWS / Google / Ollama) — chat + embedding + vector + memory
- [ ] Stage 6 MCP demos (5 modules) — all green
- [ ] Stage 7 agentic agents (inner-monologue + model-directed-loop) — happy path + fallback
- [ ] Stage 8 observability — Grafana span tree verified, dashboard panels still resolve
- [ ] `/spring-ai-history.html` shows the new M7 sign-post

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

---

## Part 5 — Verification appendix

### A. Quick grep matrix (run after every commit)

```bash
# Versions
grep -rn "2\.0\.0-M[1-6]" --include="*.xml" --include="VERSION" . | grep -v "/target/" | grep -v "/migration/" | grep -v "SPRING_AI_M.*_TO_M.*"
# Expect: empty

# Removed APIs from prior milestones
grep -rn "PromptChatMemoryAdvisor\|MessageChatMemoryAdvisor.Builder.conversationId\|OpenAiAudioApi\|spring-ai-azure-openai" --include="*.java" --include="*.xml" --include="*.yaml" . | grep -v "/target/" | grep -v "/migration/" | grep -v "SPRING_AI_M.*_TO_M.*"
# Expect: empty
```

### B. Per-provider smoke matrix (run before merge)

| Provider | Profile combo | Endpoint | Expected |
|---|---|---|---|
| OpenAI | `pgvector,observation,ui` | `GET /chat/02/client/joke` | 200, joke |
| OpenAI | `pgvector,observation,ui` | `GET /chat/05/tool/time?timeZone=UTC` | 200, current UTC time |
| OpenAI | `pgvector,observation,ui` | `GET /chat/08/stream?topic=spring` | 200, SSE stream completes |
| OpenAI | `pgvector,observation,ui` | `POST /embed/04/store` then `GET /rag/01/query` | 200 then 200 |
| OpenAI | `pgvector,observation,ui` | `GET /mem/02/hello` then `GET /mem/02/name` | greeting, then "name is X" recall |
| Anthropic | `observation,ui` | `GET /chat/02/client/joke` | 200, joke |
| Azure | `pgvector,observation,ui` | All above (no `chat/02/audio`) | Same |
| AWS | `observation,ui` | `GET /chat/02/client/joke` | 200, joke |
| Google | `observation,ui` | `GET /chat/02/client/joke` | 200, joke |
| Ollama | `pgvector,observation,ui` | All above | Same |
| Stage 6 | dashboard `/dashboard/stage/6` | Click each MCP demo card | All 5 render success |
| Stage 7 | `inner-monologue` @ 8091, `model-directed-loop` @ 8092 | `POST /agents/.../chat` | Structured response, no fallback |
| Stage 8 | Tempo trace search | Service `openai`, recent tool call | Span tree shows `tool.call.advisor` |

### C. Failure-mode quick reference

| Symptom | Most likely cause | First place to look |
|---|---|---|
| `ClassNotFoundException io.modelcontextprotocol.server.McpServerFeatures.SyncToolSpecification` | MCP SDK M3 renamed/moved class | `mcp/04-dynamic-tool-calling/server/ServerApplication.java` |
| `Dimension mismatch: configured 1536, model returned N` at PgVector init | New M7 validation caught a real misconfiguration | Provider `application.yaml` `vectorstore.pgvector.dimension` vs `embedding.options.model` |
| `NullPointerException ChatClient$Builder.defaultAdvisors(Consumer)` in `AgentTest` | Mockito stub regression from M5/M6 era | `agentic-system/*/AgentTest.java` — re-apply the §1.3 fix from `SPRING_AI_M5_TO_M6_MIGRATION.md` |
| `NoSuchMethodError com.google.protobuf...` in `provider-google` | New Google BOM shifted protobuf transitive | `applications/provider-google/pom.xml` overrides |
| Stage 8 Grafana panels empty | Span names changed under new `ToolCallAdvisor` default | `docker/observability-stack/grafana/dashboards/spring-ai-workshop-overview.json` panel queries |
| Infinite loop in `model-directed-loop` agent | M7 default broke the agent's reinvocation signal | `agentic-system/02-model-directed-loop/.../Agent.java`; do **not** disable the new default — file an issue |

---

## Part 5b — POST-MERGE FIX: Spring AI M7 mcp-client packaging bug

> **READ THIS FIRST when bumping to 2.0.0-GA (or any later milestone).** The workaround below was added AFTER the initial M6 → M7 bump merged, in commit `968807b` on the same branch. It needs to be **removed once upstream ships the fix** — keeping a stale `spring.autoconfigure.exclude` in 6 yaml files is exactly the kind of crud that accumulates if you forget.

### The bug

Spring AI 2.0.0-M7 ships a broken `spring-ai-autoconfigure-mcp-client-httpclient` jar. Both of its `@AutoConfiguration` classes —

- `org.springframework.ai.mcp.client.httpclient.autoconfigure.SseHttpClientTransportAutoConfiguration`
- `org.springframework.ai.mcp.client.httpclient.autoconfigure.StreamableHttpHttpClientTransportAutoConfiguration`

— are annotated with `@EnableConfigurationProperties({ McpSseClientProperties.class, McpClientCommonProperties.class })` etc., referencing classes in the package `org.springframework.ai.mcp.client.common.autoconfigure.properties.*`. Those classes lived in `spring-ai-autoconfigure-mcp-client-common` for M3–M6, but **that artifact was not published for M7** (Spring milestone repo returns 404 for the M7 GAV). The two autoconfigs are listed in `AutoConfiguration.imports` and load unconditionally; the registrar throws `ClassNotFoundException` **before** `@ConditionalOnProperty(name="spring.ai.mcp.client.enabled")` is evaluated, so the conventional `enabled=false` escape hatch does not work.

Affects every provider app in this workshop: `provider-ollama`, `-openai`, `-anthropic`, `-azure`, `-aws`, `-google` (all of them inherit `spring-ai-starter-mcp-client` transitively via `components/config-dashboard`).

Reported upstream to Christian Tzolov (workshop maintainer's colleague on the Spring AI team) on 2026-05-28; awaiting fix in M7.1 / M8 / GA.

### The workaround (currently in place)

Each provider's main `application.yaml` carries a top-level `spring.autoconfigure.exclude` block:

```yaml
spring:
  autoconfigure:
    exclude:
      # Spring AI 2.0.0-M7 packaging bug — these autoconfigs reference classes in the
      # unpublished spring-ai-autoconfigure-mcp-client-common artifact and crash at startup.
      # Workshop's MCP Inspector builds clients manually so it does not need them.
      - org.springframework.ai.mcp.client.httpclient.autoconfigure.SseHttpClientTransportAutoConfiguration
      - org.springframework.ai.mcp.client.httpclient.autoconfigure.StreamableHttpHttpClientTransportAutoConfiguration
```

Why it works: `spring.autoconfigure.exclude` is consumed by `AutoConfigurationImportSelector` BEFORE the annotation-driven `EnableConfigurationPropertiesRegistrar` runs on the imported configs — the broken classes never reach the registrar, so the missing-class lookup never fires.

Why excluding the autoconfigs is safe for the workshop: the only consumer of MCP client beans in the providers is the dashboard's `McpInspectorController` + `McpClientRegistry`, and both build `McpSyncClient` instances manually via `McpClient.sync(transport)` / `SyncMcpToolCallbackProvider.builder()`. They do not depend on the auto-wired `McpAsyncClient` / `McpSyncClient` beans that the excluded autoconfigs would have produced.

What is NOT covered: the standalone `mcp/03-mcp-client` demo module **does** consume the auto-wired beans (it injects `ToolCallbackProvider tools` and uses `spring.ai.mcp.client.stdio.servers-configuration` config). That module is **expected to fail to boot on M7** until upstream ships the fix; it is not used by the dashboard at runtime, so the workshop's main paths still work.

### Verification that the workaround holds

Run the user's actual failure scenario (4 profiles, the same combination that originally crashed):

```bash
./mvnw spring-boot:run -pl applications/provider-ollama \
  -Dspring-boot.run.profiles=pgvector,observation,ui,spy
```

Expected: a normal Spring Boot banner followed by `Started OllamaApplication in N seconds`, Tomcat on :8080, PostgreSQL HikariCP up, PgVectorStore initialized. The workaround was verified post-fix on 2026-05-28 — full boot in 2.972 seconds with the 4-profile combination.

### What to do when bumping to 2.0.0-GA (or any later milestone)

The workaround is technical debt — when upstream fixes the packaging, the exclude block should come out. Concrete checklist for the next bumper:

- [ ] **First step of the next bump:** check whether `spring-ai-autoconfigure-mcp-client-common` is published for the target version:
  ```bash
  curl -sI https://repo.spring.io/release/org/springframework/ai/spring-ai-autoconfigure-mcp-client-common/<VERSION>/spring-ai-autoconfigure-mcp-client-common-<VERSION>.jar
  ```
  HTTP 200 ⇒ upstream fix shipped, the exclude can be removed. HTTP 404 ⇒ still broken; keep the exclude.

- [ ] If the artifact is published OR the autoconfig in `spring-ai-autoconfigure-mcp-client-httpclient` no longer references `org.springframework.ai.mcp.client.common.autoconfigure.*` (alternative upstream fix where the properties were relocated/inlined), remove the `spring.autoconfigure.exclude` block from all 6 provider `application.yaml` files in the same commit as the BOM bump. Touch only those 6 files for this cleanup — do not blanket-edit other yaml.

- [ ] Boot at least one provider with the original failing profile combination (`pgvector,observation,ui,spy`) to confirm the upstream fix landed and the workaround is no longer needed.

- [ ] If `mcp/03-mcp-client` was disabled / annotated as broken during the M7 era, re-enable / re-test it in the new bump.

- [ ] Remove this Part 5b section (or move it to the post-mortem record) once the workaround is gone — keeping it around after it stops applying just creates noise for the bumper after that.

### Affected files (workshop side)

Touched in commit `968807b`:

- `applications/provider-ollama/src/main/resources/application.yaml`
- `applications/provider-openai/src/main/resources/application.yaml`
- `applications/provider-anthropic/src/main/resources/application.yaml`
- `applications/provider-azure/src/main/resources/application.yaml`
- `applications/provider-aws/src/main/resources/application.yaml`
- `applications/provider-google/src/main/resources/application.yaml`

Each has the same 7-line `spring.autoconfigure.exclude` block added at the top of the main `spring:` document (before any `---`-separated profile blocks).

---

## Part 6 — Recommended follow-ups (NOT done in this bump)

1. **Rename `mcp/05-mcp-capabilities/src/test/java/mcp/capabilities/ClientSse.java` to `ClientStreamableHttp.java`** — class is currently misleadingly named (uses `HttpClientStreamableHttpTransport`, not SSE). Pure cleanup; deferred so this bump diff stays focused on M7.

2. **Capture the M7 `ToolCallAdvisor`-as-default pattern as a callout in `docs/spring-ai/SPRING_AI_INTRODUCTION.md`** — the introduction's "Advisors and Request Context" subsection should pick up `ToolCallAdvisor` alongside `MessageChatMemoryAdvisor` as a default-installed advisor attendees should know about.

3. **Document `ToolSpec` fluent API in Stage 5 (chat-tools) docs** — new in M7 (#6085), additive. Worth showing as a forward-looking pattern next to `@Tool` and `FunctionToolCallback.builder()`.

4. **Watch for the next Spring AI milestone (M8 / GA).** Particularly:
   - Whether `ToolCallAdvisor` gets renamed or split before GA — early-stage APIs often shift.
   - MCP Java SDK trajectory toward `1.0.0` (the M-series is interim).
   - Whether the `spring-cloud-bindings` removal lands a replacement for K8s/CloudFoundry binding workflows we'd want to surface in docs.

5. **Re-test the `spy` gateway path** with M7 — same caveat as in `SPRING_AI_M4_TO_M5_MIGRATION.md` §7.4: the openai-java SDK constructs paths itself, so if its base-URL handling changes the gateway route logic in `applications/gateway/.../RouteConfig.java` may need adjusting again.

---

*Plan authored: 2026-05-28. Author: workshop maintainer + Claude (planning session). Execution to follow once approved.*
