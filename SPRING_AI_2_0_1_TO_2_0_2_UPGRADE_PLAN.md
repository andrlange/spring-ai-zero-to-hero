# Spring AI 2.0.1 → 2.0.2 + Spring Boot 4.1.1 → 4.1.2 + Spring Cloud 2025.1.2 → 2025.1.4 Upgrade Plan

> **For agentic workers:** REQUIRED SUB-SKILL: `superpowers:subagent-driven-development` or `superpowers:executing-plans`. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bump the workshop to the **second GA patch stack** — Spring AI **2.0.2**, Spring Boot **4.1.2**, Spring Cloud **2025.1.4** — and ship workshop **`v2.4.2`**.

**Architecture:** Three version properties in the root `pom.xml` drive the whole stack (`spring-boot-starter-parent`, `<spring-ai.version>`, `<spring-cloud.version>`). Unlike 2.0.1, **2.0.2 is a real fix release**: its upgrade notes list only two items, neither of which needs a code change here. The one surprise is **not in the release notes at all** — `spring-ai-mcp` 2.0.2 moves the **MCP Java SDK 2.0.0 → 2.1.0**, a *minor* bump of the SDK behind a *patch* bump of Spring AI (new **Gap 7** in [`SPRING_VERSION_DOC_GAP.md`](SPRING_VERSION_DOC_GAP.md)). All five Stage 6 demos were runtime-checked against it. Net: zero application-code changes; a mechanical version sweep across docs, HTML, version files and the changelog.

**Tech Stack (target):** Spring Boot 4.1.2 · Spring Framework 7.0.10 · Spring AI 2.0.2 · Spring Cloud 2025.1.4 (Gateway Server WebMVC 5.0.4) · MCP Java SDK 2.1.0 · Java 25 · Maven 3.9.14

**Reference release notes:**
- Spring AI 2.0.2 (2026-10-23) — <https://github.com/spring-projects/spring-ai/releases/tag/v2.0.2>
- Spring AI upgrade notes, "Upgrading to 2.0.2" — <https://docs.spring.io/spring-ai/reference/upgrade-notes.html#upgrading-to-2-0-2>
- Spring Boot 4.1.2 (2026-10-22) — <https://github.com/spring-projects/spring-boot/releases/tag/v4.1.2>
- Spring Cloud 2025.1.3 (2026-08-20, 17 CVE fixes) — <https://github.com/spring-cloud/spring-cloud-release/releases/tag/v2025.1.3>
- Spring Cloud 2025.1.4 (2026-10-23) — <https://github.com/spring-cloud/spring-cloud-release/releases/tag/v2025.1.4>
- MCP Java SDK 2.1.0 (2026-10-16) — <https://github.com/modelcontextprotocol/java-sdk/releases/tag/v2.1.0>

**Companion docs:** [`SPRING_AI_GA_TO_2_0_1_UPGRADE_PLAN.md`](SPRING_AI_GA_TO_2_0_1_UPGRADE_PLAN.md), [`SPRING_VERSION_DOC_GAP.md`](SPRING_VERSION_DOC_GAP.md), [`SPRING_AI_RC1_TO_GA_UPGRADE_PLAN.md`](SPRING_AI_RC1_TO_GA_UPGRADE_PLAN.md), [`SPRING_AI_M8_TO_RC1_UPGRADE_PLAN.md`](SPRING_AI_M8_TO_RC1_UPGRADE_PLAN.md), [`SPRING_AI_M7_TO_M8_UPGRADE_PLAN.md`](SPRING_AI_M7_TO_M8_UPGRADE_PLAN.md), [`SPRING_AI_M6_TO_M7_UPGRADE_PLAN.md`](SPRING_AI_M6_TO_M7_UPGRADE_PLAN.md), [`SPRING_AI_M5_TO_M6_MIGRATION.md`](SPRING_AI_M5_TO_M6_MIGRATION.md), [`SPRING_AI_M4_TO_M5_MIGRATION.md`](SPRING_AI_M4_TO_M5_MIGRATION.md).

---

## Part 0 — Version comparison at a glance

All "Target" values are taken from `./mvnw dependency:list` on the bumped build, not from release notes.

| Component | Current (v2.4.1) | Target (v2.4.2) | Kind of change |
|---|---|---|---|
| **Spring Boot** | 4.1.1 | **4.1.2** | Patch |
| **Spring Framework** (transitive) | 7.0.9 | **7.0.10** | Patch (via Boot) |
| **Spring Security** (transitive via Boot) | 7.1.1 | **7.1.2** | Patch (via Boot) |
| **Micrometer** (transitive via Boot) | 1.17.1 | **1.17.2** | Patch (via Boot) |
| **Tomcat** (transitive via Boot) | 11.0.24 | **11.0.27** | Patch (via Boot) |
| **Jackson** (transitive via Boot) | 2.21.5 / 3.1.5 | **2.21.7 / 3.1.7** | Patch (via Boot) |
| **Spring AI** | 2.0.1 | **2.0.2** | Patch — no breaking changes for us |
| **MCP Java SDK** (transitive via `spring-ai-mcp`) | 2.0.0 | **2.1.0** | **Minor** — not in the Spring AI release notes |
| **OpenAI Java SDK** (transitive) | — | **4.80.0** | Via Spring AI (#7170) |
| **Spring Cloud** | 2025.1.2 | **2025.1.4** | Patch train (skips over 2025.1.3) |
| **Spring Cloud Gateway Server WebMVC** (transitive) | 5.0.2 | **5.0.4** | Patch |
| **Spring Cloud Azure** | 7.1.0 | 7.1.0 (unchanged) | — |
| **Spring Shell** | 4.0.1 | 4.0.1 (unchanged — 4.0.2 available, see Part 7) | — |
| **Java** | 25 | 25 (unchanged) | — |
| **Workshop version** | 2.4.1 | **2.4.2** | — |

---

## Part 1 — Breaking-change audit

### Spring AI 2.0.1 → 2.0.2 — the upgrade-notes page

Per the standing rule from the 2.0.1 bump (Gap 6), `upgrade-notes.html#upgrading-to-2-0-2` was read in full. It lists **two** items:

| # | Item | Verdict here | Evidence |
|---|---|---|---|
| 1 | OpenAI text-to-speech + transcription, ElevenLabs TTS and the Stability AI image model now emit observations (`gen_ai.client.operation`, `gen_ai.operation.name` = `text_to_speech` / `transcription` / `image`) when an `ObservationRegistry` is present (#7141) | **No code impact — visible in Stage 8** | `components/apis/audio/.../TranscribeController.java` uses `OpenAiAudioTranscriptionModel`. Under the `observation` profile its calls now show up as new spans and metric series. Content logging stays off by default |
| 2 | Neo4j chat-memory repository: stale indexes replaced with correct property indexes (#6967); old indexes can be dropped manually | **No impact** | No Neo4j anywhere in the repo (`grep -ri neo4j` over poms, Java and YAML → empty) |

**Net: zero application-code changes.**

### MCP Java SDK 2.0.0 → 2.1.0 (transitive, undocumented by Spring AI)

`spring-ai-mcp-2.0.1.pom` declares `io.modelcontextprotocol.sdk:mcp:2.0.0`; `spring-ai-mcp-2.0.2.pom` declares **`2.1.0`**. The Spring AI release notes' *Dependency Upgrades* section lists only OpenAI SDK and AWS SDK bumps. What 2.1.0 changes, and whether it touches us:

| SDK 2.1.0 change | Verdict here | Evidence |
|---|---|---|
| `HttpClient`-based client transports reworked to be `Publisher`-based; request customizers compose on the builders (#1079, #1165) | **No impact** | Only `HttpClientStreamableHttpTransport.builder(url).build()` is used (`McpClientRegistry`, plus two test clients) — no customizers. Compiles and runs unchanged |
| `2024-11-05` protocol removed from Streamable HTTP (#1126) | **No impact** | Client and servers both come from the same SDK and negotiate a newer protocol. Runtime-checked: demos 02, 04, 05 |
| Non-`application/json` POSTs rejected (#1164) | **No impact** | All traffic goes through the SDK client |
| `ServerHttpHeaderValidator` replaces `ServerTransportSecurityValidator` (#982) | **No impact** | Not referenced (`grep` → empty) |
| Tool list filtering (#1108), Streamable HTTP session sweeping + keep-alive (#1130), `extensions` on capabilities (#1064) | New features, unused | Candidates for future Stage 6 content |
| Thread-safe STDIO `sendMessage` (#935), re-subscribable `listXyz()` monos (#1175), NPE fixes (#1178, #1179) | Fixes | Stage 6 stdio demo 01 and the inspector's list calls |

### 2.0.2 fixes that *do* land on workshop stages (behavioural, no code change)

| Issue | What it fixes | Stage / module it touches |
|---|---|---|
| #6837 | Configured OpenAI timeout honoured again | `provider-openai`, `provider-azure` |
| #6865 | `additionalProperties: false` backfilled in OpenAI **strict** tool schemas | No-op — nothing sets `strict(...)` (2.0.1 turned the default off) |
| #7066 | Ollama responses without a `message` handled | `provider-ollama` |
| #6984 | Disabled reasoning honoured in tool history | Thinking models during tool calls (e.g. qwen3 on Ollama) |
| #7001 / #6982 | `AnthropicChatModel` returns the final answer first; thinking text included in streaming chunks | `provider-anthropic` |
| #6963 | Invalid JSON in Bedrock tool-call arguments | `provider-aws` — Stage 1 `/chat/05/*` |
| #5468 | Tool-call extraction for mixed-content Gemini responses | `provider-google` — Stage 1 `/chat/05/*` |
| #6797 | `TextReader` closes its resource stream | Stage 2 `embed_04/DocumentController` (Shakespeare `TextReader`) |
| #7100 | `StructuredOutputValidationAdvisor` repeating tool calls | No-op — advisor not used |
| #6803 | `JsoupDocumentReader` relative links | No-op — reader not used |
| #7164 / #7170 / #7169 | Anthropic SDK 2.72.0, OpenAI SDK 4.80.0, AWS SDK 2.55.14 | The three matching providers |

### Spring Boot 4.1.1 → 4.1.2 audit

Maintenance release, **no breaking changes**. One "new feature": `JavaVersion.TWENTY_SEVEN` (Java 27 recognised — irrelevant on our Java 25 baseline). Fixes that could be visible here: `WritableJson.toByteArray()` supplementary-character corruption (#51464, structured logging), Tomcat graceful-shutdown callback (#52197), `OriginTrackedPropertiesLoader` dropping properties whose name starts with `#`/`!` (#52265). Transitive bumps: see Part 0, plus Hibernate 7.4.13, Netty 4.2.19, Reactor 2025.0.8, Spring Data 2026.0.2.

### Spring Cloud — 2025.1.2 → 2025.1.4

`https://start.spring.io/actuator/info` declares the **2025.1.4** BOM range as Spring Boot **`>=4.0.0` and `<4.2.0-M1`**, so Boot 4.1.2 is in range. Two trains are crossed:

- **2025.1.3 (2026-08-20)** — security train, **17 CVE fixes across 5 modules**, among them **Spring Cloud Gateway 5.0.3** (CVE-2026-47879, SSRF and native file access with gRPC). The `gateway` module (`spy` profile) uses Gateway Server WebMVC, so this one applies. **The previous bump (2026-08-23) kept 2025.1.2 although 2025.1.3 was already three days old.** It checked only *"is 2025.1.2 still compatible?"* and never *"is it still the latest?"* — see Gap 8.
- **2025.1.4 (2026-10-23)** — routine train: Gateway 5.0.4, Commons 5.0.4, Function 5.0.5, Config 5.0.6. No breaking changes listed.

---

## Part 2 — Impact summary (TL;DR)

- **Application code:** no changes.
- **Build:** three properties in the root `pom.xml`.
- **Docs/labels:** `Spring Boot 4.1.1` → `4.1.2`, `Spring AI 2.0.1` → `2.0.2`, workshop `2.4.1` → `2.4.2`; README + intro banners rewritten.
- **Behavioural deltas to expect at runtime:** new Stage 8 spans/metrics for OpenAI transcription (#7141); OpenAI timeout config takes effect again (#6837); MCP SDK 2.1.0 transports on Stage 6.
- **Risk:** low. The only change with real reach is the transitive MCP SDK minor; it was runtime-checked (Part 6).

---

## Part 3 — File-by-file impact map

### Build (code/config)

| File | Change |
|---|---|
| `pom.xml` | `spring-boot-starter-parent` `4.1.1` → `4.1.2`; `<spring-ai.version>` `2.0.1` → `2.0.2`; `<spring-cloud.version>` `2025.1.2` → `2025.1.4` |

`<spring-cloud-azure.version>`, `<spring-shell.version>`, `<spotless.version>` and `<java.version>` are unchanged.

### Workshop-version touchpoints (`2.4.1 → 2.4.2`)

| File | Change |
|---|---|
| `VERSION` | `2.4.2` |
| `components/config-dashboard/src/main/resources/workshop.properties` | `workshop.version=2.4.2` |
| `components/config-dashboard/src/main/resources/templates/fragments/layout.html` | footer placeholder `v2.4.2` + `Spring AI 2.0.2` |

### Label sweep `Spring AI 2.0.1 → 2.0.2`, `Spring Boot 4.1.1 → 4.1.2`

Same 24-file set as the 2.0.1 bump, run as one count-asserting script (every `(old, new, expected_count)` asserted before writing; 41 insertions / 40 deletions in total, 1–2 lines per file): `README.md`, `WHATS_NEW_STAGE_06_MCP.md`, `agentic-system/readme.md`, the 6 `applications/provider-*/readme.md`, `docs/README.md`, `docs/guide.md`, `docs/spring-ai/SPRING_AI_INTRODUCTION.md`, `support/prerequisites.md`, `support/howto_windows11.md`, `support/os-compatibility-analysis.md`, `workshop.sh` (4 banners + the Java-version warning), `prepare.sh` (2 defaults + 2 `replace_once` literals), `components/config-openapi/.../OpenApiConfig.java` (`version` + tech-stack string), `docker/observability-stack/grafana/dashboards/spring-ai-workshop-overview.json`, `components/config-dashboard/src/main/resources/static/slides.html` **and** `slides.html.original`.

Prose rewritten by hand: the README upgrade banner (line 11) and a new *(current)* bullet in the `SPRING_AI_INTRODUCTION.md` release-progression block (the 2.0.1 bullet keeps its historical numbers).

### Pixel-art history timeline — `spring-ai-history.html`

Two new entries (44 → **46**): `spring-boot-4-1-2` (ecosystem, 2026-10-22) and `v2.0.2` (spring-ai, 2026-10-23, titled *"Where we are today"*). The previous `v2.0.1` entry is retitled *"First GA patch"*. `WORLD_END` recomputed as `720 + 46 × 360 + 800 = 18080`, entry-count comment updated (13 2.0 line + 3 Boot 4.1), end-of-world panel line changed to *"Spring AI 2.0.2 is the foundation"*. Inline script passes `node --check`.

### Files NOT touched (historical — leave as-is)

`migration/`, all prior `SPRING_AI_*` plan/migration docs, prior `CHANGELOG.md` entries, the 2.0.1 bullet in `SPRING_AI_INTRODUCTION.md`, and the in-source `// Spring AI 2.0.0-Mx:` / `// Spring AI 2.0.0-RC1:` attribution comments.

---

## Part 4 — Provider checklist

| Provider | Build | Runtime | Notes |
|---|---|---|---|
| `provider-ollama` | ✅ | ✅ smoked (Part 6) | Message-less responses handled (#7066); disabled reasoning honoured in tool history (#6984) |
| `provider-openai` | ✅ | not smoked | Timeout honoured again (#6837); openai-java 4.80.0; transcription now observed (#7141) |
| `provider-azure` | ✅ | not smoked | Shares the OpenAI module — #6837 applies |
| `provider-anthropic` | ✅ | not smoked | Anthropic SDK 2.72.0; final-answer ordering + streaming thinking (#7001, #6982) |
| `provider-google` | ✅ | not smoked | Mixed-content tool-call extraction (#5468) |
| `provider-aws` | ✅ | not smoked | AWS SDK 2.55.14; Bedrock tool-call JSON (#6963) |
| `gateway` | ✅ | not smoked | Gateway Server WebMVC 5.0.2 → 5.0.4 (incl. the 5.0.3 CVE fix) |

---

## Part 5 — Implementation tasks

### Task 1: Version bumps (root pom) — **applied, verified**
- [x] `spring-boot-starter-parent` `4.1.1` → `4.1.2`
- [x] `<spring-ai.version>` `2.0.1` → `2.0.2`
- [x] `<spring-cloud.version>` `2025.1.2` → `2025.1.4`
- [x] Confirm resolved classpath: `spring-boot:4.1.2`, `spring-core:7.0.10`, `spring-ai-openai:2.0.2`, `io.modelcontextprotocol.sdk:mcp:2.1.0`, `micrometer-core:1.17.2`, `spring-cloud-gateway-server-webmvc:5.0.4`

### Task 2: Workshop version 2.4.1 → 2.4.2 — **applied**
- [x] `VERSION`, `workshop.properties`, `layout.html`, `prepare.sh` defaults

### Task 3: Label sweep + OpenApiConfig — **applied**
- [x] All files listed in Part 3, each replacement count-asserted before writing

### Task 4: README + intro banner rewrite — **applied**

### Task 5: Pixel-art history timeline — **applied**
- [x] Two new entries, `WORLD_END` = 18080, panel line updated

### Task 6: CHANGELOG `[2.4.2]` + `SPRING_VERSION_DOC_GAP.md` (Gaps 7 + 8) — **applied**

### Task 7: This plan doc — **applied**

### Task 8: Push + PR + tag + release + merge
- [ ] `git push -u origin sb412_spai202`
- [ ] `gh pr create --title "chore(deps): Spring Boot 4.1.2 + Spring AI 2.0.2 + Spring Cloud 2025.1.4"`
- [ ] `git tag v2.4.2 <branch-tip>` && `git push origin v2.4.2`
- [ ] `gh release create v2.4.2 --latest`
- [ ] `gh pr merge --merge --delete-branch`

---

## Part 6 — Verification

```bash
# Upgrade-notes items (expect empty)
grep -ril neo4j --include=pom.xml --include='*.java' --include='*.yaml' --include='*.yml' .

# MCP SDK 2.1.0 surface we use (expect only HttpClientStreamableHttpTransport.builder(url).build())
grep -rn 'ServerTransportSecurityValidator\|HttpClientStreamableHttpTransport\|McpSyncHttpClientRequestCustomizer' --include='*.java' .

# Where the MCP SDK version comes from
./mvnw dependency:tree -pl components/config-dashboard -Dincludes=io.modelcontextprotocol.sdk

# No stray pre-2.0.2 labels (expect only historical docs, the timeline data, and the
# deliberate "2.0.1 → 2.0.2" / "2025.1.2 → 2025.1.4" in the README banner)
grep -rn 'Spring AI 2\.0\.1\|Spring Boot 4\.1\.1\|2025\.1\.2' --exclude-dir=target --exclude-dir=.git .

# Full reactor build + install (install matters — spring-boot:run resolves component jars from ~/.m2)
./mvnw -U clean install
```

**Result (2026-10-27):** `./mvnw -U clean install` — **42 modules, BUILD SUCCESS, 114 tests, 0 failures / 0 errors / 0 skipped**, 37 s. Compiler warnings: the same set as in 2.0.1 (`JsonParser` ×4 sites in the Stage 7 agents, `toolCallbacks(ToolCallbackProvider…)` ×4 sites in `mcp/03`, `mcp/04` and `McpInspectorController`). **No new deprecations.** The `TokenTextSplitter()` warning is gone since PR #11.

### Runtime smoke (2026-10-27, `provider-ollama` + `ui` profile, host Ollama, qwen3 / nomic-embed-text)

Started from the freshly installed jars: `02-mcp-http-server` (:8081), `04-dynamic-tool-calling/server` (:8082), `05-mcp-capabilities` (:8083), `provider-ollama --spring.profiles.active=ui` (:8080). No `ERROR` lines in the app log.

| Stage | What was exercised | Result |
|---|---|---|
| 1 | `/chat/05/time`, `/chat/05/weather`, `/chat/05/pack` (tool calling) | ✅ tools invoked, coherent answers |
| 2 | `/embed/01/text`, `/embed/01/dimension` | ✅ 768-dim `nomic-embed-text` vectors |
| 3 | `/rag/01/load` → `/rag/01/query?topic=a bike for kids` (in-memory `SimpleVectorStore`) | ✅ 72 chunks / 25 docs loaded; grounded answer |
| 4 | `/mem/02/hello` → `/mem/02/name` | ✅ name remembered across turns |
| 6 | `/dashboard/mcp/{01,02,04,05}/status` + `/tools` | ✅ all `up`; tools listed over **stdio (01)** and **Streamable HTTP (02, 04, 05)** on MCP SDK 2.1.0 |
| 6 | `05` resources / `resources/read?uri=user-location://bob` / prompts / `prompts/get` | ✅ `Tokyo`; prompt rendered |
| 6 | `04/update-tools` → `04/tools` | ✅ 1 → 4 tools (runtime registration) |
| 6 | `POST /dashboard/mcp/03/run?mode=local` (ChatClient + tools from 01 + 02) | ✅ tool called, answer in ~13 s |

The stdio subprocess logs `ERROR in ch.qos.logback.classic.PatternLayout("") - Empty or null pattern` on stderr. That is intentional and predates this bump: `01-mcp-stdio-server` blanks `logging.pattern.console` to keep stdout clean for JSON-RPC.

**Not smoked (needs infra/credentials not available in this session):** Stage 3 under `pgvector` (port 15432 was taken by an unrelated container), Stage 7 agents (OpenAI), Stage 8 Grafana/Tempo (LGTM not running — check the new #7141 transcription spans there), the `spy` gateway, and the five cloud providers.

---

## Part 7 — Recommended follow-ups (NOT done in this bump)

- **Carried over: retire the Stage 7 typed-`toolChoice` workaround.** spring-ai#6332 has been fixed since before 2.0.0 GA; revert `ChatCompletionToolChoiceOption.ofAuto(Auto.REQUIRED)` to the plain `"required"` string in its own commit with a Stage 7 OpenAI smoke.
- **Carried over: adopt `spring.ai.tools.limits.*` explicitly** in Stage 7.
- **Spring Shell 4.0.1 → 4.0.2** — available, and in range for Boot 4.1.x per start.spring.io. Out of scope for this bump (only the Stage 7 CLI modules use it); needs a Stage 7 shell smoke.
- **Replace the deprecated `JsonParser` / `toolCallbacks(ToolCallbackProvider…)` call sites** — both are marked for removal, so they will break on a future minor.
- **MCP SDK 2.1.0 tool-list filtering (#1108)** — a natural fit for Stage 6 next to the dynamic-tool demo.
- **`CLAUDE.md` tech-stack table** still says Spring Boot 4.0.6 / Spring AI 2.0.0-M4 — never part of the label sweep. Either add it to the sweep set or point it at `VERSION`/`pom.xml`.
