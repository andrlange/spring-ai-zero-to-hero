# Spring AI 2.0.0-M7 → 2.0.0-M8 Upgrade Plan

> **For agentic workers:** REQUIRED SUB-SKILL: `superpowers:subagent-driven-development` or `superpowers:executing-plans`. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bump the workshop from Spring AI 2.0.0-M7 → 2.0.0-M8, drop the M7 mcp-client autoconfig workaround (now fixed upstream), and ship `v2.3.7`.

**Architecture:** Single property bump (`<spring-ai.version>`) drives the BOM upgrade; the M8 release is fix-focused (no new features touching our surface). The biggest workshop-visible change is **removing** the M7 packaging-bug workaround introduced in `968807b` — M8 #6138 restored the missing `spring-ai-autoconfigure-mcp-client-common` transitive dependency so the exclude block in each provider yaml is no longer needed. The rest is the usual workshop version bump (2.3.6 → 2.3.7), non-historical label sweep, history-page entry, and CHANGELOG.

**Tech Stack:** Spring Boot 4.0.6 · Spring AI 2.0.0-M8 · Java 25 · Maven 3.9.14 · MCP Java SDK 2.0.0-M3 (unchanged from M7)

**Reference release notes:** <https://github.com/spring-projects/spring-ai/releases/tag/v2.0.0-M8>

**Companion docs:** [`SPRING_AI_M6_TO_M7_UPGRADE_PLAN.md`](SPRING_AI_M6_TO_M7_UPGRADE_PLAN.md), [`SPRING_AI_M5_TO_M6_MIGRATION.md`](SPRING_AI_M5_TO_M6_MIGRATION.md), [`SPRING_AI_M4_TO_M5_MIGRATION.md`](SPRING_AI_M4_TO_M5_MIGRATION.md), [`migration/upgrade.md`](migration/upgrade.md).

---

## Part 1 — Impact summary (TL;DR)

| Risk | M8 change | Affects us? | Action |
|---|---|---|---|
| 🟩 **CLEANUP** | **#6138 — Restore transitive autoconfig dependencies** | **Yes — fixes our M7 workaround.** M8 `spring-ai-autoconfigure-mcp-client-httpclient` now transitively pulls `spring-ai-autoconfigure-mcp-client-common`. Verified: M8 `mcp-client-common` jar exists on the milestone repo and ships `McpSseClientProperties`, `McpStreamableHttpClientProperties`, `McpClientCommonProperties`. Server-side `mcp-server-common:2.0.0-M8` also published (was the issue reporter's failure mode). | **Remove the 7-line `spring.autoconfigure.exclude` block** added by commit `968807b` from all 6 provider `application.yaml` files. |
| 🟩 **FIX** | **#6164 — `spring-ai-starter-vector-store-pgvector` needs `spring-boot-starter-jdbc`** | **No effect for us.** All 3 pgvector providers (`openai`, `azure`, `ollama`) already include `spring-boot-starter-flyway` which pulls `spring-boot-starter-jdbc` transitively. The M8 fix closes the latent footgun for users who depend on pgvector without Flyway. | None. |
| 🟩 **FIX** | **#6171 — `spring-ai-starter-model-google-genai` over-declared embedding dep** | **Possibly cleaner deps.** `provider-google` already has an explicit `<exclusions>` block against the embedding artifact. M8 removes the embedding dep from the starter so our exclusion becomes redundant — harmless, but you can drop the `<exclusions>` block to clean up. | Optional follow-up — not done in this bump. |
| 🟩 **FIX** | **#6150 — M7 forced API-key requirement broke cookie/session auth** | **No effect.** We always provide API keys via `creds.yaml`; no cookie/session-based auth. | None. |
| 🟨 **LOW** | **#6186 — Dash-separated convention for Spring Boot properties** | **No-op.** All workshop `spring.ai.*` config keys already use dash-separated naming (`spring.ai.openai.chat.options.model`, `spring.ai.vectorstore.pgvector.dimension`, etc.). No camelCase or underscore keys found in any provider/component yaml. | None. |
| 🟨 **LOW** | **#6127 — `ChatOptions#mutate` overrides return more specific types** | **No-op.** No `.mutate(...)` calls in our codebase. | None. |
| 🟨 **LOW** | **#6090 — Exclude `jackson-dataformat-yaml` from `json-schema-validator`** | **No-op.** We don't use `jackson-dataformat-yaml` directly anywhere. | None. |
| 🟨 **LOW** | **#5585 — MistralAI Jackson mapping improvements** | **No-op.** We don't use Mistral. | None. |

**Workshop side effects (mechanical, same pattern as previous bumps):**

- Workshop version `2.3.6` → `2.3.7` in `VERSION`, `workshop.properties`, `prepare.sh`, `layout.html` placeholder.
- Non-historical version-label sweep `2.0.0-M7` → `2.0.0-M8` (README, workshop.sh banners, docs/, all provider/component readmes, dashboard slides, Grafana dashboard, OpenAPI metadata).
- New `[2.3.7]` entry in `CHANGELOG.md`.
- New `v2.0.0-M8` (2026-05-27) entry on the pixel-art Spring AI History timeline; M7 retitled from "Where we are today" to a neutral retrospective ("ToolCallAdvisor default + MCP SDK M3").

**Reactor build target:** `./mvnw clean verify` → **BUILD SUCCESS** across 42 modules; no behavioral surprises.

**Runtime verify target:** boot `provider-ollama` with `pgvector,observation,ui,spy` profiles (the original failure scenario that exposed the M7 bug). With the workaround removed, M8 should boot cleanly.

---

## Part 2 — File-by-file impact map

### Code/config changes

| File | What changes | Why |
|---|---|---|
| `pom.xml` (root) | `<spring-ai.version>2.0.0-M7</spring-ai.version>` → `2.0.0-M8` | The single BOM bump. |
| `applications/provider-{ollama,openai,anthropic,azure,aws,google}/src/main/resources/application.yaml` | Remove the 7-line `spring.autoconfigure.exclude` block added by commit `968807b` | M8 #6138 restored the missing transitive dep; the workaround is no longer needed. |

### Workshop-version touchpoints

| File | What changes |
|---|---|
| `VERSION` | `2.3.6` → `2.3.7` |
| `components/config-dashboard/src/main/resources/workshop.properties` | `workshop.version=2.3.6` → `2.3.7` |
| `prepare.sh` (lines 71 + 115) | `2.0.0-M7` → `2.0.0-M8` defaults |
| `components/config-dashboard/src/main/resources/templates/fragments/layout.html` (line 106 + 107) | Workshop `v2.3.6` → `v2.3.7`, Spring AI `2.0.0-M7` → `2.0.0-M8` |

### Non-historical version-label sweep (21 files)

All forward-looking workshop-version banners get bumped `2.0.0-M7` → `2.0.0-M8`:

- `README.md` (line 7 banner + line 11 "Recently upgraded" callout rewrite to M7→M8 with the new packaging-fix note)
- `agentic-system/readme.md`
- `applications/provider-{ollama,openai,anthropic,azure,aws,google}/readme.md` (banner only — leave any historical "Migrated for M6/M5" lines)
- `WHATS_NEW_STAGE_06_MCP.md` (line 218 "APIs used")
- `docs/{README,guide}.md`
- `docs/spring-ai/SPRING_AI_INTRODUCTION.md` (lines 3, 105, 368 — all forward-looking)
- `support/{howto_windows11,os-compatibility-analysis,prerequisites}.md`
- `components/config-openapi/src/main/java/com/example/openapi/OpenApiConfig.java` (line 17 `version=` + line 22 tech stack desc)
- `components/config-dashboard/src/main/resources/static/slides.html` (banner pill)
- `components/config-dashboard/src/main/resources/static/slides.html.original` (prepare.sh baseline)
- `docker/observability-stack/grafana/dashboards/spring-ai-workshop-overview.json` (description banner)
- `workshop.sh` (4 banner occurrences)

### Pixel-art history timeline

- `components/config-dashboard/src/main/resources/static/spring-ai-history.html`:
  - Retitle M7 entry from `'Where we are today'` to `'ToolCallAdvisor default + MCP SDK M3'`.
  - Append new `v2.0.0-M8` (2026-05-27) entry with `title:'Where we are today'` and three bullets covering the M8 fixes.
  - Bump `WORLD_END` `14840 → 15200` and the inline comment `37 entries → 38 entries`.
  - Bump line 768 `'<li>Spring AI 2.0.0-M7 is the foundation</li>'` → `'M8 is the foundation'`.

### Files NOT touched (historical)

- `migration/*.md` — historical record of the prior Boot 3 → 4 / Spring AI 1 → 2.0-M4 migration.
- `SPRING_AI_M4_TO_M5_MIGRATION.md`, `SPRING_AI_M5_TO_M6_MIGRATION.md`, `SPRING_AI_M6_TO_M7_UPGRADE_PLAN.md` — historical records of prior milestones.
- `CHANGELOG.md` entries for `[2.3.6]` and earlier — historical.
- In-source attribution comments (`// Spring AI 2.0.0-M6: <description>` in agentic-system, gateway, audio, chat_07, AgentOptionsConfig, provider-azure pom and creds-template, provider-google pom) — these document WHEN a change happened. Per the M6→M7 convention, they stay.
- The `v2.0.0-M7` timeline entry in `spring-ai-history.html` (line 554 area) — historical data point.

---

## Part 3 — Provider-by-provider checklist

| Provider | Module changed? | Code changed? | Config keys changed? | Notes |
|---|---|---|---|---|
| **OpenAI** | — | — | Removed M7 workaround block from yaml | Default provider. |
| **Anthropic** | — | — | Removed M7 workaround block from yaml | |
| **Azure (Foundry)** | — | — | Removed M7 workaround block from yaml | |
| **AWS Bedrock** | — | — | Removed M7 workaround block from yaml | |
| **Google GenAI** | — | — | Removed M7 workaround block from yaml | M8 #6171 means `<exclusions>` in `pom.xml` is now redundant (optional follow-up). |
| **Ollama** | — | — | Removed M7 workaround block from yaml | Full local-only test path. |

The M8 packaging fix cuts across all 6 providers — they all inherited the M7 bug via `config-dashboard`'s transitive `spring-ai-starter-mcp-client` and all needed the workaround. M8 removes the need for the workaround uniformly.

---

## Part 4 — Implementation tasks

> Convention: every code/config change ends with `./mvnw spotless:apply` before commit. Run from repo root.

### Task 1: Branch + BOM bump

**Files:**
- Modify: `pom.xml:20`

- [x] **Step 1:** Branch off main:

```bash
git checkout main && git pull --ff-only
git checkout -b chore/spring-ai-m8-bump
```

- [x] **Step 2:** Bump `pom.xml:20`:

```diff
-    <spring-ai.version>2.0.0-M7</spring-ai.version>
+    <spring-ai.version>2.0.0-M8</spring-ai.version>
```

- [x] **Step 3:** Confirm compile:

```bash
./mvnw -DskipTests clean compile
```

- [x] **Step 4:** Commit:

```bash
git add pom.xml
git commit -m "chore(spring-ai): bump 2.0.0-M7 → 2.0.0-M8 (BOM only)"
```

### Task 2: Remove M7 mcp-client autoconfig workaround

**Files:**
- Modify: `applications/provider-{ollama,openai,anthropic,azure,aws,google}/src/main/resources/application.yaml`

- [x] **Step 1:** Delete the 7-line `spring.autoconfigure.exclude` block from each of the 6 provider yamls (the block added by commit `968807b`):

```bash
for p in ollama openai anthropic azure aws google; do
  sed -i.bak '/^  autoconfigure:$/,/StreamableHttpHttpClientTransportAutoConfiguration$/d' \
    applications/provider-$p/src/main/resources/application.yaml
  rm applications/provider-$p/src/main/resources/application.yaml.bak
done
```

- [x] **Step 2:** Verify (should output empty):

```bash
grep -rln "autoconfigure:" applications/provider-*/src/main/resources/application.yaml
```

- [x] **Step 3:** Commit:

```bash
git add applications/provider-*/src/main/resources/application.yaml
git commit -m "fix(providers): remove M7 mcp-client autoconfig workaround — fixed upstream in M8 (#6138)"
```

### Task 3: Full reactor verify + runtime smoke test

- [x] **Step 1:** `./mvnw clean verify` — expect BUILD SUCCESS on 42 modules.

- [x] **Step 2:** Smoke-test the original M7 failure scenario:

```bash
./mvnw -pl applications/provider-ollama spring-boot:run \
  -Dspring-boot.run.profiles=ui,spy
```

Expected: `Started OllamaApplication in N seconds`. (The full `pgvector,observation,ui,spy` combination additionally needs Postgres running; the `ui,spy` combination is sufficient to validate the autoconfig phase that broke under M7.)

### Task 4: Workshop version 2.3.6 → 2.3.7

Bump `VERSION`, `workshop.properties`, `prepare.sh` (Spring AI default + slides patch literal), `layout.html` placeholder. Commit:

```bash
git commit -m "chore(workshop): bump 2.3.6 → 2.3.7 for Spring AI M8"
```

### Task 5: Non-historical version-label sweep M7 → M8

For the 21 files listed in Part 2's sweep table, replace `Spring AI 2.0.0-M7` → `Spring AI 2.0.0-M8` and `| 2.0.0-M7 |` → `| 2.0.0-M8 |` and `**Spring AI Version:** 2.0.0-M7` → `**Spring AI Version:** 2.0.0-M8`. Use surgical edits — do NOT blanket-replace any other `M7` strings.

README.md needs a hand-written rewrite of the "Recently upgraded" callout (line 11) — replace the M6→M7 prose with an M7→M8 callout that highlights #6138 + #6164 + #6171 + #6150 and notes that the workshop's M7 workaround has been removed.

Commit:

```bash
git commit -m "docs: sweep workshop-version labels 2.0.0-M7 → 2.0.0-M8"
```

### Task 6: Pixel-art history timeline

Edit `spring-ai-history.html`:
- Retitle M7 entry (`'Where we are today'` → `'ToolCallAdvisor default + MCP SDK M3'`).
- Insert new M8 entry after M7 with `date:'2026-05-27'`, `title:'Where we are today'`, bullets covering the three M8 fix headlines.
- Bump `WORLD_END` 14840 → 15200, comment `37 entries → 38 entries`.
- Bump line 768 "M7 is the foundation" → "M8 is the foundation".

Commit:

```bash
git commit -m "feat(history): add v2.0.0-M8 to pixel-art timeline + retitle M7"
```

### Task 7: CHANGELOG `[2.3.7]` entry

Prepend a new entry at the top of `CHANGELOG.md` matching the shape of `[2.3.6]`. Sections: Changed (bump summary + workaround removal), Fixed upstream (the four M8 fixes), Other release-notes items not relevant here, Reactor verify + runtime smoke summary.

Commit:

```bash
git commit -m "docs(changelog): [2.3.7] — Spring AI M7 → M8"
```

### Task 8: Upgrade plan doc

Commit this file (`SPRING_AI_M7_TO_M8_UPGRADE_PLAN.md`):

```bash
git commit -m "docs: add Spring AI M7 → M8 upgrade plan"
```

### Task 9: Push + PR + tag + release + merge

- [ ] `git push -u origin chore/spring-ai-m8-bump`
- [ ] `gh pr create --title "chore(spring-ai): bump 2.0.0-M7 → 2.0.0-M8" --body "..."`
- [ ] After PR approval / final check: `git tag -a v2.3.7 -m "v2.3.7 — Spring AI 2.0.0-M8 (workaround removed)"`
- [ ] `git push origin v2.3.7`
- [ ] `gh release create v2.3.7 --title "..." --notes "..."`
- [ ] `gh pr merge <PR#> --merge` (preserves tag on main's history)
- [ ] `git push origin --delete chore/spring-ai-m8-bump && git branch -d chore/spring-ai-m8-bump`

---

## Part 5 — Verification

### Per-task verification commands

```bash
# After Task 2 — confirm exclude blocks are gone from all 6 providers
grep -rln "autoconfigure:" applications/provider-*/src/main/resources/application.yaml
# Expect: empty

# After Task 5 — confirm only history-page timeline data + new README callout still mention M7
grep -rln "2\.0\.0-M7" \
  --include="*.md" --include="*.xml" --include="*.html" \
  --include="*.yaml" --include="*.yml" --include="*.sh" \
  --include="*.json" --include="*.properties" --include="*.java" \
  --include="VERSION" . \
  | grep -v "/target/" | grep -v "/migration/" \
  | grep -v "SPRING_AI_M.*_TO_M.*" \
  | grep -v "CHANGELOG.md" | grep -v "/.git/" | grep -v "/superpowers/"
# Expect: only README.md (the new M7→M8 callout legitimately mentions M7 as "the prior version")
# and spring-ai-history.html (timeline data + foundation line — handled in Task 6).

# After Task 6 — both expected hits in history page resolved
# spring-ai-history.html should now only have the historical v2.0.0-M7 timeline entry around line 554.

# Final reactor verify
./mvnw clean verify
# Expect: BUILD SUCCESS, 42 modules
```

### Runtime smoke matrix (post-merge)

| Provider | Profile combo | Expected |
|---|---|---|
| OpenAI | `pgvector,observation,ui` | 200 on `/chat/02/client/joke` |
| Anthropic | `observation,ui` | 200 on `/chat/02/client/joke` |
| Azure | `pgvector,observation,ui` | Same |
| AWS | `observation,ui` | 200 on chat-only path |
| Google | `observation,ui` | 200, with the M8 fix #6171 the Google GenAI starter is cleaner |
| Ollama | `pgvector,observation,ui,spy` | Full local-only run + spy gateway |
| Stage 6 | dashboard | All 5 MCP demos work |
| `mcp/03-mcp-client` standalone | direct boot | Should boot now (was expected-to-fail on M7) |

---

## Part 6 — Recommended follow-ups (NOT done in this bump)

1. **Drop the now-redundant `<exclusions>` in `applications/provider-google/pom.xml`** — M8 #6171 means the `spring-ai-starter-model-google-genai` starter no longer pulls the embedding dep, so our explicit exclusion is dead code. Harmless but tidy to remove.

2. **Re-run the deferred manual smoke tests from the M6→M7 plan Tasks 4-8** with M8:
   - PgVector dimension validation (`embed/04/store` per pgvector provider)
   - `ToolCallAdvisor`-as-default Grafana span tree inspection
   - Stage 7 agentic E2E
   - Stage 6 MCP demos via dashboard
   - `provider-google` `dependency:tree` re-check (with M8's #6171 fix landed)

3. **Re-enable `mcp/03-mcp-client` for runtime smoke testing.** It was expected-to-fail under M7's packaging bug and should now boot. If any new issue surfaces in its `ToolCallbackProvider` injection, file a follow-up.

4. **Watch for the next Spring AI milestone (M9 / GA).** Particularly:
   - The M-series MCP Java SDK trajectory toward 1.0.0.
   - Whether any of the deferred follow-ups from prior bumps (rename `ClientSse.java`, document `ToolSpec`, document `ToolCallAdvisor` default in `SPRING_AI_INTRODUCTION.md`) land in the workshop.

5. **Re-test the `spy` gateway path** — unchanged from M7's caveat. If the openai-java SDK's base-URL handling changes in M9/GA, the gateway route logic may need adjusting again.

---

*Plan authored + executed: 2026-05-28. Author: workshop maintainer + Claude.*
