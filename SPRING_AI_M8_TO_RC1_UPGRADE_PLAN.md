# Spring AI 2.0.0-M8 → 2.0.0-RC1 Upgrade Plan

> **For agentic workers:** REQUIRED SUB-SKILL: `superpowers:subagent-driven-development` or `superpowers:executing-plans`. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bump the workshop from Spring AI 2.0.0-M8 → 2.0.0-RC1, absorb the **breaking** tool-calling/API cleanups that land in the first release candidate, and ship `v2.3.8`.

**Architecture:** A single property bump (`<spring-ai.version>`) drives the BOM upgrade — but unlike the fix-only M8 release, **RC1 is a breaking release** that removes deprecated tool-calling APIs and moves/renames modules. Three real source/build changes are required (none were needed for M8):

1. `ChatClient.prompt().toolNames("…")` is **removed** (#6301 / #6154 — `SpringBeanToolCallbackResolver` and `toolNames()` gone). Our `chat_05/ToolController` uses it twice; both must switch to passing the `FunctionToolCallback` bean explicitly via `.tools(...)`.
2. `ImageOptionsBuilder.N()` is **renamed** to `.n()` (#6285). Our `image_01/ImageController` calls `.N(1)`.
3. The vector-store advisor artifact was **renamed** `spring-ai-advisors-vector-store` → `spring-ai-vector-store-advisor` (#6309 — "Move advisors to their proper modules"). Our RAG pattern module depends on the old coordinate. **Confirmed against the published RC1 BOM on Maven Central.**

Everything else is the usual workshop mechanical sweep (version `2.3.7 → 2.3.8`, non-historical label sweep `2.0.0-M8 → 2.0.0-RC1`, history-page entry, CHANGELOG) plus a documentation correction: the `ToolSpec` consumer API we documented in M7 was **removed** in RC1 (#6292), so its Stage 1 doc entry must be retired, and `ToolCallAdvisor` is **renamed** to `ToolCallingAdvisor` (#6303, backward-compat shim retained) so the docs/history prose should use the new name.

**Tech Stack:** Spring Boot 4.0.6 · Spring AI 2.0.0-RC1 · Java 25 · Maven 3.9.14 · MCP Java SDK 2.0.0-RC1 (upgraded from M3, #6287 — transitive via the BOM)

**Reference release notes:** <https://github.com/spring-projects/spring-ai/releases/tag/v2.0.0-RC1>
**Announcement:** <https://spring.io/blog/2026/06/06/spring-ai-2-0-0-RC1-available-now>

**Companion docs:** [`SPRING_AI_M7_TO_M8_UPGRADE_PLAN.md`](SPRING_AI_M7_TO_M8_UPGRADE_PLAN.md), [`SPRING_AI_M6_TO_M7_UPGRADE_PLAN.md`](SPRING_AI_M6_TO_M7_UPGRADE_PLAN.md), [`SPRING_AI_M5_TO_M6_MIGRATION.md`](SPRING_AI_M5_TO_M6_MIGRATION.md), [`SPRING_AI_M4_TO_M5_MIGRATION.md`](SPRING_AI_M4_TO_M5_MIGRATION.md), [`migration/upgrade.md`](migration/upgrade.md).

---

## Part 1 — Impact summary (TL;DR)

| Risk | RC1 change | Affects us? | Action |
|---|---|---|---|
| 🟥 **BREAKING** | **#6301 / #6154 — Remove `toolNames()` API + `SpringBeanToolCallbackResolver`** | **Yes — compile break.** `chat_05/ToolController` calls `.toolNames("weatherFunction")` at lines 107 and 139. The `weatherFunction` callback is a `FunctionToolCallback` bean (`FunctionConfiguration.weatherFunctionCallback`) that was resolved by name at runtime. RC1 removes name-based resolution. | **Inject the `FunctionToolCallback` bean into `ToolController` and pass it via `.tools(weatherTool)`** in both endpoints. |
| 🟥 **BREAKING** | **#6285 — Rename `N()` → `n()` in options builders** | **Yes — compile break.** `image_01/ImageController` calls `ImageOptionsBuilder.builder().N(1)`. | **Change `.N(1)` → `.n(1)`.** |
| 🟥 **BREAKING** | **#6309 — Move advisors to their proper modules (artifact rename)** | **Yes — build break.** `components/patterns/02-retrieval-augmented-generation/pom.xml` depends on `org.springframework.ai:spring-ai-advisors-vector-store`, which no longer exists in RC1. The RC1 BOM publishes `spring-ai-vector-store-advisor` instead (verified on Maven Central). | **Rename the dependency `artifactId`** `spring-ai-advisors-vector-store` → `spring-ai-vector-store-advisor`. |
| 🟨 **DOCS** | **#6292 — Remove `ToolSpec` consumer API from `ChatClient`** | **No code impact** (we never used `o.s.ai.tool.ToolSpec` in code — confirmed), **but docs are now wrong.** `SPRING_AI_STAGE_1.md` line 55 documents `o.s.ai.tool.ToolSpec` as an "M7+" API attendees may encounter; RC1 removed it. (Note: the `SyncToolSpecification` references in `mcp/04` + Stage 6 docs are MCP SDK types, **not** the removed Spring AI `ToolSpec` — they stay.) | **Remove the `ToolSpec` row** from the Stage 1 API table (and any prose introduced by `f856306`). |
| 🟨 **DOCS** | **#6303 — Rename `ToolCallAdvisor` → `ToolCallingAdvisor`** (backward-compat deprecated shim retained) | **No code impact** (we never instantiate it — it is the auto-configured default), **but prose names the old class.** Mentioned in `SPRING_AI_INTRODUCTION.md`, `SPRING_AI_STAGE_8.md`, `spring-ai-history.html`. | **Update prose to `ToolCallingAdvisor`** where it names the current class; leave historical timeline bullets describing past milestones as-is. |
| 🟩 **VERIFY** | **#6252–#6272 — Remove built-in tool-execution loop from every `ChatModel`** | **No expected impact.** All workshop tool calling flows through `ChatClient` (which executes tools via the auto-configured `ToolCallingAdvisor`), not raw `ChatModel.call()` with tools. Stage 1 `chat_05/*`, Stage 7 agentic `@Tool` agents, and the MCP client all use `ChatClient`. | **Verify at runtime** — the `chat_05/*` endpoints and Stage 7 agents must still auto-execute tools. (No code change anticipated.) |
| 🟩 **VERIFY** | **#6287 — Upgrade MCP SDK 2.0.0-M3 → 2.0.0-RC1** (transitive via BOM) | **Possible compile impact** in MCP modules that touch SDK types directly: `mcp/04` (`SyncToolSpecification`, `McpToolUtils.toSyncToolSpecifications`, `McpSyncServer.addTool`) and `mcp/05` (`ClientSse`, server features). | **Verify these compile + run** after the bump; fix any SDK API drift surgically. |
| 🟩 **INFO** | **#6312 — Turn-boundary snapping in `MessageWindowChatMemory` eviction** | **Behavioural improvement, automatic.** Stage 4 chat-memory demos benefit (no split turns on eviction); no API change. | None — optionally mention in CHANGELOG. |
| 🟩 **INFO** | **#5909 — Tool Search Advisor for on-demand tool discovery** (`spring-ai-tool-search-*` modules) | **New optional feature, not adopted.** | None (candidate future stage content). |
| 🟩 **INFO** | **#6165 — `EntityParamSpec` for per-call structured output** | **New optional API, not adopted.** | None. |
| 🟩 **INFO** | **#6204 — Deprecate + rename `ChatClientCustomizer` → `ChatClientBuilderCustomizer`** | **No-op.** We don't use `ChatClientCustomizer` anywhere (grep clean). | None. |
| 🟩 **INFO** | **#6289 — Remove `internalToolExecutionEnabled`** | **No-op.** No usages in the codebase (grep clean). | None. |
| 🟩 **INFO** | **#6290 / #6149 / #6210 — Remove MiniMax, retire Pixtral Large, drop deprecated Mistral models** | **No-op.** Workshop uses Ollama, OpenAI, Anthropic, Azure, Google, AWS Bedrock — none of the removed models. | None. |
| 🟩 **INFO** | **#6280 — Replace SLF4J with `org.apache.commons.logging.LogFactory`** | **No-op.** Internal to Spring AI; our logging config is unaffected. | None. |
| 🟩 **INFO** | **#6194 — Add DeepSeek V4 chat model constants; #5963 DeepSeek fix** | **No-op.** DeepSeek not used. | None. |

**Workshop side effects (mechanical, same pattern as previous bumps):**

- Workshop version `2.3.7` → `2.3.8` in `VERSION`, `workshop.properties`, `prepare.sh`, `layout.html` placeholder.
- Non-historical version-label sweep `2.0.0-M8` → `2.0.0-RC1` (README, workshop.sh banners, docs/, all provider/component readmes, dashboard slides, Grafana dashboard, OpenAPI metadata).
- New `[2.3.8]` entry in `CHANGELOG.md`.
- New `v2.0.0-RC1` (2026-06-06) entry on the pixel-art Spring AI History timeline; M8 retitled from "Where we are today" to a neutral retrospective ("MCP autoconfig packaging fixes").

**Reactor build target:** `./mvnw clean verify` → **BUILD SUCCESS** across all 42 modules after the three code/build fixes land.

**Runtime verify target:** boot `provider-ollama` and hit `/chat/05/weather` + `/chat/05/time` (the `toolNames` → `.tools()` migration) and `/image/01/make` (the `.n()` rename), plus `/rag/01/query` (the artifact rename).

---

## Part 2 — File-by-file impact map

### Code/build changes (NEW for RC1 — none of these existed in the M8 bump)

| File | What changes | Why |
|---|---|---|
| `pom.xml` (root, line 20) | `<spring-ai.version>2.0.0-M8</spring-ai.version>` → `2.0.0-RC1` | The single BOM bump. |
| `components/apis/chat/src/main/java/com/example/chat_05/ToolController.java` | Inject `FunctionToolCallback weatherFunctionCallback` via the constructor; replace `.toolNames("weatherFunction")` (lines 107 + 139) with `.tools(this.weatherTool)` | #6301 / #6154 removed name-based tool resolution. |
| `components/apis/image/src/main/java/com/example/image_01/ImageController.java` (line 31) | `.N(1)` → `.n(1)` | #6285 renamed the builder method. |
| `components/patterns/02-retrieval-augmented-generation/pom.xml` (line 39) | `<artifactId>spring-ai-advisors-vector-store</artifactId>` → `<artifactId>spring-ai-vector-store-advisor</artifactId>` | #6309 moved/renamed the advisor module. |

### Verify-only (no change expected, confirm at build/runtime)

| File / area | What to confirm |
|---|---|
| `mcp/04-dynamic-tool-calling/server/.../ServerApplication.java`, `mcp/05-mcp-capabilities/.../*` | MCP SDK M3 → RC1: `SyncToolSpecification`, `McpToolUtils.toSyncToolSpecifications(...)`, `McpSyncServer.addTool(...)`, `ClientSse` still compile + run. |
| Stage 1 `chat_05/*`, Stage 7 agentic `@Tool` agents, `mcp/03-mcp-client` | Tool calls still auto-execute through `ChatClient` after the `ChatModel` internal-loop removal (#6252–#6272). |

### Documentation corrections (content, not just labels)

| File | What changes | Why |
|---|---|---|
| `docs/spring-ai/SPRING_AI_STAGE_1.md` (line ~55) | Remove the `ToolSpec` *(M7+)* row from the API table (and any `f856306` prose introducing it) | #6292 removed `o.s.ai.tool.ToolSpec`. |
| `docs/spring-ai/SPRING_AI_INTRODUCTION.md` (lines ~10, ~212) | `ToolCallAdvisor` → `ToolCallingAdvisor` where it names the current default class; add an RC1 callout to the milestone history line | #6303 renamed the class. |
| `docs/spring-ai/SPRING_AI_STAGE_8.md` (line ~117) | `ToolCallAdvisor` → `ToolCallingAdvisor` in the span-tree callout (and `2.0.0-M7` → `2.0.0-RC1` where it labels "current") | #6303 rename + label sweep. |

### Workshop-version touchpoints

| File | What changes |
|---|---|
| `VERSION` | `2.3.7` → `2.3.8` |
| `components/config-dashboard/src/main/resources/workshop.properties` | `workshop.version=2.3.7` → `2.3.8` |
| `prepare.sh` (lines 71 + 115) | `2.0.0-M8` → `2.0.0-RC1` defaults |
| `components/config-dashboard/src/main/resources/templates/fragments/layout.html` (lines 106 + 107) | Workshop `v2.3.7` → `v2.3.8`, Spring AI `2.0.0-M8` → `2.0.0-RC1` |

### Non-historical version-label sweep (~21 files)

All forward-looking workshop-version banners get bumped `2.0.0-M8` → `2.0.0-RC1`:

- `README.md` (line 7 banner + line 11 "Recently upgraded" callout — rewrite to M8→RC1 highlighting the three breaking changes + the doc corrections)
- `agentic-system/readme.md`
- `applications/provider-{ollama,openai,anthropic,azure,aws,google}/readme.md` (banner only — leave any historical "Migrated for M6/M5" lines)
- `WHATS_NEW_STAGE_06_MCP.md` (line ~218 "APIs used" — bump MCP SDK M3 → RC1 too)
- `docs/{README,guide}.md`
- `docs/spring-ai/SPRING_AI_INTRODUCTION.md` (forward-looking version mentions)
- `support/{howto_windows11,os-compatibility-analysis,prerequisites}.md`
- `components/config-openapi/src/main/java/com/example/openapi/OpenApiConfig.java` (`version=` + tech-stack desc)
- `components/config-dashboard/src/main/resources/static/slides.html` (banner pill)
- `components/config-dashboard/src/main/resources/static/slides.html.original` (prepare.sh baseline)
- `docker/observability-stack/grafana/dashboards/spring-ai-workshop-overview.json` (description banner)
- `workshop.sh` (4 banner occurrences)

> Use surgical edits — do **NOT** blanket-replace every `M8` string. Confirm the final state with the grep in Part 5.

### Pixel-art history timeline

- `components/config-dashboard/src/main/resources/static/spring-ai-history.html`:
  - Retitle the M8 entry (`id:'v2.0.0-M8'`, line ~558) from `title:'Where we are today'` to a neutral retrospective, e.g. `'MCP autoconfig packaging fixes'`.
  - Append a new `v2.0.0-RC1` entry (`date:'2026-06-06'`, `badge:'RC1'`) with `title:'Where we are today'` and bullets covering RC1's headline changes (tool-calling API cleanup: `toolNames()`/`ToolSpec` removed; `ToolCallAdvisor` → `ToolCallingAdvisor`; advisor modules moved; MCP SDK RC1; Tool Search Advisor added).
  - Bump `WORLD_END` `15200 → 15560` and the inline comment `38 entries → 39 entries` (`720 + 39 × 360 + 800 = 15560`).
  - Bump line ~772 `'<li>Spring AI 2.0.0-M8 is the foundation</li>'` → `'…RC1 is the foundation'`.

### Files NOT touched (historical)

- `migration/*.md` — historical record of the prior Boot 3 → 4 / Spring AI 1 → 2.0-M4 migration.
- `SPRING_AI_M4_TO_M5_MIGRATION.md`, `SPRING_AI_M5_TO_M6_MIGRATION.md`, `SPRING_AI_M6_TO_M7_UPGRADE_PLAN.md`, `SPRING_AI_M7_TO_M8_UPGRADE_PLAN.md` — historical milestone records.
- `CHANGELOG.md` entries for `[2.3.7]` and earlier — historical.
- In-source attribution comments (`// Spring AI 2.0.0-Mx: <description>`) that document **when** a change happened — per the established convention, they stay.
- The `v2.0.0-M8` (and earlier) timeline entries in `spring-ai-history.html` — historical data points.
- The `SyncToolSpecification` references in `mcp/04` README + `SPRING_AI_STAGE_6.md` — MCP SDK types, not the removed Spring AI `ToolSpec`.

---

## Part 3 — Provider-by-provider checklist

| Provider | Module changed? | Code changed? | Config keys changed? | Notes |
|---|---|---|---|---|
| **OpenAI** | — | — | — | Default provider. Tool calling + image both exercised here. |
| **Anthropic** | — | — | — | |
| **Azure (Foundry)** | — | — | — | |
| **AWS Bedrock** | — | — | — | Built-in tool-exec removed from `BedrockProxyChatModel` (#6272) — verify Stage 1 tools still work via ChatClient. |
| **Google GenAI** | — | — | — | |
| **Ollama** | — | — | — | Full local-only test path; built-in tool-exec removed from `OllamaChatModel` (#6256). |

The breaking changes are all in **shared component code** (`components/apis/chat`, `components/apis/image`, `components/patterns/02-rag`), so the fixes apply once and benefit every provider — no per-provider yaml edits this round (contrast with M8, which touched all 6 provider yamls).

---

## Part 4 — Implementation tasks

> Convention: every code/config change ends with `./mvnw spotless:apply` before commit. Run from repo root.

### Task 1: Branch + BOM bump

**Files:** Modify `pom.xml:20`

- [ ] **Step 1:** Branch off main:

```bash
git checkout main && git pull --ff-only
git checkout -b chore/spring-ai-rc1-bump
```

- [ ] **Step 2:** Bump `pom.xml:20`:

```diff
-    <spring-ai.version>2.0.0-M8</spring-ai.version>
+    <spring-ai.version>2.0.0-RC1</spring-ai.version>
```

- [ ] **Step 3:** Commit (compile will still fail until Task 2 — that's expected; commit the BOM bump on its own for a clean history):

```bash
git add pom.xml
git commit -m "chore(spring-ai): bump 2.0.0-M8 → 2.0.0-RC1 (BOM only)"
```

### Task 2: Fix breaking API changes

**Files:**
- Modify `components/apis/chat/src/main/java/com/example/chat_05/ToolController.java`
- Modify `components/apis/image/src/main/java/com/example/image_01/ImageController.java`
- Modify `components/patterns/02-retrieval-augmented-generation/pom.xml`

- [ ] **Step 1 — `toolNames()` removal.** Inject the `FunctionToolCallback` bean and pass it explicitly:

```diff
 import org.springframework.ai.chat.client.ChatClient;
+import org.springframework.ai.tool.function.FunctionToolCallback;
 ...
 class ToolController {
   private final ChatClient chatClient;
+  private final FunctionToolCallback weatherTool;

-  public ToolController(ChatClient.Builder builder) {
+  public ToolController(ChatClient.Builder builder, FunctionToolCallback weatherFunctionCallback) {
     this.chatClient = builder.build();
+    this.weatherTool = weatherFunctionCallback;
   }
```

Then in both `/weather` and `/pack` endpoints:

```diff
-        .toolNames("weatherFunction")
+        .tools(this.weatherTool)
```

- [ ] **Step 2 — `N()` → `n()`** in `ImageController` (line 31):

```diff
-                ImageOptionsBuilder.builder().N(1).height(1024).width(1024).build()));
+                ImageOptionsBuilder.builder().n(1).height(1024).width(1024).build()));
```

- [ ] **Step 3 — advisor artifact rename** in the RAG pom (line 39):

```diff
-			<artifactId>spring-ai-advisors-vector-store</artifactId>
+			<artifactId>spring-ai-vector-store-advisor</artifactId>
```

- [ ] **Step 4:** Format + compile:

```bash
./mvnw spotless:apply
./mvnw -DskipTests clean compile
```

- [ ] **Step 5:** Commit:

```bash
git add components/apis/chat components/apis/image components/patterns/02-retrieval-augmented-generation/pom.xml
git commit -m "fix(api): migrate off removed RC1 APIs — toolNames()→tools() (#6301), N()→n() (#6285), advisor artifact rename (#6309)"
```

### Task 3: Verify MCP SDK M3 → RC1 + ChatClient tool execution

- [ ] **Step 1:** Full reactor verify:

```bash
./mvnw clean verify
```

Expect BUILD SUCCESS on 42 modules. If `mcp/04` or `mcp/05` fail to compile against MCP SDK RC1, fix the SDK API drift surgically and note it in the CHANGELOG (Task 7).

- [ ] **Step 2:** Runtime smoke — the three migrated paths + tool auto-execution:

```bash
./mvnw -pl applications/provider-ollama spring-boot:run \
  -Dspring-boot.run.profiles=ui
# Then, in another shell:
curl -s "http://localhost:8080/chat/05/time?city=Toronto"      # toolNames→tools migration
curl -s "http://localhost:8080/chat/05/weather?city=Toronto"   # FunctionToolCallback via .tools()
curl -s "http://localhost:8080/image/01/make"                  # .n() rename (OpenAI/Azure only)
curl -s "http://localhost:8080/rag/01/query?q=which+bike"      # advisor artifact rename
```

Expect tool-backed answers (not "I can't access live data"), confirming `ChatClient`/`ToolCallingAdvisor` still auto-executes tools after the `ChatModel` internal-loop removal.

### Task 4: Workshop version 2.3.7 → 2.3.8

Bump `VERSION`, `workshop.properties`, `prepare.sh` (Spring AI default + slides patch literal), `layout.html` placeholder. Commit:

```bash
git commit -m "chore(workshop): bump 2.3.7 → 2.3.8 for Spring AI RC1"
```

### Task 5: Non-historical version-label sweep M8 → RC1 + doc corrections

For the ~21 files in Part 2's sweep table, replace `Spring AI 2.0.0-M8` → `Spring AI 2.0.0-RC1`, `| 2.0.0-M8 |` → `| 2.0.0-RC1 |`, and `**Spring AI Version:** 2.0.0-M8` → `2.0.0-RC1`. Surgical edits only.

Additionally apply the **documentation corrections** from Part 2:
- Remove the `ToolSpec` row from `SPRING_AI_STAGE_1.md`.
- `ToolCallAdvisor` → `ToolCallingAdvisor` in `SPRING_AI_INTRODUCTION.md` + `SPRING_AI_STAGE_8.md` (current-class prose only).
- Rewrite `README.md` line 11 "Recently upgraded" callout to M8→RC1 highlighting the three breaking changes and the removed `ToolSpec`/renamed advisor.

```bash
git commit -m "docs: sweep labels 2.0.0-M8 → 2.0.0-RC1 + retire ToolSpec, rename ToolCallAdvisor→ToolCallingAdvisor"
```

### Task 6: Pixel-art history timeline

Edit `spring-ai-history.html`:
- Retitle the M8 entry (`'Where we are today'` → `'MCP autoconfig packaging fixes'`).
- Insert new RC1 entry after M8: `id:'v2.0.0-RC1'`, `date:'2026-06-06'`, `badge:'RC1'`, `title:'Where we are today'`, bullets covering RC1 headlines.
- Bump `WORLD_END` 15200 → 15560, comment `38 entries → 39 entries`.
- Bump the foundation line "M8 is the foundation" → "RC1 is the foundation".

```bash
git commit -m "feat(history): add v2.0.0-RC1 to pixel-art timeline + retitle M8"
```

### Task 7: CHANGELOG `[2.3.8]` entry

Prepend a new entry at the top of `CHANGELOG.md` matching the shape of `[2.3.7]`. Sections:
- **Changed** — BOM bump M8 → RC1; `toolNames()` → `.tools()` migration; `N()` → `n()`; advisor artifact rename; MCP SDK M3 → RC1.
- **Removed (upstream)** — `ToolSpec` consumer API (#6292), `toolNames()`/`SpringBeanToolCallbackResolver` (#6301/#6154), `internalToolExecutionEnabled` (#6289), built-in `ChatModel` tool-exec loop (#6252–#6272), MiniMax/Pixtral/deprecated-Mistral models.
- **Docs** — retired `ToolSpec` Stage 1 entry; `ToolCallAdvisor` → `ToolCallingAdvisor`.
- **Notes** — turn-boundary snapping in chat memory (#6312), Tool Search Advisor available (#5909, not adopted); reactor verify + runtime smoke summary.

```bash
git commit -m "docs(changelog): [2.3.8] — Spring AI M8 → RC1"
```

### Task 8: Upgrade plan doc

Commit this file (`SPRING_AI_M8_TO_RC1_UPGRADE_PLAN.md`):

```bash
git commit -m "docs: add Spring AI M8 → RC1 upgrade plan"
```

### Task 9: Push + PR + tag + release + merge

- [ ] `git push -u origin chore/spring-ai-rc1-bump`
- [ ] `gh pr create --title "chore(spring-ai): bump 2.0.0-M8 → 2.0.0-RC1" --body "..."`
- [ ] After PR approval / final check: `git tag -a v2.3.8 -m "v2.3.8 — Spring AI 2.0.0-RC1 (breaking tool-calling API migration)"`
- [ ] `git push origin v2.3.8`
- [ ] `gh release create v2.3.8 --title "..." --notes "..."`
- [ ] `gh pr merge <PR#> --merge`
- [ ] `git push origin --delete chore/spring-ai-rc1-bump && git branch -d chore/spring-ai-rc1-bump`

---

## Part 5 — Verification

### Per-task verification commands

```bash
# After Task 2 — confirm the removed APIs are gone from our source
grep -rn "\.toolNames(\|\.N(" --include="*.java" \
  components/apis/chat components/apis/image | grep -v "/target/"
# Expect: empty

grep -rn "spring-ai-advisors-vector-store" . | grep -v "/target/" | grep -v "/.git/" \
  | grep -v "SPRING_AI_M.*_TO_.*" | grep -v "migration/" | grep -v "CHANGELOG.md"
# Expect: empty (only historical plan/changelog/migration docs may still name the old artifact)

# After Task 5 — confirm only history-page timeline data + the new README/CHANGELOG callouts mention M8
grep -rln "2\.0\.0-M8" \
  --include="*.md" --include="*.xml" --include="*.html" \
  --include="*.yaml" --include="*.yml" --include="*.sh" \
  --include="*.json" --include="*.properties" --include="*.java" \
  --include="VERSION" . \
  | grep -v "/target/" | grep -v "/migration/" \
  | grep -v "SPRING_AI_M.*_TO_.*" \
  | grep -v "CHANGELOG.md" | grep -v "/.git/" | grep -v "/superpowers/"
# Expect: README.md (M8 named as "the prior version") + spring-ai-history.html (timeline data, handled in Task 6).

# Final reactor verify
./mvnw clean verify
# Expect: BUILD SUCCESS, 42 modules
```

### Runtime smoke matrix (post-merge)

| Provider | Profile combo | Expected |
|---|---|---|
| OpenAI | `pgvector,observation,ui` | 200 on `/chat/05/weather`, `/chat/05/time`, `/image/01/make`, `/rag/01/query` |
| Anthropic | `observation,ui` | 200 on `/chat/05/*` (tool calling) |
| Azure | `pgvector,observation,ui` | 200 on `/chat/05/*` + `/image/01/make` |
| AWS | `observation,ui` | 200 on `/chat/05/*` (verify post-`BedrockProxyChatModel` internal-loop removal) |
| Google | `observation,ui` | 200 on `/chat/05/*` |
| Ollama | `pgvector,observation,ui,spy` | 200 on `/chat/05/*` + `/rag/01/query` |
| Stage 6 | dashboard | All 5 MCP demos work on MCP SDK RC1 |
| Stage 7 | `02-model-directed-loop` | `@Tool` agent loop still executes tools via ChatClient |

---

## Part 6 — Recommended follow-ups (NOT done in this bump)

1. **Adopt the Tool Search Advisor (#5909) as new Stage content.** RC1 ships `spring-ai-tool-search-tool-advisor` with vector-store / Lucene / regex `ToolIndex` backends — a natural extension of the Stage 5/6 tool-calling material (on-demand tool discovery when the tool catalogue is large).
2. **Showcase `EntityParamSpec` (#6165)** in the Stage 1 structured-output demos — per-call structured-output configuration on `ChatClient.entity()`.
3. **Mention turn-boundary snapping (#6312)** in the Stage 4 chat-memory narrative — eviction no longer splits a conversational turn.
4. **Migrate any future `ChatClientCustomizer` usage to `ChatClientBuilderCustomizer`** (#6204) — not used today, but the old name is now deprecated.
5. **Watch for 2.0.0 GA.** Track whether the deprecated `ToolCallAdvisor` shim is removed at GA (we already use the auto-configured default, so impact is limited to prose), and whether the MCP Java SDK reaches 1.0.0/GA.
6. **Re-run the deferred manual smoke tests** from prior plans (PgVector dimension validation, Grafana span-tree inspection now showing `tool.calling.advisor`, Stage 7 agentic E2E, Stage 6 MCP demos).

---

*Plan authored: 2026-06-08. Author: workshop maintainer + Claude. Status: ready for execution (awaiting go-ahead).*
