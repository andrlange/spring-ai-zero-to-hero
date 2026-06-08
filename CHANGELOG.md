# Changelog — Spring AI Zero-to-Hero Workshop

## [2.3.8] - 2026-06-08

### Changed
- Bumped Spring AI from `2.0.0-M8` → `2.0.0-RC1` across the parent POM, workshop docs, dashboard, slides (and `slides.html.original` baseline), Grafana dashboard, `workshop.sh` banners, OpenAPI metadata, and all provider/component readmes. **This is the first breaking bump since the Boot 4 / Spring AI 2.0-M4 migration** — three real code/build changes were required (below).
- **`chat_05/ToolController` migrated off the removed `toolNames()` API.** The `weatherFunction` `FunctionToolCallback` bean is now injected into the controller and passed explicitly via `.tools(this.weatherTool)` at the `/chat/05/weather` and `/chat/05/pack` endpoints (previously resolved by name through `SpringBeanToolCallbackResolver`). See #6301 / #6154 below.
- **`image_01/ImageController`**: `ImageOptionsBuilder.builder().N(1)` → `.n(1)` (#6285).
- **`components/patterns/02-retrieval-augmented-generation/pom.xml`**: advisor dependency `artifactId` renamed `spring-ai-advisors-vector-store` → `spring-ai-vector-store-advisor` (#6309, "Move advisors to their proper modules"; confirmed against the published RC1 BOM on Maven Central).
- **Stage 7 agents (`01-inner-monologue`, `02-model-directed-loop`): `toolChoice("required")` → typed `ChatCompletionToolChoiceOption.ofAuto(Auto.REQUIRED)`.** RC1's `OpenAiChatModel.createRequest` throws `UnsupportedOperationException: SDK version does not support typed 'required' toolChoice` for the plain `"required"`/`"none"` strings (only `"auto"`, a named-function choice, or a pre-built typed `ChatCompletionToolChoiceOption` are accepted) — even though the shipped `openai-java-core` 4.38.0 supports `ofAuto(Auto.REQUIRED)`. This is an RC1 regression (M8 accepted the string); both agents forced `send_message` via the string and failed at runtime on the OpenAI provider. Updated the OpenAi option + controller-fixture tests to match. Found via manual Stage 7 runtime testing, not caught by the reactor build.
- New `v2.0.0-RC1` (2026-06-06) entry added to the pixel-art Spring AI History timeline; M8 retitled from "Where we are today" to "MCP autoconfig packaging fixes".
- Docs: retired the `ToolSpec` row from `SPRING_AI_STAGE_1.md` (consumer API removed in RC1, see #6292); `ToolCallAdvisor` → `ToolCallingAdvisor` prose in `SPRING_AI_INTRODUCTION.md` + `SPRING_AI_STAGE_8.md`.

### Removed (upstream — RC1 release-notes items relevant to us)
- **#6301 / #6154 — `toolNames()` API and `SpringBeanToolCallbackResolver` removed.** Direct compile break in `chat_05/ToolController` (two call sites). Migrated to explicit `ToolCallback` beans passed via `.tools(...)`.
- **#6285 — `N()` renamed to `n()` in options builders.** Direct compile break in `image_01/ImageController`.
- **#6309 — Advisor modules moved/renamed.** Build break in the RAG pattern module — dependency `artifactId` renamed.
- **#6292 — `ToolSpec` consumer API removed from `ChatClient`.** No code impact (we never used `o.s.ai.tool.ToolSpec`), but documentation referencing it (Stage 1) was retired. Note: the `SyncToolSpecification` references in `mcp/04` + Stage 6 are MCP SDK types, **not** the removed Spring AI `ToolSpec` — they remain.
- **#6303 — `ToolCallAdvisor` renamed to `ToolCallingAdvisor`** (deprecated `ToolCallAdvisor` shim retained one release). No code impact — we use the auto-configured default, not a direct instantiation; prose updated.
- **#6252–#6272 — Built-in tool-execution loop removed from every `ChatModel`** (OpenAI, Ollama, Anthropic, Mistral, DeepSeek, MiniMax, Bedrock proxy). No impact — all workshop tool calling flows through `ChatClient` / `ToolCallingAdvisor`, which is now the sole auto-execution path. Verified at runtime (below).
- **#6289 — `internalToolExecutionEnabled` removed.** No-op — no usages in the codebase.
- **#6290 / #6149 / #6210 — MiniMax dedicated support removed, Pixtral Large retired, deprecated Mistral models dropped.** No-op — none used by the workshop's 6 providers.

### Other release-notes items not relevant here
- **#6204 — `ChatClientCustomizer` deprecated/renamed → `ChatClientBuilderCustomizer`.** No-op — not used anywhere in the codebase.
- **#6312 — Turn-boundary snapping in `MessageWindowChatMemory` eviction.** Automatic behavioural improvement; benefits Stage 4 chat-memory demos (eviction no longer splits a conversational turn). No API change.
- **#5909 — Tool Search Tool advisor for on-demand tool discovery** (new `spring-ai-tool-search-*` modules, vector-store / Lucene / regex `ToolIndex` backends). Additive; not adopted — candidate future stage content.
- **#6165 — `EntityParamSpec` for per-call structured output on `ChatClient.entity()`.** Additive; not adopted.
- **#6280 — SLF4J replaced by `org.apache.commons.logging.LogFactory`** internally. No-op — our logging config is unaffected.
- **#6194 / #5963 — DeepSeek V4 chat model constants + function-calling fix.** No-op — DeepSeek not used.
- **#6287 — MCP Java SDK 2.0.0-M3 → 2.0.0-RC1** (transitive via the BOM). All 5 `mcp/` submodules (`SyncToolSpecification`, `McpToolUtils.toSyncToolSpecifications`, `McpSyncServer.addTool`, `ClientSse`) compile and pass tests with **zero code changes**.

### Reactor verify
- `./mvnw clean verify` — 42 modules, BUILD SUCCESS, all tests pass (~17s).
- Runtime smoke: `provider-ollama` (`ui` profile) — `Started OllamaApplication in 2.1 seconds`. Verified the migrated endpoints return tool-backed answers: `/chat/05/time`, `/chat/05/weather` + `/chat/05/pack` (both `toolNames()`→`.tools()` sites with the injected `FunctionToolCallback`), and `/rag/01/query` (renamed advisor artifact loads and runs through `RetrievalAugmentationAdvisor`).
- Stage 7 runtime smoke (OpenAI profile): both agents return tool-backed responses with the typed `toolChoice` fix — inner-monologue (`/agents/inner-monologue/{id}/messages`) and model-directed-loop (`/agents/model-directed-loop/{id}/messages`), HTTP 200, `isFallback:false`, loop terminates.

## [2.3.7] - 2026-05-28

### Changed
- Bumped Spring AI from `2.0.0-M7` → `2.0.0-M8` across the parent POM, workshop docs, dashboard, slides (and `slides.html.original` baseline), Grafana dashboard, `workshop.sh` banners, OpenAPI metadata, and all provider/component readmes.
- New `v2.0.0-M8` (2026-05-27) entry added to the pixel-art Spring AI History timeline; M7 retitled from "Where we are today" to "ToolCallAdvisor default + MCP SDK M3".

### Removed
- **The M7 mcp-client autoconfig workaround.** The 7-line `spring.autoconfigure.exclude` block added by commit `968807b` is gone from all 6 provider `application.yaml` files. M8 #6138 (sdeleuze) restored the missing `spring-ai-autoconfigure-mcp-client-common` transitive dependency, so the previously-unpublished property classes (`McpSseClientProperties`, `McpStreamableHttpClientProperties`, `McpClientCommonProperties`) are now resolvable at startup and providers boot cleanly without manual exclusion.

### Fixed upstream (M8 release-notes items relevant to us)
- **#6138 — Restore transitive autoconfig dependencies.** This is the upstream fix for the M7 packaging bug that crashed every provider boot in our workshop. Verified post-bump: `provider-ollama` boots cleanly in 1.6 seconds with `ui,spy` profiles (no workaround needed).
- **#6164 — `spring-ai-starter-vector-store-pgvector` requires `spring-boot-starter-jdbc`.** No effect for us — our 3 pgvector providers (openai, azure, ollama) already include `spring-boot-starter-flyway` which pulls jdbc transitively. The fix closes a latent footgun for upstream users.
- **#6171 — `spring-ai-starter-model-google-genai` over-declared embedding dependency.** `provider-google/pom.xml` already has an explicit `<exclusions>` block against the embedding artifact; M8 removes the embedding dep from the starter so our exclusion is now redundant (left in place for this bump — optional follow-up to clean up).
- **#6150 — M7 forced API-key requirement broke cookie/session auth.** No effect — we always provide API keys via `creds.yaml`.

### Other release-notes items not relevant here
- **#6186 — Dash-separated convention for Spring Boot properties.** No-op — all workshop `spring.ai.*` config keys already use dash-separated naming.
- **#6127 — `ChatOptions#mutate` return-type specificity.** No-op — no `.mutate(...)` calls in our codebase.
- **#6090 — Exclude `jackson-dataformat-yaml` from `json-schema-validator`.** No-op — we don't depend on `jackson-dataformat-yaml` directly.
- **#5585 — MistralAI Jackson mapping improvements.** No-op — we don't use Mistral.

### Reactor verify
- `./mvnw clean verify` — 42 modules, BUILD SUCCESS, all tests pass.
- Runtime smoke: `provider-ollama` with `ui,spy` profiles — `Started OllamaApplication in 1.569 seconds` (no workaround block present, M8 fix is live).

## [2.3.6] - 2026-05-28

### Changed
- Bumped Spring AI from `2.0.0-M6` → `2.0.0-M7` across the parent POM, workshop docs, dashboard, slides (and the `slides.html.original` baseline), Grafana dashboard, `workshop.sh` banners, the OpenAPI metadata, and all provider/component readmes.
- New `v2.0.0-M7` (2026-05-22) entry added to the pixel-art Spring AI History timeline; the prior "Where we are today" sign now sits on M6.

### Migrated (M7 changes audited)
- **`ToolCallAdvisor` is now the default tool-call management option (#5459, #6096, #6111).** Behavioral change: tool calls execute through the advisor chain instead of the internal model loop. No code changes needed — all tool-using surfaces (chat_05 demos, both agentic agents, MCP client modules, dashboard MCP Inspector) compile clean and unit tests pass. Stage 8 observability span tree may now include a `tool.call.advisor` wrapper — verification deferred to runtime smoke tests against a live provider (workshop maintainer to confirm and refresh Grafana panels / Stage 8 docs if span shape changed).
- **MCP Java SDK 2.0.0-M2 → 2.0.0-M3 (#6121).** Audited every M3 breaking change against our imports before bumping: `ResourceReference` reduced `(type, uri)` → `(uri)` (we already use the 1-arg form at `mcp/05-mcp-capabilities/.../ClientSse.java:94`); `PromptReference.equals/hashCode` keyed on name only (we don't use it as a map/set key); `CompleteReference.identifier()` deprecated (we don't import it); `CreateMessageRequest.maxTokens` / `CreateMessageResult.model` mandatory (we don't construct either); "builders now require mandatory args in factory" (`McpClient.sync(transport)` / `HttpClientStreamableHttpTransport.builder(url)` already satisfy this). All 5 `mcp/` submodules compile and pass tests on M3 with **zero code changes**.
- **SSE transports deprecated, Streamable HTTP becomes the default server protocol (#5969).** No-op — all 3 HTTP-based MCP servers (`02-mcp-http-server`, `04-dynamic-tool-calling`, `05-mcp-capabilities`) already pin `protocol: STREAMABLE` + `streamable-http.mcp-endpoint`; `01-mcp-stdio-server` uses stdio. The misleadingly-named `ClientSse.java` test in `mcp/05-mcp-capabilities` already uses `HttpClientStreamableHttpTransport`; class rename left as a follow-up.
- **PgVector dimension validation added (#4868).** Configured dimensions already match each provider's embedding model (`openai`: 1536 / `azure`: 1536 / `ollama`: 768 — matching `text-embedding-3-small` / `text-embedding-3-small` / `nomic-embed-text` respectively). Smoke-test against a live Postgres deferred to workshop maintainer; expected to pass.
- **`ChatOptions` setters removed (#6025).** No-op — the codebase migrated to `ChatOptions.Builder` everywhere during the [2.3.4] M4 → M5 bump.
- **Gemini default `GEMINI_2_0_FLASH` → `GEMINI_2_5_FLASH` (#6003).** No-op — all Google references already use `gemini-2.5-flash`.

### Other release-notes items not relevant here
- Removed `spring-ai-spring-cloud-bindings` (#6079) and CosmosDB components (#6080) — not used.
- Ollama GraalVM native-image fix (#6043) — we don't compile native images.
- OpenAI streaming chunk-loss and metadata-preservation fixes (#5120, #5929, #6014) — beneficial, no code change needed; `chat_08/StreamingChatModelController` benefits transparently.
- Kotlin MCP nullable-fields fix (#5997) — Java-only codebase.
- `OpenAi*Options` setters and `OpenAiChatOptions.AbstractBuilder#combineWith` fix (#6045, #6042) — we always use builders and don't override OpenAI options at request time.
- New `ToolSpec` fluent API (#6085) — additive; we keep using `@Tool` + `MethodToolCallbackProvider` + `FunctionToolCallback.builder()`. Documenting `ToolSpec` in Stage 5 docs is left as a follow-up.
- Per-call `customHeaders` not propagated in `OpenAiImageOptions` (#6082), Docker Model Runner fix (#6036), Redis vector store fix (#5998), recursive `$ref` resolution (#5888), `WebFluxSseClientTransport` validator (#5967), Google GenAI start.spring.io fix (#6005) — none of these surfaces are exercised by this workshop.

### Reactor verify
- `./mvnw clean verify` — 42 modules, BUILD SUCCESS, all tests pass, no new deprecation warnings on the four watched surfaces (`ToolCallAdvisor`, `SSE`, `Streamable`, `ChatOptions`). Wall-clock ~14s.

### Post-merge fix — Spring AI M7 mcp-client packaging bug
- **Issue:** Spring AI 2.0.0-M7's `spring-ai-autoconfigure-mcp-client-httpclient` references classes in `org.springframework.ai.mcp.client.common.autoconfigure.*` — but that artifact (`spring-ai-autoconfigure-mcp-client-common`) was not published for M7. Every provider app crashes at startup with `ClassNotFoundException: McpSseClientProperties` BEFORE `@ConditionalOnProperty` is evaluated (so `enabled=false` does not work). Reactor `mvn clean verify` did not catch this — unit tests use sliced contexts that don't load MCP autoconfig.
- **Workaround applied** (commit `968807b`): added `spring.autoconfigure.exclude` for both `SseHttpClientTransportAutoConfiguration` and `StreamableHttpHttpClientTransportAutoConfiguration` to each of the 6 provider `application.yaml` files. Verified post-fix with the original failing scenario (`spring-boot:run -pl applications/provider-ollama -Dspring-boot.run.profiles=pgvector,observation,ui,spy`) — boot completes cleanly in ~3 seconds.
- **Followup for 2.0.0-GA / M7.1:** see `SPRING_AI_M6_TO_M7_UPGRADE_PLAN.md` Part 5b — remove the exclude block once upstream republishes the missing `mcp-client-common` artifact (or inlines/relocates the property classes into `mcp-client-httpclient`). Upstream bug reported.
- **Known limitation:** the standalone `mcp/03-mcp-client` demo module consumes the auto-wired beans the exclude removes and is expected to fail to boot on M7. The dashboard's MCP Inspector (which is the path attendees actually exercise) builds clients manually and is unaffected.

## [2.3.5] - 2026-05-10

### Added
- Interactive pixel-art **Spring AI History** page at `/spring-ai-history.html`, linked from the dashboard sidebar (Tools → History). Scroll-driven walk through ~30 Spring AI release tags (`v0.8.0` → `v2.0.0-M6`) interleaved with 6 ecosystem events (ChatGPT, GPT-4, Llama 2, Claude 3, MCP open-sourcing, Spring Boot 4 GA) in strict chronological order. Lime-character mascot with bobbing walk cycle and a hop animation when passing ecosystem events; sign-post side panel reveals release headlines and bullets. Press Start 2P pixel font vendored locally under `static/vendor/press-start-2p/` so the page works airgapped.

### Changed
- Bumped Spring AI from `2.0.0-M5` → `2.0.0-M6` across the parent POM, workshop docs, dashboard, slides, Grafana dashboard, `workshop.sh` banners, and all provider/component readmes.

### Migrated (M6 breaking changes)
- **`PromptChatMemoryAdvisor` removed.** `components/patterns/03-chat-memory/.../mem_02/ChatHistoryController.java` migrated to `MessageChatMemoryAdvisor`.
- **`MessageChatMemoryAdvisor.Builder.conversationId(String)` removed.** The conversation id is now supplied at request time via the `ChatMemory.CONVERSATION_ID` context key (`BaseChatMemoryAdvisor#getConversationId(Map)` asserts it is present, with no implicit default). Both agentic-system `Agent` classes (`01-inner-monologue`, `02-model-directed-loop`) now wire the id through `ChatClient.Builder.defaultAdvisors(spec -> spec.advisors(...).param(ChatMemory.CONVERSATION_ID, id))`. Both `AgentTest` mock setups gained a `defaultAdvisors(Consumer)` stub to match.
- **Chat-memory docs updated.** `docs/spring-ai/SPRING_AI_STAGE_4.md` and `docs/spring-ai/SPRING_AI_STAGE_7.md` rewritten to use `MessageChatMemoryAdvisor` and the M6 context-key pattern; the per-agent memory section in Stage 7 now shows the M5 → M6 delta.
- **MCP modules** — all 5 `mcp/` submodules compile and pass tests on M6 without code changes.
- **Other release-notes items not relevant here:** OpenAI options class refactor (we don't subclass `AbstractOpenAiOptions` or call setters), `OpenAiConnectionProperties` → `OpenAiCommonProperties` rename (we don't reference it), `OpenAiEmbeddingOptions#encodingFormat` enum (we don't set it), removed `spring-ai-hanadb-store` / `spring-ai-infinispan-store` (not used), `ModelOptionsUtils` method removals (not used).

## [2.3.4] - 2026-04-28

### Changed
- Bumped Spring AI from `2.0.0-M4` → `2.0.0-M5` across the parent POM, workshop docs, dashboard, slides, Grafana dashboard, `workshop.sh` banners, and all provider/component readmes.

### Migrated (M5 breaking changes)
- **Azure OpenAI** — `spring-ai-azure-openai` was removed in M5. `applications/provider-azure` now depends on `spring-ai-starter-model-openai` and runs in "Microsoft Foundry" mode (auto-detected when `spring.ai.openai.base-url` ends with `openai.azure.com`). Config keys moved from `spring.ai.azure.openai.*` to `spring.ai.openai.*`; `creds-template.yaml`, `application.yaml`, `DebugController`, and the Azure provider readme were rewritten to match. Existing Azure resources/keys/deployments work unchanged. Dropped the unused `spring-ai-azure-store` dependency.
- **`ChatClient.Builder.defaultOptions(...)` and `ChatClientRequestSpec.options(...)`** now take a `ChatOptions.Builder` instead of a built `ChatOptions` (release: "options merging moved to ChatClient level"). Updated `MultiModalController`, both agentic-system `Agent` classes + their controllers + `AgentOptionsConfig` beans + tests to pass and inject builders.
- **OpenAI internal API package** — `org.springframework.ai.openai.api.*` no longer exists; the module now uses the official `openai-java` SDK directly. `TranscribeController` now imports `com.openai.models.audio.AudioResponseFormat` (was `OpenAiAudioApi.TranscriptResponseFormat`).
- **MCP modules** — all 5 `mcp/` submodules compile and pass tests on the upgraded MCP Java SDK 2.0.0-M2 without code changes.

## [2.3.3] - 2026-04-24

### Changed
- Bumped Spring Boot from `4.0.5` → `4.0.6` across the parent POM, workshop docs, dashboard, slides, OpenAPI description, Grafana dashboard, `workshop.sh` banners, and all provider/component readmes. No code changes required — 4.0.6 is a maintenance release with no breaking changes relevant to the workshop (notable fixes — actuator-without-health security misconfig, Jackson `use-jackson2-defaults`, Elasticsearch REST5Client, MongoDB reactive driver transitive, Cassandra/RabbitMQ config — do not affect any module here).
- Transitively picks up Spring Framework `7.0.7`, Spring Security `7.0.5`, Hibernate `7.2.12` via the managed parent.

## [2.3.2] - 2026-04-19

### Added
- Dockerized Ollama as an optional, first-class alternative to a host install. New `docker/ollama/docker-compose.yaml` (CPU default) + `docker-compose.gpu.yaml` overlay for NVIDIA. Mounts `models/ollama/` into the container; same port 11434 so `provider-ollama` config is unchanged.
- `models/ollama.sh import` target chooser: `--target=ollama` (native, tarball), `--target=docker` (dockerized models dir, tarball), `--target=docker-pull` (runs `docker exec ollama ollama pull` for every `WORKSHOP_MODELS` entry). Interactive prompt offers all three.
- `models/containers.sh` `--with-ollama` flag and opt-in prompt for `ollama/ollama:latest` (~1.3 GB).
- `workshop.sh`: new `infra ollama` target, new `--ollama-docker` flag on `start`, new `[3/4]` optional step in `setup` for the Ollama image, and a three-state runtime indicator (`ollama:docker` / `ollama:local` / `ollama:off`) in the menu header and `status` output.
- `docs/ollama_dockerized.md` — canonical reference with performance notes (macOS CPU-only, x86 vs arm64, NVIDIA overlay), airgapped workflow, and commands.

### Changed
- `cmd_stop` now includes the dockerized Ollama in its single "stop Docker containers?" prompt when the container is up.
- `cmd_check` and `cmd_status` distinguish native vs dockerized Ollama and surface actionable hints when neither is running.
- `README.md`, `docs/quickstart.md`, `docs/guide.md`, `docs/providers.md`, `docs/troubleshooting.md` — cross-referenced to the new doc; quickstart gains a Section 3.5 airgapped recipe; troubleshooting gains three new entries.

### Notes
- macOS containers cannot access Metal — native `Ollama.app` remains preferred on Apple Silicon for performance. The dockerized path targets attendees without a local install and airgapped environments.

---

## [2.3.1] - 2026-04-18

### Added
- Stage 7 dashboard UI at `/dashboard/stage/7` — two cards (Inner Monologue, Model-Directed Loop) with inline chat consoles, multi-step trace rendering, provider pills, live curl lines.
- Ollama support for Stage 7 agents alongside OpenAI — one jar per agent, Spring profile selects provider.
- `./workshop.sh agentic start|stop|status|logs` subcommand family managing agent apps on ports `:8091`/`:8092`.
- Fallback handler in both agents for weak local models: wraps free-form / malformed responses with `[fallback: model replied without tool]` marker. Demo 02 forces `requestReinvocation=false` on fallback to stop the loop cleanly.
- Gateway spy routing for Ollama: `ollama,spy` profile combo now actively routes through `:7777/ollama` (the gateway route pre-existed in `RouteConfig.java`).
- New agent REST endpoints: `POST /{id}/reset` and `GET /{id}/log` for memory management and history inspection.
- `WHATS_NEW_STAGE_07_AGENTIC.md` attendee + trainer walkthrough.
- Stage 7 troubleshooting section in `docs/troubleshooting.md`.

### Changed
- `docs/spring-ai/SPRING_AI_STAGE_7.md` — added dashboard endpoint inventory, Ollama model compatibility matrix (incl. `llava` counter-example), fallback behavior anchor, observability + gateway spy notes.
- `agentic-system/*/readme.md` — "New in Stage 7 UI" intro boxes.
- `docs/guide.md` — Stage 7 section with `workshop.sh agentic` commands.

### Fixed
- Stage 7 fullscreen console — long pasted prompts no longer push the **Send** button out of view. The message form uses CSS Grid (`minmax(0, 1fr) auto`) and the center column is explicitly constrained with `grid-template-columns: minmax(0, 1fr)`, so a large textarea value wraps internally instead of blowing the column out.
- Stage 7 fullscreen exit — topbar icons (theme toggle, provider/profile pills, UI entry) re-enter the viewport. JS now remembers `window.scrollY` on fullscreen enter and restores it on exit, so the page no longer sits at a stale scroll offset after the fixed-positioned console returns to normal flow.

### Breaking
- Removed `inner-monologue-agent` and `model-directed-loop-agent` dependencies from `applications/provider-openai/pom.xml` (commit `c0759a6`) — Stage 7 agents now exclusively run as **standalone Spring Boot processes** on `:8091`/`:8092`, launched via `./workshop.sh agentic start all`. The legacy "all-in-one on :8080" mode (where the agent REST controllers were served from the provider app's JVM) is no longer supported. The dashboard at `:8080` proxies to the standalone agents over HTTP.

---

## [2.3.0] — 2026-04-17: Stage 6 MCP Dashboard UI & Coordinated Lifecycle

Stage 6 (Model Context Protocol) moves from CLI-only to a first-class dashboard chapter. Every MCP demo is now runnable, inspectable, and invokable from `http://localhost:8080/dashboard/stage/6`, backed by a new `./workshop.sh mcp` command family that manages the five demos' lifecycle from a single script.

> 👉 **Attendee + trainer walkthrough:** [`WHATS_NEW_STAGE_06_MCP.md`](WHATS_NEW_STAGE_06_MCP.md) — recommended demo order, time budget, trainer notes, and troubleshooting.
>
> **Deep-dive reference:** [`docs/spring-ai/SPRING_AI_STAGE_6.md`](docs/spring-ai/SPRING_AI_STAGE_6.md) — per-demo flow diagrams, key code, MCP JSON-RPC endpoints, and curl equivalents.

### Dashboard — Stage 6 page

- **New `/dashboard/stage/6`** with five demo cards (01 STDIO, 02 HTTP, 03 Client, 04 Dynamic, 05 Full Capabilities). Live status pills poll every 3 seconds via a TCP port probe (not actuator health — 04's `CountDownLatch` blocks health readiness).
- **Tool inspection modal** (Bootstrap-5, styled after the stages 1–5 gateway modal) opens from each card's **List tools** button. Each tool renders as a card with collapsible input schema and an **Invoke** button that expands a schema-driven argument form.
- **Per-tool Invoke form** builds a live curl line below the submit button that updates as you type; one-click copy to clipboard, same UX as stages 1–5.
- **Resource inspection** (05 only) merges `resources/list` + `resources/templates/list` into one list with `resource`/`template` badges, pre-fills each URI, and offers a **Read** button with live curl.
- **Prompt inspection** (05 only) renders per-prompt argument forms with typed inputs, `@McpArg` descriptions as visible helper text, and live curl.
- **Demo 03 Run** renders the LLM response as chat bubbles (user question → assistant answer with markdown rendering) and a `tools from: 01+02` badge indicating which MCP servers contributed tools. Raw envelope available via a `Raw response` collapsible.
- **Demo 04 Dynamic registration** trigger button with a one-shot-latch-aware UX; list-tools re-invocation after registration shows the new math tools in a fresh modal.
- **Docs button on every card** opens the corresponding Demo section of `SPRING_AI_STAGE_6.md` in a modal, with Mermaid diagrams rendered client-side (matching the stages 1–5 docs modal).

### Backend — `components/config-dashboard/src/main/java/com/example/dashboard/mcp/`

- **`McpDemoCatalog`** — static catalog of the five demos with id, title, one-liner, transport, port, module path, capabilities enum.
- **`McpClientRegistry`** — long-lived `McpSyncClient` cache for 02/04/05, connected via `HttpClientStreamableHttpTransport` (Streamable HTTP — **no SSE** anywhere in this codebase). TCP port probe for `isUp`. Graceful eviction on errors; `@PreDestroy` closes all connections.
- **`McpStdioInvoker`** — per-request subprocess spawn for 01 STDIO using `StdioClientTransport(ServerParameters, McpJsonDefaults.getMapper())`. Jar path resolved by walking up from the JVM cwd so the provider app (running from its module dir) still finds `mcp/01-mcp-stdio-server/target/*.jar`. Caller-managed `openClient()` API for multi-step flows (e.g. holding the STDIO client open across a ChatClient call).
- **`McpInspectorController`** — REST endpoints under `/dashboard/mcp/`:
  - `GET /{id}/status` — status + port + capabilities + transport + startCommand hint
  - `GET /{id}/tools` — list tools (routes 01 → StdioInvoker, others → ClientRegistry)
  - `POST /{id}/invoke` — call a tool with JSON args
  - `GET /{id}/resources` — **merges** `listResources()` + `listResourceTemplates()`
  - `GET /{id}/resources/read?uri=…` — read a specific resource
  - `GET /{id}/prompts` — list prompts
  - `POST /{id}/prompts/get` — get a prompt with args
  - `POST /04/update-tools` — proxy to 04's `/updateTools` with cache reset
  - `POST /03/run?mode=local` — build `SyncMcpToolCallbackProvider` on-demand from live 01+02 clients (with `DefaultMcpToolNamePrefixGenerator` to disambiguate duplicate tool names); external mode returns 400 pointing at the CLI
- **Unit tests** — 23 new tests across `McpDemoCatalogTest`, `McpClientRegistryTest`, `McpStdioInvokerTest`, `McpInspectorControllerTest`, `McpDemoTest`.

### `workshop.sh` — coordinated MCP lifecycle

```bash
./workshop.sh mcp start all          # build 01 jar + start 02/04/05
./workshop.sh mcp start 02           # start just 02
./workshop.sh mcp status             # table: id | port | pid | up?
./workshop.sh mcp logs 04            # tail 04's log
./workshop.sh mcp stop all           # stop them cleanly
./workshop.sh mcp build-01           # build the STDIO jar
```

- PID + log files under `.workshop/mcp/` (gitignored).
- Per-demo port probing via `nc -z`/`/dev/tcp` (not `/actuator/health` — works around 04's latch).
- Process-group kill with `lsof -ti:<port> | xargs kill -9` fallback so Maven's forked JVM children are reaped cleanly.
- Exit codes propagate correctly for CI use (invalid id → exit 1).
- **Interactive TUI menu items 11–14** (Start MCP demo / Stop MCP demo / MCP status / Tail MCP logs) added to `draw_menu`.
- **Status banner** (`services_status_line`) now shows `MCP: 02✓ 04✗ 05✓` alongside provider / spy / ui / pg / lgtm.
- **Bash 3.2 compat preserved** — macOS bash 3.2 doesn't support `declare -A`, so lookups use case-helpers (`mcp_port_for`, `mcp_module_for`, `mcp_label_for`).

### MCP module changes

- **Module renames** (to match the canonical doc and remove the redundant "basic" word):
  - `mcp/01-basic-stdio-mcp-server/` → `mcp/01-mcp-stdio-server/`
  - `mcp/02-basic-http-mcp-server/` → `mcp/02-mcp-http-server/`
  - `mcp/03-basic-mcp-client/` → `mcp/03-mcp-client/`
  - 04, 05 dir names unchanged
  - Artifact IDs and parent pom module list updated in lockstep
- **Port allocation** — HTTP demos pinned to distinct ports: 02 → `:8081`, 04 → `:8082`, 05 → `:8083`. Each exposes `/actuator/health` (new `spring-boot-starter-actuator` dependency).
- **04 client URL fix** — `http://localhost:8080/updateTools` → `http://localhost:8082/updateTools` so the demo client actually reaches its paired server instead of the provider app.
- **01/02 weather tool rework** — `getTemperature` now accepts city OR coordinates (or both). Missing args no longer NPE; city-only path geocodes via Open-Meteo before fetching the forecast. Returns a `TemperatureResult` record; not-found cases return a friendly `note` field instead of throwing.
- **04/05 tool parameters annotated** — every `@Tool` method has `@ToolParam` descriptions with concrete examples. `getAlerts` parameter description enumerates all 50 US state codes + DC + PR. 04's `MathTools` has example invocations per tool.
- **05 resources, prompts annotated** — `@McpResource` descriptions list known demo usernames (`john`, `jane`, `bob`, `alice`); `@McpArg` descriptions on every prompt argument carry example values.

### Demo 03 — dual-config refactor

- Extracted `McpClientDemoRunner` bean from the inline `CommandLineRunner`; CLI now delegates, dashboard's `/03/run` uses its own path.
- `mcp-servers-config.json` split into `mcp-servers-local.json` (01 STDIO jar + 02 HTTP) and `mcp-servers-external.json` (Brave Search + filesystem via `npx`).
- `application.yaml` split into default (local) + `mcp-external` profile.
- Local mode is the default and closes the 01→02→03 pedagogical arc; external mode preserved for attendees who want the full MCP ecosystem experience.

### Dashboard backend dependency

- `spring-ai-starter-mcp-client` is now a non-optional dependency of `components/config-dashboard`. Optional blocked `spring-ai-mcp` (home of `SyncMcpToolCallbackProvider`) from transitively reaching provider apps, which broke `/03/run` at runtime. Making it required propagates the client starter to every provider app; the MCP client autoconfig is a no-op when no connections are configured.
- `spring-boot-webmvc-test` added (Spring Boot 4 moved `@WebMvcTest` to this artifact; no longer transitive via `spring-boot-starter-test`).

### Documentation

- **New root-level [`WHATS_NEW_STAGE_06_MCP.md`](WHATS_NEW_STAGE_06_MCP.md)** — 7-step walkthrough, time budget, trainer notes, FAQ, and implementation highlights. Linked from `README.md`, `docs/README.md`, `docs/spring-ai/README.md`, `docs/guide.md`, and `docs/spring-ai/SPRING_AI_STAGE_6.md`.
- **Rewritten [`docs/spring-ai/SPRING_AI_STAGE_6.md`](docs/spring-ai/SPRING_AI_STAGE_6.md)** — UI + CLI workflows, port allocation table, dashboard endpoint bullets per demo, curl equivalents under each Demo, Demo 05 resource catalog (9 URI templates), MCP JSON-RPC server-endpoint table, concrete-vs-template explainer, dual-config section for 03, spy-gateway exclusion note.
- **Rewritten Stage 6 section in [`docs/guide.md`](docs/guide.md)** — dashboard as primary entry point, `./workshop.sh mcp` commands as canonical, module table with new dir names + ports, walkthrough link.
- **"New in Stage 6 UI" intro boxes** on every `mcp/*/README.md` pointing at the dashboard page.
- **Minor wording appends** on `README.md`, `docs/README.md`, `docs/spring-ai/README.md`, `docs/spring-ai/SPRING_AI_INTRODUCTION.md`, and `CLAUDE.md` to reflect the UI integration + directory renames.
- **New "Stage 6 / MCP" troubleshooting section** in `docs/troubleshooting.md` (port in use, workshop.sh mcp start timeouts, dashboard offline, 01 jar missing, 04 one-shot latch).

### Design doc & plan

Captured on branch for auditability (gitignored from main per workshop convention):

- `docs/superpowers/specs/2026-04-17-stage6-mcp-enhancement-design.md`
- `docs/superpowers/plans/2026-04-17-stage6-mcp-enhancement.md`

---

---

## [2.2.2] — 2026-04-15: Dashboard Light/Dark Mode Toggle

Adds a persistent theme toggle to the workshop dashboard topbar, available on every page (overview + all stage detail pages).

### Dashboard Theme Toggle

- **Sun/moon button in the topbar** — switches between the existing dark theme (default) and a new light theme on click
- **Persistent preference** — `localStorage` key `theme` stores the user's choice; survives refreshes and browser restarts with no expiration
- **Flash prevention** — `theme.js` runs as an IIFE in `<head>` before first paint, reading `localStorage` synchronously so the correct theme renders from the initial page load
- **Light theme uses darker green tones** (`#3d7a1c`) for WCAG AA contrast against the light background
- **Highlight.js colors** adapted to a GitHub-style palette when light mode is active
- **Smooth 200ms transitions** between themes, disabled on initial page load to avoid a flash animation
- **Mermaid diagrams re-render** with matching theme on toggle — existing diagrams have their original markdown restored and re-processed
- **Bootstrap `data-bs-theme` kept in sync** so form controls, close buttons, and other Bootstrap components follow the theme automatically

### CSS Architecture Refactor

- **50+ CSS custom properties** defined in `:root`, with `[data-theme="light"]` overrides — covers all UI colors, JSON syntax highlighting, highlight.js tokens, code blocks, modals, gateway panel, and component-specific elements
- **All hardcoded color literals removed** from stylesheets and templates in favour of theme-aware `var(--spring-*)` references
- **Bootstrap `text-light` utility replaced** with `var(--spring-text)` inline styles on endpoint paths, stage card titles, doc modal title, similarity labels, and card values
- **`btn-close-white` removed** from gateway modal — Bootstrap's `data-bs-theme` now handles close-button contrast

### Files

- New: `components/config-dashboard/src/main/resources/static/js/theme.js` (toggle logic, persistence, Mermaid re-init)
- Modified: `workshop.css` (+200 lines: variables + light overrides + toggle button + transitions)
- Modified: `layout.html` (theme.js in `<head>`, toggle button in topbar, dynamic Mermaid theme init)
- Modified: `response.js` (theme-aware error bubbles and dynamic HTML)
- Modified: `stage/detail.html`, `dashboard/index.html` (theme-aware text + modal close styling)

---

## [2.2.1] — 2026-04-11: Anthropic Provider Fix & Gateway Spy UI Improvements

Bug fixes for the Anthropic provider and visual improvements to the gateway spy panel in the workshop dashboard.

### Bug Fixes

- **Anthropic provider startup failure** — Added `spring-boot-restclient` dependency. In Spring Boot 4, `RestClient.Builder` auto-configuration moved to a separate module; the Anthropic SDK (OkHttp-based) doesn't pull it in transitively unlike OpenAI/Ollama starters
- **Gateway routing all requests to Ollama** — In Spring Cloud Gateway MVC 5.x, `.before(uri())` filters apply to all routes in a builder group, not just the preceding route. The last `uri()` (Ollama) always won. Replaced with a single route using dynamic URI selection based on request path
- **Anthropic provider name showing "unknown"** — Added `spring.application.name: provider-anthropic` to application config

### Dashboard Improvements

- **Gateway spy JSON syntax highlighting** — Color-coded JSON output: green keys, blue strings, yellow numbers, red booleans, gray nulls
- **Nested JSON expansion** — Tool call arguments and tool results (escaped JSON strings) are expanded into formatted objects
- **Newline handling** — `\n` sequences unescaped for readability, trailing newlines stripped
- **Always-visible scrollbar** — Gateway request/response panels show vertical scrollbar when content overflows
- **Fullscreen expand modal** — New expand icon (⤢) on the gateway panel opens a side-by-side request/response modal for easier inspection of large payloads
- **Provider and profiles in stage topbar** — Stage detail pages now show the provider name and active profiles (matching the dashboard overview)

---

## [2.2.0] — 2026-04-10: Enhanced Observability & Offline Workshop Tools

End-to-end distributed tracing with per-span log correlation in Grafana, and offline workshop tooling for slow-WiFi venues.

### Observability

- **Endpoint payload logging** — `ControllerTracingAspect` logs request params/body and truncated response at INFO level, auto-correlated to OTel traces in Loki
- **Distributed tracing through spy gateway** — Added `spring-boot-starter-opentelemetry`, `observation` profile, and `logback-spring.xml` to gateway module. Full end-to-end traces (backend → gateway → AI provider) visible in Grafana Tempo with `spy,observation` profiles
- **Per-span log correlation** — New `SpanLoggingObservationHandler` emits INFO logs for Spring AI chat observations (`AI CALL START/END`) and HTTP client observations (`HTTP CLIENT REQUEST/RESPONSE`), ensuring every span has associated logs
- **Structured gateway audit logs** — Refactored `OpenAiAuditor` to emit separate `GATEWAY REQUEST` / `GATEWAY RESPONSE` log lines with truncated payloads, replacing one large concatenated string
- **Grafana trace-to-logs fix** — Changed datasource query from `|=` (line content filter) to `| trace_id =` (structured metadata filter) for correct OTLP log correlation
- **Application name in console logs** — Added `<springProperty>` for app name in logback patterns (`[gateway]`, `[ollama]`) so interleaved logs are distinguishable
- **Gateway OTel logback installer** — Added `OpenTelemetryLogbackInstaller` so gateway logs reach Loki via OTLP export

### Workshop Tools

- **Docker image export/import** — New `models/containers.sh` script: export/import/pull/list for all 4 workshop Docker images (pgvector, pgAdmin, Grafana LGTM, MailDev). Produces `containers.tar.gz` for USB stick distribution
- **Gateway auto-starts with observation** — `workshop.sh` passes `observation` profile to gateway when selected
- **Prerequisites update** — Added prominent "Important — Before Joining the Workshop" section with all Docker and Ollama pull commands
- **Offline setup docs** — USB stick import instructions with links to `containers.sh` and `ollama.sh`

---

## [2.1.0] — 2026-04-04: Workshop Helpers, Dashboard UI & Docs

Workshop improvements for presenters and self-learners: interactive dashboard, OpenAPI docs, unified CLI script, and restructured documentation.

### New Modules

#### `components/config-openapi` — Swagger UI & OpenAPI Specs
- SpringDoc OpenAPI 3.0.1 with `@OpenAPIDefinition` for 5 workshop stage tags
- OpenAPI annotations on all 21 controllers (37 endpoints documented)
- Server-side path sorting for correct endpoint ordering
- Always active — Swagger UI at `/swagger-ui.html`, OpenAPI spec at `/v3/api-docs`

#### `components/config-dashboard` — Workshop Dashboard UI
- Thymeleaf + Bootstrap 5.3.3 (dark theme) + htmx 2.0.4
- Activated with `ui` profile, served at `/dashboard`
- Spring-branded dark theme with collapsible sidebar
- All frontend assets vendored locally for offline workshop use
- Auto-discovers endpoints from OpenAPI spec at runtime
- Specialized response views: plain text, JSON viewer, streaming text, similarity bar charts, chat bubbles, step accordion
- Parameter inputs with placeholder examples, dropdown selects for enum params
- Copy-to-clipboard curl command with live parameter updates
- Chat-style conversation view for Stage 4 (patterns) endpoints
- Dashboard excluded from tracing via `ObservationPredicate`

### `workshop.sh` — Unified CLI Script
- Replaces `check-deps.sh` and `download-deps.sh`
- CLI mode: `check`, `setup`, `start`, `stop`, `reset`, `status`, `logs`, `infra`
- Interactive TUI menu with provider selection and profile toggling
- Infrastructure submenu: start PostgreSQL, LGTM, or both
- Abort option (`a`) in all submenus
- Database reset: drops and recreates public schema in all 3 databases
- Port 8080 check before starting (lsof on macOS, ss on Linux)
- Process group kill on stop (Maven + forked Java)
- Runs `mvn install` before `spring-boot:run` for module dependency resolution
- Health check via `/v3/api-docs` fallback (not all providers have actuator)
- Compatible with macOS bash 3.2 and Linux bash 4+

### Documentation Restructure
- `docs/README.md` — landing page with audience routing
- `docs/quickstart.md` — 5-minute setup for live workshop attendees
- `docs/guide.md` — full 8-stage walkthrough for self-learners
- `docs/providers.md` — provider comparison, credentials, model requirements
- `docs/troubleshooting.md` — common issues and solutions
- Fixed all example docs (`examples_chat.md`, `examples_embedding.md`, `examples_image.md`, `examples_audio.md`) with correct URLs
- Root `README.md` updated with screenshots, docs links, and workshop.sh instructions

### Observability Fixes
- Suppressed generic `http.server.requests` spans — `@TracedEndpoint` spans are now root spans
- Trace root span names show HTTP request path (e.g., `GET /rag/02/query`)
- Fixed Grafana LGTM datasource provisioning for trace-to-log correlation
- Enabled OTel logging export with explicit `enabled: true`

### MCP Fixes (Stage 6)
- Added `protocol: STREAMABLE` and `streamable-http.mcp-endpoint: /mcp` to MCP 02, 04, 05
- Without this config, the Streamable HTTP transport didn't register the `/mcp` endpoint
- All 4 MCP servers tested and passing

### Agentic Fixes (Stage 7)
- Fixed model-directed-loop agent reinvocation loop: first call sent user message but discarded result, then loop sent empty prompts. Now sends user message in first iteration
- Both agents tested with OpenAI and passing

### Endpoint Fixes
- `/embed/01/dimension` — shows provider, model name, and dimensions
- `/embed/01/text` — added `text` request parameter
- `/embed/03/big` — added `size` parameter (small/large dropdown)
- `/chat/02/*/threeJokes` — makes 3 separate API calls (not 1)
- `/chat/05/dayOfWeek` — system prompt forces tool call; TimeTools returns day-of-week
- `/chat/07/explain` — fixed OpenAPI example to match actual image
- `/cot/bio/oneshot` — removed unused `message` parameter
- Fixed Ollama Flyway migration dimension: 1024 → 768
- Removed duplicate `spring-boot-starter-actuator` from provider-openai
- Hidden `/login` endpoint from OpenAPI via `springdoc.paths-to-exclude`

---

## [2.0.0] — 2026-04-03: Spring Boot 4 + Spring AI 2 Migration

Major version upgrade of the entire workshop from Spring Boot 3.5.6 / Spring AI 1.0.3 to Spring Boot 4.0.5 / Spring AI 2.0.0-M4.

### Tech Stack

| Component | Before | After |
|-----------|--------|-------|
| Spring Boot | 3.5.6 | **4.0.5** |
| Spring AI | 1.0.3 | **2.0.0-M4** |
| Spring Framework | 6.2.x | **7.x** |
| Java | 21 | **25** |
| Maven | 3.9.9 | **3.9.14** |
| Spring Cloud | 2025.0.0 | **2025.1.1** |
| Spring Cloud Azure | 6.0.0 | **7.1.0** |
| Spring Shell | 3.4.1 | **4.0.1** |
| Jackson | 2.x | **3.0** (databind: `tools.jackson`, annotations: `com.fasterxml.jackson`) |
| Flyway | 10.x | **11.11** |
| Micrometer | 1.14.x | **1.16** |
| PostgreSQL (Docker) | pgvector:pg17 | **pgvector:pg18** |
| pgAdmin (Docker) | 9.8.0 | **latest** |
| Observability | 6 containers (Prometheus/Grafana/Tempo/Loki/OTel/MailDev) | **grafana/otel-lgtm:latest** + MailDev |

### Ollama Models

| Model | Before | After | Reason |
|-------|--------|-------|--------|
| Chat | llama3.2 (3B) | **qwen3 (8B)** | Reliable structured output + tool calling; Mistral 7B had weak tool-call compliance |
| Embedding | mxbai-embed-large (512 ctx) | **nomic-embed-text (8192 ctx)** | Bike documents exceed 512 token context |
| Multimodal | llava (manual switch) | **llava (auto-switch)** | Controller detects Ollama and switches model |

### New Features

#### Distributed Tracing Module (`components/patterns/04-distributed-tracing/`)
- Custom AOP annotations: `@TracedEndpoint`, `@TracedService`, `@TracedRepository`
- Three ordered aspects creating proper span hierarchy (Controller → Service → Repository)
- OpenTelemetry Tracer, ObservedAspect, Logback OTel appender config
- All 24 REST controllers annotated with `@TracedEndpoint`

#### LGTM Observability Stack
- Single `grafana/otel-lgtm:latest` container replaces 6 separate containers
- Includes: Grafana, Loki (logs), Tempo (traces), Mimir (metrics), OTel Collector
- Custom dashboard provisioning with default dashboard suppression
- Traces, metrics, and logs all flow via OTLP

#### Spring AI Workshop Overview Dashboard
- New Grafana dashboard replacing the old Prometheus Stats dashboard
- Panels: Application, Uptime, Start Time, Live Threads, CPU Usage, Heap Memory
- HTTP Request Rate and Response Time (p95) by URI
- JVM Heap Memory, CPU & System Load, HikariCP Connections
- GC Pause Duration, Log Events per minute (ERROR/WARN/INFO)

### Breaking Changes Resolved

#### Spring Boot 4
- **Jackson 3**: `com.fasterxml.jackson.databind` → `tools.jackson.databind` (annotations unchanged)
- **Flyway**: `flyway-core` → `spring-boot-starter-flyway`
- **Spring Cloud Gateway 5**: `spring-cloud-starter-gateway-mvc` → `spring-cloud-starter-gateway-server-webmvc`, `HandlerFunctions.http(url)` → `http()` + `uri()` filter
- **Spring Shell 4**: `@CommandScan` → `@EnableCommand`, `@Command(command=)` → `@Command(name=)`, `PromptProvider` removed
- **AutoConfiguration packages moved**: `o.s.b.autoconfigure.jdbc` → `o.s.b.jdbc.autoconfigure`, `o.s.b.autoconfigure.flyway` → `o.s.b.flyway.autoconfigure`
- **Micrometer 1.16 metric names**: `_seconds` → `_milliseconds` throughout
- **`spring-boot-starter-aop` removed**: explicit `spring-aop` + `aspectjweaver` dependencies needed
- **`@MockBean` → `@MockitoBean`**, `@SpyBean` → `@MockitoSpyBean`

#### Spring AI 2.0
- **MCP SSE → Streamable HTTP**: `spring-ai-starter-mcp-server-webflux` → `webmvc`, `WebFluxSseClientTransport` → `HttpClientStreamableHttpTransport`
- **MCP annotations**: `com.logaritex.mcp.annotation` → `org.springframework.ai.mcp.annotation`
- **`SpringAiMcpAnnotationProvider`** → `SyncMcpAnnotationProviders` (different API: `resourceSpecifications()`, `promptSpecifications()`, `completeSpecifications()`)
- **`McpSyncClientCustomizer`** → `McpClientCustomizer<B>` (generic)
- **Google provider**: `spring-ai-starter-model-vertex-ai-gemini` → `spring-ai-starter-model-google-genai`
- **Deprecated `functions` config**: `spring.ai.openai.chat.options.functions` removed — tools registered inline via `.tools()`
- **`StdioClientTransport`** now requires `McpJsonMapper` parameter
- **MCP bean name conflicts**: Spring AI 2.0 auto-config creates `resourceSpecs`/`promptSpecs`/`completionSpecs` beans — manual beans need unique names
- **`LocalDate`/`LocalTime` in tool params**: Jackson 3 can't deserialize — use `String` instead
- **`returnDirect=true` + `entity()`**: incompatible in Spring AI 2.0 — use `.content()` with manual JSON parsing

### Fixes Applied

#### Embedding & Vector Store
- Switched default embedding model to `nomic-embed-text` (8192 token context vs 512, **768 dimensions**)
- pgvector dimension changed from 1024 → **768** in `application.yaml`
- Added `TokenTextSplitter` chunking before `vectorStore.add()` in vector store and RAG controllers
- Result: 25 bike documents → 72 chunks, all load and query successfully
- **Note:** If upgrading from an existing database with 1024-dimension vectors, drop the `vector_store` table before starting (Spring AI recreates it automatically)

#### Chat Endpoints
- Switched default chat model to `qwen3` (8B) — reliable structured output (POJO/Map), tool calling, and reasoning
- Fixed `chat_04/map` prompt to explicitly request JSON object structure
- Fixed `chat_05/search`: `LocalDate` → `String` params, `.content()` + manual JSON parsing for `returnDirect`
- Fixed `chat_07/explain`: auto-switches to `llava` model when running on Ollama

#### Observability
- Created `logback-spring.xml` with OTel Logback appender for both provider apps
- Fixed `management.tracing.export.enabled` → `management.tracing.enabled` (correct property for Spring Boot 4)
- Added `logging.level.com.example.tracing: DEBUG` for tracing aspect logs
- All Grafana dashboards updated for Micrometer 1.16 metric names (`_seconds` → `_milliseconds`)
- Fixed PromQL syntax: `metric/1000{labels}` → `metric{labels}/1000`
- Replaced Tomcat thread metrics with JVM thread metrics (Tomcat metrics not available via OTLP)
- Added `or vector(0)` fallback for error count panels (show 0 instead of N/A)

#### MCP
- Migrated 3 MCP modules from SSE to Streamable HTTP transport
- Updated MCP annotations from external `com.logaritex.mcp` to Spring AI built-in
- Fixed `StdioClientTransport` constructor for MCP SDK 1.1

#### Infrastructure
- Created sample `Profile.pdf` for chain-of-thought and self-reflection demos
- Replaced `check-deps.sh` and `download-deps.sh` with unified `workshop.sh` (see [2.1.0] below)
- Cleaned up 11 obsolete observability config files

### Test Results

| Provider | Pass | Total | Notes |
|----------|:----:|:-----:|-------|
| **Ollama** (qwen3 + nomic-embed-text) | 44 | 44 | All chat + embedding + vector + patterns + agents |
| **OpenAI** (gpt-4o-mini) | 44 | 44 | All endpoints |
| **Anthropic** (Claude, direct API) | 14 | 14 | All chat endpoints (no embeddings — Anthropic doesn't offer them) |
| **AWS Bedrock** (Amazon Nova Lite, eu-central-1) | 8 | 8 | Chat + stuff-the-prompt (no embeddings — Converse starter is chat-only) |
| **Google** (Gemini 2.5 Flash) | 13 | 13 | All chat endpoints (dependency conflicts fixed, API key mode) |
| **Azure OpenAI** (gpt-4.1-mini, East US) | 8 | 8 | All chat endpoints pass (Standard SKU with 1 TPM) |

### Documentation

- `migration/flow.md` — Complete workshop demo flow with all 8 stages and endpoints
- `migration/prerequisites.md` — Local setup requirements (JDK 25, Docker, Ollama, API keys)
- `migration/upgrade.md` — Step-by-step migration plan (9 phases)
- `migration/upgrade_status.md` — All findings and deviations from plan
- `migration/test_plan.md` — 10-phase test plan
- `migration/test_results.md` — Detailed test results per endpoint
- `migration/model_mapping.md` — Provider compatibility matrix (52 endpoints)
- `CLAUDE.md` — Project context for AI assistants
- All 14 README files updated for new tech stack
- New `Spring AI Workshop Overview` Grafana dashboard replacing Prometheus Stats
