# Spring AI 2.0.0-RC1 → 2.0.0 GA + Spring Boot 4.0.6 → 4.1.0 Upgrade Plan

> **For agentic workers:** REQUIRED SUB-SKILL: `superpowers:subagent-driven-development` or `superpowers:executing-plans`. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bump the workshop to the **GA-era stack** — Spring AI **2.0.0 GA**, Spring Boot **4.1.0**, Spring Cloud **2025.1.2** — and ship workshop **`v2.4.0`**.

**Architecture:** Four coordinated version-property bumps in the root `pom.xml` drive the whole stack. Unlike the M8 → RC1 hop (which was a *breaking* Spring AI release requiring three source/build fixes), **RC1 → GA is a stabilisation release with no breaking API changes that touch this codebase** — verified by grep (below) and by a full green reactor build. The work is therefore **almost entirely a mechanical version sweep** across docs, HTML, version files and the changelog — plus the one thing the user flagged for intensive scrutiny: **Spring Cloud Gateway compatibility with Spring Boot 4.1.0**, which is now empirically confirmed working.

**Tech Stack (target):** Spring Boot 4.1.0 · Spring Framework 7.0.8 · Spring AI 2.0.0 GA · Spring Cloud 2025.1.2 (Gateway Server WebMVC 5.0.2) · MCP Java SDK 2.0.0 · Java 25 · Maven 3.9.14

**Reference release notes:**
- Spring AI 2.0.0 GA — <https://github.com/spring-projects/spring-ai/releases/tag/v2.0.0>
- Spring Boot 4.1.0 — <https://github.com/spring-projects/spring-boot/releases/tag/v4.1.0>
- Spring Cloud 2025.1.2 — <https://github.com/spring-cloud/spring-cloud-release/releases/tag/v2025.1.2>

**Companion docs:** [`SPRING_AI_M8_TO_RC1_UPGRADE_PLAN.md`](SPRING_AI_M8_TO_RC1_UPGRADE_PLAN.md), [`SPRING_AI_M7_TO_M8_UPGRADE_PLAN.md`](SPRING_AI_M7_TO_M8_UPGRADE_PLAN.md), [`SPRING_AI_M6_TO_M7_UPGRADE_PLAN.md`](SPRING_AI_M6_TO_M7_UPGRADE_PLAN.md), [`SPRING_AI_M5_TO_M6_MIGRATION.md`](SPRING_AI_M5_TO_M6_MIGRATION.md), [`SPRING_AI_M4_TO_M5_MIGRATION.md`](SPRING_AI_M4_TO_M5_MIGRATION.md).

---

## Part 0 — Version comparison at a glance

| Component | Current (v2.3.8) | Target (v2.4.0) | Kind of change |
|---|---|---|---|
| **Spring Boot** | 4.0.6 | **4.1.0** | Minor upgrade |
| **Spring Framework** (transitive) | 7.0.x | **7.0.8** | Patch (via Boot) |
| **Spring AI** | 2.0.0-RC1 | **2.0.0 GA** | RC → GA stabilisation |
| **Spring Cloud** | 2025.1.1 | **2025.1.2** | Patch (Oakwood train) |
| **Spring Cloud Gateway Server WebMVC** (transitive) | 5.0.1 | **5.0.2** | Patch (via Spring Cloud) |
| **MCP Java SDK** (transitive via Spring AI BOM) | 2.0.0-RC1 | **2.0.0** | RC → GA |
| **Spring Security** (transitive via Boot) | 7.0.5 | **7.1.0** | Minor (via Boot) |
| **Spring Cloud Azure** | 7.1.0 | 7.1.0 (unchanged) | — |
| **Java** | 25 | 25 (unchanged) | — |
| **Workshop version** | 2.3.8 | **2.4.0** | — |

---

## Part 1 — Spring compatibility (the intensive check)

The user's explicit concern: **does the latest Spring Cloud Gateway work with Spring Boot 4.1.0?** Two independent signals plus an empirical build settle this:

1. **start.spring.io offers Boot 4.1.0 together with Spring Cloud 2025.1.2.** start.spring.io only surfaces *mutually compatible* release-train ↔ Boot combinations, so their co-selectability is a direct compatibility signal from Spring's own tooling.
2. **Spring AI 2.0.0 GA itself upgraded its baseline to Spring Boot 4.1.0** (#6329). The GA-era stack is *designed* around Boot 4.1.0.
3. **Empirical reactor build — `./mvnw clean verify` on the bumped stack: BUILD SUCCESS, 43 modules, all tests pass (0 failures / 0 errors / 0 skipped).** The `gateway` module (`spring-cloud-starter-gateway-server-webmvc`) compiled and verified. Resolved on the classpath:
   - `spring-cloud-gateway-server-webmvc:5.0.2`
   - `spring-boot-autoconfigure:4.1.0`
   - `spring-core:7.0.8`
   - `spring-ai-client-chat:2.0.0`, `io.modelcontextprotocol.sdk:mcp:2.0.0`

> ⚠️ **Stale-doc caveat:** the Spring Cloud *Supported-Versions* wiki still maps the `2025.1` (Oakwood) train to "Spring Boot 4.0.x". That table reflects the train's *initial* (2025.1.0) baseline and has not been refreshed for the 4.1.0 line; start.spring.io + the GA Spring AI baseline + our green build supersede it. **Verdict: compatible.** This and other version-doc gaps are catalogued in [`SPRING_VERSION_DOC_GAP.md`](SPRING_VERSION_DOC_GAP.md) (incl. the undocumented **Spring AI 2.0.0-RC2** hotfix that GA's notes never mention).

### RC1 → GA breaking-change audit (Spring AI)

GA is a stabilisation release. Every GA change item, checked against this codebase:

| GA change (PR) | Affects us? | Evidence |
|---|---|---|
| **Remove `streamToolCallResponses` from advisor builders** (#6391) | **No** | `grep -rn streamToolCallResponses --include=*.java` → **0 hits**. |
| **Add missing `promptCacheKey` to `OpenAiChatOptions`** (#6380) | **No** (additive) | Not referenced anywhere; nothing to change. |
| **Use only Jackson 2 in `OpenAiChatModel`** (#6392) | **No** | Internal to Spring AI; our code never touches its Jackson wiring. |
| **Preserve OpenAI tool-call additional properties** (#6365) | **No** (behavioural) | Improves fidelity of tool-call round-trips; auto-applied. |
| **`org.springframework.ai.image.observation` null-marked** (#6388) | **No** | Nullability annotations only; no API shape change. |
| **Filter unsupported tool messages in Cassandra/Mongo/JDBC chat-memory repos** (#6398/#6399/#6400) | **No** | We use `MessageWindowChatMemory` (in-memory); `grep` for `JdbcChatMemoryRepository`/`Cassandra*`/`Mongo*` → **0 hits**. |
| **Updated Google GenAI models** (#6406) | **No** | Model-constant additions; our Google config pins its own model id. |
| **MCP SDK 2.0.0-RC1 → 2.0.0** (#6385) | **Verify only** | Transitive via BOM; `mcp/04` + `mcp/05` touch SDK types directly. ✅ Compiled green. |
| **Spring Boot → 4.1.0** (#6329) | **Yes (intended)** | This *is* our Boot bump; handled by the parent-POM version. |

**Net Spring-AI code impact of RC1 → GA: zero source changes.** (Contrast: M8 → RC1 needed `toolNames()`→`.tools()`, `N()`→`.n()`, and an advisor-artifact rename — all already in place since v2.3.8.)

### Spring Boot 4.0.6 → 4.1.0 audit

Minor release, no API breakage for this codebase:

- Ships **Spring Framework 7.0.8**, **Spring Security 7.1.0**, Hibernate 7.4.1, Kotlin 2.3.21.
- **Java 25 baseline confirmed** (the workshop is already on Java 25 — no change).
- Deprecations (`SpringJtaPlatform`) and the removed test-only Security↔HtmlUnitDriver integration are **not used here**.
- No workshop-relevant property removals.

**Net Spring-Boot code impact: zero source changes** (confirmed by green `clean verify`, including the dashboard/test modules).

### Important consequence for the docs sweep

Because **GA introduces no application-code changes**, every code sample currently shown in the dashboard UI / `docs/spring-ai/*.md` (the RC1 `toolNames()`→`.tools()`, `.n()`, typed `ChatCompletionToolChoiceOption` patterns) **remains correct verbatim**. The doc work is therefore **labels + narrative + version strings only** — no code-snippet edits.

---

## Part 2 — Impact summary (TL;DR)

| Risk | Change | Action |
|---|---|---|
| 🟩 **VERIFY (done)** | Spring Cloud Gateway on Boot 4.1.0 | ✅ Confirmed: Gateway 5.0.2 builds + verifies on Boot 4.1.0. |
| 🟩 **VERIFY (done)** | MCP SDK RC1 → 2.0.0 in `mcp/04`, `mcp/05` | ✅ Confirmed: both compile + reactor-green against SDK 2.0.0. |
| 🟦 **BUILD** | Four version-property bumps in root `pom.xml` | Boot `4.0.6→4.1.0`, AI `2.0.0-RC1→2.0.0`, Cloud `2025.1.1→2025.1.2`. (azure unchanged.) |
| 🟨 **DOCS** | Workshop label sweep `2.0.0-RC1 → 2.0.0`, `Spring Boot 4.0.6 → 4.1.0`, `2025.1.1 → 2025.1.2` | Surgical edits across ~25 files (Part 3). |
| 🟨 **DOCS** | Workshop version `2.3.8 → 2.4.0` | `VERSION`, `workshop.properties`, `prepare.sh`, `layout.html`. |
| 🟨 **DOCS** | Pixel-art history timeline: add `v2.0.0` GA entry; retitle RC1 retrospective | `spring-ai-history.html`. |
| 🟨 **DOCS** | `CHANGELOG.md` `[2.4.0]` entry | Document the GA + Boot + Cloud bump. |
| 🟩 **INFO** | `streamToolCallResponses` removed (#6391), promptCacheKey added (#6380), Jackson-2-only OpenAI (#6392) | No-ops here; optionally noted in CHANGELOG. |

**No per-provider yaml edits** this round — the bump is entirely in shared root config + docs.

---

## Part 3 — File-by-file impact map

### Build (code/config)

| File | Change | Status |
|---|---|---|
| `pom.xml` line 9 | `spring-boot-starter-parent` `4.0.6` → `4.1.0` | ✅ applied on `chore/spring-ga-bump` |
| `pom.xml` line 20 | `<spring-ai.version>` `2.0.0-RC1` → `2.0.0` | ✅ applied |
| `pom.xml` line 21 | `<spring-cloud.version>` `2025.1.1` → `2025.1.2` | ✅ applied |

> No application `.java` / yaml changes. The 6 in-source `// Spring AI 2.0.0-RC1:` attribution comments (agentic toolChoice fix) **stay** — they document *when* that change happened (established convention).

### Workshop-version touchpoints (`2.3.8 → 2.4.0`)

| File | Change |
|---|---|
| `VERSION` | `2.3.8` → `2.4.0` |
| `components/config-dashboard/src/main/resources/workshop.properties` | `workshop.version=2.3.8` → `2.4.0` |
| `prepare.sh` (lines 70, 71, 114, 115) | Spring Boot default `4.0.6`→`4.1.0`; Spring AI default `2.0.0-RC1`→`2.0.0`; replace-literals updated |
| `components/config-dashboard/src/main/resources/templates/fragments/layout.html` (lines 106–107) | `v2.3.8`→`v2.4.0` placeholder; `Spring AI 2.0.0-RC1`→`Spring AI 2.0.0` |

### Label sweep `2.0.0-RC1 → 2.0.0`, `Boot 4.0.6 → 4.1.0`, `2025.1.1 → 2025.1.2`

Surgical edits — **do not blanket-replace**; confirm with the Part 5 grep.

- `README.md` (top banner + "Recently upgraded" callout — rewrite to GA, Boot 4.1.0, Cloud 2025.1.2; emphasise GA stability + no breaking changes)
- `CHANGELOG.md` (new `[2.4.0]` entry — see Task 6; also carries the only remaining `2025.1.1` references, which become historical record)
- `docs/README.md`, `docs/guide.md`
- `docs/spring-ai/SPRING_AI_INTRODUCTION.md` (forward-looking version mentions; GA milestone callout)
- `agentic-system/readme.md`
- `applications/provider-{ollama,openai,anthropic,azure,aws,google}/readme.md` (banner only — leave historical "Migrated for M*" lines)
- `WHATS_NEW_STAGE_06_MCP.md` (MCP SDK `RC1`→`2.0.0` in the "APIs used" section)
- `support/{howto_windows11,os-compatibility-analysis,prerequisites}.md`
- `components/config-openapi/src/main/java/com/example/openapi/OpenApiConfig.java` (line 17 `version="2.0.0-RC1"`→`"2.0.0"`; line 22 tech-stack string `Spring Boot 4.0.6 | Spring AI 2.0.0-RC1`→`Spring Boot 4.1.0 | Spring AI 2.0.0`)
- `components/config-dashboard/src/main/resources/static/slides.html` (banner pill; Boot 4.0.6→4.1.0)
- `docker/observability-stack/grafana/dashboards/spring-ai-workshop-overview.json` (description banner)
- `workshop.sh` (banner occurrences)

### Pixel-art history timeline — `spring-ai-history.html`

- Retitle the RC1 entry (`id:'v2.0.0-RC1'`) from `title:'Where we are today'` to a neutral retrospective (e.g. `'Tool-calling API cleanup (breaking)'`).
- Append a new **`v2.0.0` GA** entry (`badge:'GA'`, `date:'2026-06-12'`) with `title:'Where we are today'` and bullets: GA stabilisation, Spring Boot 4.1.0 baseline, MCP SDK 2.0.0, `streamToolCallResponses` removed, no breaking changes for this workshop.
- Bump `WORLD_END` and the inline `… entries` comment by one entry (`+360`).
- Bump the foundation line `'<li>Spring AI 2.0.0-RC1 is the foundation</li>'` → `'…2.0.0 GA is the foundation'`.

### Files NOT touched (historical — leave as-is)

- `migration/*.md`; `SPRING_AI_M4_TO_M5_MIGRATION.md` … `SPRING_AI_M8_TO_RC1_UPGRADE_PLAN.md`.
- `CHANGELOG.md` entries `[2.3.8]` and earlier.
- In-source `// Spring AI 2.0.0-RC1:` / `// Spring Boot 4.0.x:` attribution comments.
- `v2.0.0-RC1` and earlier timeline entries in `spring-ai-history.html`.

---

## Part 4 — Provider checklist

| Provider | Module changed? | Code? | Notes |
|---|---|---|---|
| OpenAI | — | — | Default provider; tool-calling + image exercised here. |
| Anthropic | — | — | |
| Azure | — | — | `spring-cloud-azure` 7.1.0 unchanged; resolved clean on Boot 4.1.0. |
| AWS Bedrock | — | — | |
| Google GenAI | — | — | GA model-constant additions (#6406) — config pins its own model id. |
| Ollama | — | — | Full local-only smoke path. |

All changes are in **shared root config + docs** — no per-provider yaml edits.

---

## Part 5 — Implementation tasks

> Convention: every code/config change ends with `./mvnw spotless:apply` before commit. Run from repo root. Branch `chore/spring-ga-bump` already created; root-pom bumps already applied + reactor-verified.

### Task 1: BOM/parent bumps (root pom) — **applied, verified**

- [x] `pom.xml:9` `4.0.6` → `4.1.0`
- [x] `pom.xml:20` `2.0.0-RC1` → `2.0.0`
- [x] `pom.xml:21` `2025.1.1` → `2025.1.2`
- [x] `./mvnw clean verify` → BUILD SUCCESS, 43 modules, all tests pass

```bash
git add pom.xml
git commit -m "chore(deps): bump to GA stack — Spring AI 2.0.0, Spring Boot 4.1.0, Spring Cloud 2025.1.2"
```

### Task 2: Workshop version 2.3.8 → 2.4.0

Edit `VERSION`, `workshop.properties`, `prepare.sh` (defaults + replace-literals), `layout.html` (placeholder + Spring AI label).

```bash
git commit -m "chore(workshop): bump 2.3.8 → 2.4.0 for Spring AI GA"
```

### Task 3: Label sweep + OpenApiConfig

Apply the Part 3 sweep across the ~25 listed files (`2.0.0-RC1`→`2.0.0`, `Spring Boot 4.0.6`→`4.1.0`, `2025.1.1`→`2025.1.2`). Surgical edits only.

```bash
./mvnw spotless:apply
git commit -m "docs: sweep labels to GA stack (Spring AI 2.0.0, Boot 4.1.0, Cloud 2025.1.2)"
```

### Task 4: README rewrite

Rewrite the `README.md` banner + "Recently upgraded" callout to the GA stack; emphasise GA stability and that RC1→GA needed no code changes; note Gateway-on-4.1.0 verified.

```bash
git commit -m "docs(readme): GA stack + compatibility note"
```

### Task 5: Pixel-art history timeline

Edit `spring-ai-history.html` per Part 3 (retitle RC1, add GA entry, bump `WORLD_END` +360, update foundation line).

```bash
git commit -m "feat(history): add v2.0.0 GA to pixel-art timeline"
```

### Task 6: CHANGELOG `[2.4.0]`

Prepend a `[2.4.0]` entry matching the shape of `[2.3.8]`. Sections:
- **Changed** — Spring AI RC1 → 2.0.0 GA; Spring Boot 4.0.6 → 4.1.0; Spring Cloud 2025.1.1 → 2025.1.2; MCP SDK RC1 → 2.0.0 (transitive); workshop 2.3.8 → 2.4.0.
- **Verified** — full reactor `clean verify` green (43 modules); Spring Cloud Gateway 5.0.2 compatible with Boot 4.1.0; resolved Spring Framework 7.0.8 / Security 7.1.0.
- **Notes (upstream, no workshop impact)** — `streamToolCallResponses` removed from advisor builders (#6391); `promptCacheKey` added to `OpenAiChatOptions` (#6380); Jackson-2-only `OpenAiChatModel` (#6392); chat-memory repos filter unsupported tool messages (#6398–6400).
- **No application code changes** — RC1 → GA is source-compatible for this workshop.

```bash
git commit -m "docs(changelog): [2.4.0] — Spring AI GA + Spring Boot 4.1.0"
```

### Task 7: This plan doc

```bash
git add SPRING_AI_RC1_TO_GA_UPGRADE_PLAN.md
git commit -m "docs: add RC1 → GA upgrade plan"
```

### Task 8: Push + PR + tag + release + merge

- [ ] `git push -u origin chore/spring-ga-bump`
- [ ] `gh pr create --title "chore(deps): GA stack — Spring AI 2.0.0 + Spring Boot 4.1.0" --body "..."`
- [ ] `git tag -a v2.4.0 -m "v2.4.0 — Spring AI 2.0.0 GA + Spring Boot 4.1.0"`
- [ ] `git push origin v2.4.0 && gh release create v2.4.0 ...`
- [ ] `gh pr merge <PR#> --merge`

---

## Part 6 — Verification

```bash
# Confirm GA-removed APIs absent from our source (expect empty)
grep -rn "streamToolCallResponses" --include="*.java" . | grep -v /target/

# Confirm no stray pre-GA labels remain (expect only historical plan/changelog/migration + history-timeline data)
grep -rln "2\.0\.0-RC1" --include="*.md" --include="*.html" --include="*.java" \
  --include="*.properties" --include="*.json" --include="*.sh" --include="*.xml" . \
  | grep -v /target/ | grep -v /.git/ | grep -v "SPRING_AI_M.*_TO_.*" \
  | grep -v "SPRING_AI_RC1_TO_GA" | grep -v "/migration/" | grep -v "CHANGELOG.md"
# Expect: spring-ai-history.html (timeline data) + the 6 in-source attribution comments only.

grep -rln "4\.0\.6" --include="*.md" --include="*.html" --include="*.java" --include="*.json" --include="*.sh" . \
  | grep -v /target/ | grep -v "SPRING_AI_M" | grep -v "/migration/" | grep -v "CHANGELOG.md" | grep -v "SPRING_AI_RC1_TO_GA"
# Expect: empty.

# Final reactor verify
./mvnw clean verify   # Expect BUILD SUCCESS, 43 modules
```

### Runtime smoke matrix (post-merge)

| Provider | Profile combo | Expected |
|---|---|---|
| OpenAI | `pgvector,observation,ui` | 200 on `/chat/05/weather`, `/chat/05/time`, `/image/01/make`, `/rag/01/query` |
| Ollama | `pgvector,observation,ui,spy` | 200 on `/chat/05/*` + `/rag/01/query`; **`spy` profile exercises Gateway on Boot 4.1.0** |
| Anthropic / Azure / AWS / Google | `observation,ui` | 200 on `/chat/05/*` (Azure also `/image/01/make`) |
| Stage 6 | dashboard | All 5 MCP demos work on MCP SDK 2.0.0 |
| Stage 7 | `02-model-directed-loop` | `@Tool` agent loop executes tools via ChatClient |

---

## Part 7 — Recommended follow-ups (NOT done in this bump)

1. **Adopt the Tool Search Advisor (#5909, shipped RC1, stable at GA)** as new Stage content — on-demand tool discovery for large tool catalogues.
2. **Showcase `EntityParamSpec` (#6165)** in Stage 1 structured-output demos.
3. **Mention turn-boundary snapping (#6312)** in the Stage 4 chat-memory narrative.
4. **Refresh the Spring Cloud Supported-Versions citation** if/when the wiki updates its 2025.1 ↔ Boot 4.1.x row.

---

*Plan authored: 2026-06-15. Compatibility empirically verified (reactor-green on the GA stack) before authoring. Status: root-pom bumps applied + verified; docs sweep pending execution.*
