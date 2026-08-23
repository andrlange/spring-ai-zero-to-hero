# Spring AI 2.0.0 GA → 2.0.1 + Spring Boot 4.1.0 → 4.1.1 Upgrade Plan

> **For agentic workers:** REQUIRED SUB-SKILL: `superpowers:subagent-driven-development` or `superpowers:executing-plans`. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bump the workshop to the **first GA patch stack** — Spring AI **2.0.1**, Spring Boot **4.1.1**, Spring Cloud **2025.1.2** (unchanged) — and ship workshop **`v2.4.1`**.

**Architecture:** Two version-property bumps in the root `pom.xml` drive the whole stack (`spring-boot-starter-parent` and `<spring-ai.version>`). The interesting wrinkle: **2.0.1 is a patch release that nevertheless ships eleven documented breaking changes.** Most of them are *behavioural defaults around tool calling* rather than API removals, and after a line-by-line audit **none of them touch this codebase** — verified by grep and by a full green reactor build. The work is therefore a mechanical version sweep across docs, HTML, version files and the changelog, plus the audit recorded in Part 1.

**Tech Stack (target):** Spring Boot 4.1.1 · Spring Framework 7.0.9 · Spring AI 2.0.1 · Spring Cloud 2025.1.2 (Gateway Server WebMVC 5.0.2) · MCP Java SDK 2.0.0 · Java 25 · Maven 3.9.14

**Reference release notes:**
- Spring AI 2.0.1 (2026-08-21) — <https://github.com/spring-projects/spring-ai/releases/tag/v2.0.1>
- Spring AI upgrade notes, "Upgrading to 2.0.1" — <https://docs.spring.io/spring-ai/reference/upgrade-notes.html#upgrading-to-2-0-1>
- Spring Boot 4.1.1 (2026-08-20) — <https://github.com/spring-projects/spring-boot/releases/tag/v4.1.1>

**Companion docs:** [`SPRING_AI_RC1_TO_GA_UPGRADE_PLAN.md`](SPRING_AI_RC1_TO_GA_UPGRADE_PLAN.md), [`SPRING_VERSION_DOC_GAP.md`](SPRING_VERSION_DOC_GAP.md), [`SPRING_AI_M8_TO_RC1_UPGRADE_PLAN.md`](SPRING_AI_M8_TO_RC1_UPGRADE_PLAN.md), [`SPRING_AI_M7_TO_M8_UPGRADE_PLAN.md`](SPRING_AI_M7_TO_M8_UPGRADE_PLAN.md), [`SPRING_AI_M6_TO_M7_UPGRADE_PLAN.md`](SPRING_AI_M6_TO_M7_UPGRADE_PLAN.md), [`SPRING_AI_M5_TO_M6_MIGRATION.md`](SPRING_AI_M5_TO_M6_MIGRATION.md), [`SPRING_AI_M4_TO_M5_MIGRATION.md`](SPRING_AI_M4_TO_M5_MIGRATION.md).

---

## Part 0 — Version comparison at a glance

| Component | Current (v2.4.0) | Target (v2.4.1) | Kind of change |
|---|---|---|---|
| **Spring Boot** | 4.1.0 | **4.1.1** | Patch |
| **Spring Framework** (transitive) | 7.0.8 | **7.0.9** | Patch (via Boot) |
| **Spring Security** (transitive via Boot) | 7.1.0 | **7.1.1** | Patch (via Boot) |
| **Micrometer** (transitive via Boot) | 1.17.0 | **1.17.1** | Patch (via Boot) |
| **Spring AI** | 2.0.0 GA | **2.0.1** | Patch — *with* breaking changes |
| **Spring Cloud** | 2025.1.2 | 2025.1.2 (unchanged) | — |
| **Spring Cloud Gateway Server WebMVC** (transitive) | 5.0.2 | 5.0.2 (unchanged) | — |
| **MCP Java SDK** (transitive via Spring AI BOM) | 2.0.0 | 2.0.0 (unchanged) | — |
| **Spring Cloud Azure** | 7.1.0 | 7.1.0 (unchanged) | — |
| **Java** | 25 | 25 (unchanged) | — |
| **Workshop version** | 2.4.0 | **2.4.1** | — |

---

## Part 1 — Breaking-change audit

### Spring AI 2.0.0 → 2.0.1 — all 11 documented breaking changes

The 2.0.1 upgrade notes list eleven breaking changes. Verdict per item, against this codebase:

| # | Breaking change | Verdict here | Evidence |
|---|---|---|---|
| 1 | Redis chat-memory autoconfig renamed `…-chat-memory-redis` → `…-chat-memory-repository-redis`; properties `spring.ai.chat.memory.redis.*` → `…repository.redis.*` | **No impact** | No Redis chat memory anywhere — Stage 4 uses in-memory `MessageWindowChatMemory` (`grep -r 'chat-memory-redis\|chat.memory.redis'` → empty) |
| 2 | Mistral AI moderation `Categories.dangerousAndCriminalContent` split into `dangerous` + `criminal`; new `jailbreaking` | **No impact** | Mistral is not one of the 6 workshop providers; only prose mentions in docs |
| 3 | Mistral chat-model constants retired (`MAGISTRAL_*`, `DEVSTRAL`, `OPEN_MISTRAL_NEMO`); `MISTRAL_LARGE` now aliases `mistral-medium-3-5` (#6772) | **No impact** | Same as above |
| 4 | `@McpTool` exception dispatch now mirrors `@Tool` — checked exceptions and `Error` bubble up instead of becoming error `CallToolResult` (#6534) | **No impact** | Zero `@McpTool` usages — all 5 `mcp/` servers expose tools via `@Tool` + `MethodToolCallbackProvider` |
| 5 | `DefaultToolCallingManager` enforces tool-call limits: **40 per tool, 150 total** (#6726, #6742) | **No impact, worth knowing** | Stage 7 agent loops are bounded well below 150 iterations; Stage 1/6 tool demos issue single-digit calls. Overridable via `spring.ai.tools.limits.*` |
| 6 | `ToolCallingAdvisor` accumulates token usage across the whole tool loop instead of reporting only the last call (#6424) | **No code impact — visible in Stage 8** | No test or endpoint asserts exact token counts (`grep getUsage/totalTokens` → empty). Grafana/Tempo token metrics will read **higher** for tool-calling requests; that is the corrected number, not a regression |
| 7 | `OpenAiChatModel` no longer defaults tool schemas to `strict(true)` (#6755, #6540) | **No impact, an improvement** | Nothing sets `.strict(...)`. Tools with optional parameters are no longer rejected by OpenAI |
| 8 | `OpenAiAudioSpeechModel.stream()` emits real audio chunks instead of one buffered element (#6733) | **No impact** | The audio component uses `OpenAiAudioTranscriptionModel` (speech-to-text) and non-streaming TTS; no `stream()` + `blockFirst()` pattern |
| 9 | `TranscriptionModel` now extends `StreamingTranscriptionModel` | **No impact** | We consume the framework's `OpenAiAudioTranscriptionModel`; no custom `TranscriptionModel` implementation exists |
| 10 | `Media.Builder.data(Object)` removed in favour of typed `data(byte[]/String/URI/URL/Resource)` overloads (#6481) | **No impact** | One call site — `mcp/05-mcp-capabilities/.../PromptProvider.java:91` passes a `String` literal, which binds to the `data(String)` overload |
| 11 | Fallback tool resolution (bean-registered tools not attached to the request) **disabled by default** (#6751) | **No impact** | Every workshop tool is attached explicitly: `.tools(...)` in `chat_05/ToolController` (5 sites), `.toolCallbacks(provider)` in `mcp/03`, `mcp/04` (2 sites) and `McpInspectorController`. The RC1 migration off `toolNames()` already removed all name-based resolution |

**Net: zero application-code changes.**

### 2.0.1 fixes that *do* land on workshop stages (behavioural, no code change)

| Issue | What it fixes | Stage it touches |
|---|---|---|
| #6438 | `PgVectorStore` validates its table schema after initialization | Stage 3 / RAG under the `pgvector` profile — a mismatched `vector_store` table now fails loudly at startup instead of misbehaving later |
| #6567 | `OllamaChatModel` prompt options now inherit the configured model | `provider-ollama` — per-request options no longer silently drop the configured model id |
| #6180 | Microsoft Foundry URL path mode fixed for proxy hosts | `provider-azure`, and the `spy` gateway profile |
| #6553 | Azure OpenAI auth failure behind a TLS-inspecting proxy | `provider-azure` |
| #6605 | `AnthropicChatOptions.timeout(Duration)` no longer ignored outside model construction | `provider-anthropic` |
| #6533 | MCP stdio connections without args | Stage 6 — `01-mcp-stdio-server` launched from the dashboard |
| #6716 | MCP HTTP client request-customizer beans are applied | Stage 6 — `02-mcp-http-server` / `03-mcp-client` |
| #5783 | Streamable HTTP WebClient transport accepts SSE frames without an `event` field | Stage 6 |
| #6475 | Null parent for tool-call observations in blocking mode | Stage 8 — tool-call spans now nest correctly in the Tempo trace tree |
| #6381 | Streaming tool-call deltas merged by index in `OpenAiChatModel` | Stage 1 `/chat/05/*`, Stage 7 agents (streaming) |
| #6498 / #6487 | Shared mutable state in `ChatOptions.Builder.clone()` / `AnthropicChatOptions.Builder.clone()` | Stage 7 — `AgentOptionsConfig` exposes a shared `ChatOptions.Builder` bean; this removes a real cross-request aliasing hazard |
| #6452 | `TokenTextSplitter` builder argument validation | Stage 2/3 embedding + RAG splitters |
| #6423 / #6645 | `MarkdownCodeBlockCleaner` edge cases (single-line fences, short text) | Structured output across stages |

### Spring Boot 4.1.0 → 4.1.1 audit

Maintenance release. The only breaking change in the notes is **Gradle-plugin-only** — the Spring Boot Gradle plugin no longer auto-configures gRPC when the Protobuf plugin is applied. This project builds with **Maven**, so it does not apply.

Transitive bumps that reach us: Spring Framework **7.0.9**, Spring Security **7.1.1**, Micrometer **1.17.1**, Tomcat **11.0.24**, Hibernate **7.4.5.Final**, Jackson **2.21.5** / **3.1.5**. Notable fixes: JSON encoding corruption in structured logging, Micrometer registries pinning the application context, virtual-thread support for Redis message listener containers.

### Spring Cloud — why it stays at 2025.1.2

`start.spring.io`'s Initializr metadata declares the 2025.1.2 BOM range as **Spring Boot `>=4.0.0` and `<4.2.0-M1`**, so Boot 4.1.1 is inside the supported window with no train bump needed. This is the same "the Initializr metadata is the only machine-readable compatibility source" situation documented as **Gap 1** in [`SPRING_VERSION_DOC_GAP.md`](SPRING_VERSION_DOC_GAP.md) — except that this time the range is stated explicitly in the metadata rather than merely implied by co-selectable dropdowns. The Supported-Versions wiki remains stale.

---

## Part 2 — Impact summary (TL;DR)

- **Application code:** no changes. 
- **Build:** two properties in the root `pom.xml`.
- **Docs/labels:** `Spring Boot 4.1.0` → `4.1.1`, `Spring AI 2.0.0` → `2.0.1`, workshop `2.4.0` → `2.4.1`.
- **Behavioural deltas to expect at runtime:** higher (correct) token totals on tool-calling traces in Stage 8; tool-call limits now enforced; OpenAI tool schemas no longer strict by default.
- **Risk:** low. The one thing worth an actual runtime check is the new **`PgVectorStore` schema validation** (#6438) against an existing workshop database, and Stage 8's trace/token panels.

---

## Part 3 — File-by-file impact map

### Build (code/config)

| File | Change |
|---|---|
| `pom.xml` | `spring-boot-starter-parent` `4.1.0` → `4.1.1`; `<spring-ai.version>` `2.0.0` → `2.0.1` |

`<spring-cloud.version>`, `<spring-cloud-azure.version>`, `<spring-shell.version>`, `<spotless.version>` and `<java.version>` are unchanged.

### Workshop-version touchpoints (`2.4.0 → 2.4.1`)

| File | Change |
|---|---|
| `VERSION` | `2.4.1` |
| `components/config-dashboard/src/main/resources/workshop.properties` | `workshop.version=2.4.1` |
| `components/config-dashboard/src/main/resources/templates/fragments/layout.html` | footer placeholder `v2.4.1` + `Spring AI 2.0.1` |

### Label sweep `Spring AI 2.0.0 → 2.0.1`, `Spring Boot 4.1.0 → 4.1.1`

`README.md`, `WHATS_NEW_STAGE_06_MCP.md`, `agentic-system/readme.md`, the 6 `applications/provider-*/readme.md`, `docs/README.md`, `docs/guide.md`, `docs/spring-ai/SPRING_AI_INTRODUCTION.md`, `support/prerequisites.md`, `support/howto_windows11.md`, `support/os-compatibility-analysis.md`, `workshop.sh` (4 banners + the Java-version warning), `prepare.sh` (2 defaults + 2 `replace_once` literals), `components/config-openapi/.../OpenApiConfig.java` (`version` + tech-stack string), `docker/observability-stack/grafana/dashboards/spring-ai-workshop-overview.json`, `components/config-dashboard/src/main/resources/static/slides.html` **and** `slides.html.original` (the `prepare.sh` baseline — both must move together, one occurrence each).

### Pixel-art history timeline — `spring-ai-history.html`

Two new entries (42 → **44**): `spring-boot-4-1-1` (ecosystem, 2026-08-20) and `v2.0.1` (spring-ai, 2026-08-21, titled *"Where we are today"*). The previous `v2.0.0` entry is retitled *"Spring AI 2.0 goes GA"*. `WORLD_END` recomputed as `720 + 44 × 360 + 800 = 17360`, entry-count comment updated, and the end-of-world panel line changed to *"Spring AI 2.0.1 is the foundation"*.

### Files NOT touched (historical — leave as-is)

`migration/`, `SPRING_AI_M4_TO_M5_MIGRATION.md`, `SPRING_AI_M5_TO_M6_MIGRATION.md`, `SPRING_AI_M6_TO_M7_UPGRADE_PLAN.md`, `SPRING_AI_M7_TO_M8_UPGRADE_PLAN.md`, `SPRING_AI_M8_TO_RC1_UPGRADE_PLAN.md`, `SPRING_AI_RC1_TO_GA_UPGRADE_PLAN.md`, prior `CHANGELOG.md` entries, and the in-source `// Spring AI 2.0.0-Mx:` / `// Spring AI 2.0.0-RC1:` attribution comments — these record *when* a change happened.

---

## Part 4 — Provider checklist

| Provider | Build | Notes |
|---|---|---|
| `provider-openai` | ✅ | Strict-mode default flipped to `false` (#6755); streaming tool-call delta merge fixed (#6381) |
| `provider-ollama` | ✅ | Prompt options now inherit the configured model (#6567) |
| `provider-azure` | ✅ | Foundry proxy path + TLS-inspecting-proxy auth fixes (#6180, #6553) |
| `provider-anthropic` | ✅ | `timeout(Duration)` honoured outside model construction (#6605) |
| `provider-google` | ✅ | `ToolChoice` support added for Google GenAI (#6531); thinking-level validation fixed (#6339) |
| `provider-aws` | ✅ | AWS default region resolution now follows the SDK rules (#823, #5108) — the confusing WARN is gone |
| `gateway` | ✅ | Spring Cloud unchanged at 2025.1.2; Gateway Server WebMVC 5.0.2 on Boot 4.1.1 |

---

## Part 5 — Implementation tasks

### Task 1: Version bumps (root pom) — **applied, verified**
- [x] `spring-boot-starter-parent` `4.1.0` → `4.1.1`
- [x] `<spring-ai.version>` `2.0.0` → `2.0.1`
- [x] Confirm resolved classpath: `spring-boot:4.1.1`, `spring-core:7.0.9`, `spring-ai-openai:2.0.1`, `io.modelcontextprotocol.sdk:mcp:2.0.0`, `micrometer-core:1.17.1`

### Task 2: Workshop version 2.4.0 → 2.4.1 — **applied**
- [x] `VERSION`, `workshop.properties`, `layout.html`, `prepare.sh` defaults

### Task 3: Label sweep + OpenApiConfig — **applied**
- [x] All files listed in Part 3, each replacement count-asserted before writing

### Task 4: README rewrite — **applied**
- [x] Header stack line + upgrade banner rewritten for 2.0.1 / 4.1.1

### Task 5: Pixel-art history timeline — **applied**
- [x] Two new entries, `WORLD_END` = 17360, panel line updated

### Task 6: CHANGELOG `[2.4.1]` — **applied**

### Task 7: This plan doc — **applied**

### Task 8: Push + PR + tag + release + merge
- [ ] `git push -u origin chore/boot-4.1.1-ai-2.0.1-bump`
- [ ] `gh pr create --title "chore(deps): Spring Boot 4.1.1 + Spring AI 2.0.1"`
- [ ] `git tag v2.4.1 <branch-tip>` && `git push origin v2.4.1`
- [ ] `gh release create v2.4.1 --latest`
- [ ] `gh pr merge --merge --delete-branch`

---

## Part 6 — Verification

```bash
# Confirm no 2.0.1-removed APIs in our source (expect empty)
grep -rn 'Media\.builder()\.data(' --include='*.java' .        # only the String overload in mcp/05
grep -rn '@McpTool' --include='*.java' .                       # empty
grep -rn 'chat-memory-redis\|chat\.memory\.redis' .            # empty

# Confirm no stray pre-2.0.1 labels remain (expect only historical plan/changelog/migration docs
# plus the history-timeline data and the in-source attribution comments)
grep -rn 'Spring AI 2\.0\.0 \|Spring Boot 4\.1\.0' --exclude-dir=target --exclude-dir=.git .

# Full reactor build + install (install matters: spring-boot:run resolves component
# jars from ~/.m2, so `verify` alone leaves stale jars — see the bump-gotchas note)
./mvnw clean install
```

**Result (2026-08-23):** `./mvnw clean install` — **42 modules, BUILD SUCCESS, all tests pass (0 failures / 0 errors / 0 skipped)**. No new compiler warnings: the `TokenTextSplitter()`, `JsonParser` and `toolCallbacks(ToolCallbackProvider…)` deprecation warnings were A/B-checked against a 2.0.0 build and appear identically in both — they predate this bump.

### Runtime smoke matrix (post-merge)

Reactor-green ≠ runtime-works. Smoke each of these against a live provider:

| Stage | What to exercise | Why this bump |
|---|---|---|
| 1 | `/chat/05/weather`, `/chat/05/pack`, `/chat/05/restaurant` on OpenAI | Strict-mode default flipped to `false`; streaming delta merge changed |
| 2/3 | `/rag/01/load` then `/rag/01/query?topic=…` under `pgvector` | **#6438** — `PgVectorStore` now validates the table schema at startup |
| 4 | `/mem/02/*` | Chat-memory conversation-id scoping doc/behaviour touched |
| 6 | Dashboard Stage 6 → all 5 MCP demos (stdio + HTTP + dynamic) | #6533 stdio-without-args, #6716 HTTP customizers, #5783 SSE frames |
| 7 | Both agents (inner monologue, model-directed loop) | New tool-call limits (40/150); shared-builder `clone()` fix |
| 8 | Grafana/Tempo trace tree + token panels | #6475 span parenting, #6424 accumulated usage → **expect higher token totals** |

---

## Part 7 — Recommended follow-ups (NOT done in this bump)

- **Retire the Stage 7 typed-`toolChoice` workaround.** `AgentOptionsConfig` (both agents) still passes `ChatCompletionToolChoiceOption.ofAuto(Auto.REQUIRED)` because RC1's `OpenAiChatModel` rejected the plain `"required"` string. Upstream **spring-projects/spring-ai#6332** (reported from this repo) was fixed by commit `c8ea5a0` and closed **2026-06-09** — i.e. *before* the 2.0.0 GA cut on 2026-06-12, so the plain string has worked since GA and certainly works in 2.0.1. Reverting is a behaviour-affecting change to a live agent path, so it belongs in its own commit with a Stage 7 runtime smoke, not folded into a version bump.
- **Adopt the new tool-call limit properties explicitly.** `spring.ai.tools.limits.max-calls-per-tool` / `max-total-tool-calls` would make Stage 7's runaway-loop protection visible and teachable instead of an invisible framework default.
- **Tool Search advisor (#5909, modules now in the BOM via #6464).** Still a candidate for future stage content.
