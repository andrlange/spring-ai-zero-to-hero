# Spring Version & Compatibility Documentation Gaps

> **What this is:** a record of places where the *official* Spring documentation (release notes, compatibility wikis) and *this project's own docs* fail to make version compatibility and version mappings discoverable — discovered while bumping the workshop to the GA stack (Spring Boot 4.1.0 · Spring AI 2.0.0 GA · Spring Cloud 2025.1.2) on 2026-06-15.
>
> **Why it matters:** for a teaching workshop, "which versions actually work together, and where do I confirm that?" is a first-class question. Several of the answers are not written down anywhere authoritative — you have to *infer* them from `start.spring.io` or *prove* them with a build. This doc captures each gap, the evidence, and the workaround.
>
> **Companion:** [`SPRING_AI_RC1_TO_GA_UPGRADE_PLAN.md`](SPRING_AI_RC1_TO_GA_UPGRADE_PLAN.md) — the upgrade itself, with the empirical build evidence referenced below.
>
> **Revisited 2026-08-23** while bumping to Spring Boot 4.1.1 · Spring AI 2.0.1 · Spring Cloud 2025.1.2 (workshop `v2.4.1`). Gap 1 partially closed, and a new **Gap 6** added: a *patch* version number that carries eleven breaking changes.

---

## TL;DR — the gaps

| # | Gap | Authoritative source that *would* answer it | Where it's actually (under)documented |
|---|---|---|---|
| 1 | Spring Cloud 2025.1.x ↔ Spring Boot **4.1.0** compatibility | Spring Cloud *Supported-Versions* wiki | Wiki still says "Boot **4.0.x**"; only `start.spring.io` reflects 4.1.0 |
| 2 | Spring AI **2.0.0-RC2** hotfix existence + contents | Spring AI GitHub *Releases* / GA release notes | GA notes never mention RC2; RC2 release is mis-labelled + hidden |
| 3 | GA release notes are a **non-cumulative delta** (skip RC2) | The GA release notes themselves | You must read RC1 **and** RC2 **and** GA to see the full picture |
| 4 | Maven Central `<latest>` can point at a **prerelease** | `maven-metadata.xml` | `<latest>` ≠ `<release>`; tooling that keys off "latest" can pick RC2 |
| 5 | Project docs assert the stack as **free-text banners** only | This repo's README / intro / OpenAPI metadata | No machine-checkable or linked compatibility evidence (improving) |
| 6 | Spring AI **2.0.1** is a *patch* that ships **11 breaking changes** | The 2.0.1 release notes | Breaking list lives only behind an *upgrade-notes* anchor; the notes themselves file it under "New Features" |

---

## Gap 1 — Spring Cloud ↔ Spring Boot 4.1.0 compatibility is undocumented

**The question:** does the latest Spring Cloud release train (2025.1.2) work with Spring Boot 4.1.0?

**What the official docs say:** the [Spring Cloud Supported-Versions wiki](https://github.com/spring-cloud/spring-cloud-release/wiki/Supported-Versions) maps the release trains to Spring Boot like this:

| Release Train | Spring Boot (per wiki) |
|---|---|
| **2025.1 (Oakwood)** | **4.0.x** |
| 2025.0 (Northfields) | 3.5.x |
| 2024.0 (Moorgate) | 3.4.x |

The wiki lists **4.0.x**, not 4.1.x. Taken literally, that says "don't use Spring Cloud 2025.1 with Boot 4.1.0." It is **stale** — the row reflects the train's *initial* `2025.1.0` baseline and was never refreshed when the `.1`/`.2` patches tracked Boot forward into the 4.1 line. The individual Spring Cloud **component reference docs** — Gateway, Eureka Server, Eureka Client, Config Server, Config Client, OpenFeign, Stream, Bus, Contract — **carry no per-component Boot compatibility matrix at all**, so there is no second source to cross-check.

**The only place the truth is visible:** `start.spring.io`. It offers **Spring Boot 4.1.0 together with Spring Cloud 2025.1.2**, and the Initializr only ever surfaces *mutually compatible* release-train ↔ Boot combinations. That co-selectability is a compatibility signal straight from Spring's own tooling — but it is *implicit* (you infer it from what the dropdowns allow), never *stated*.

**Empirical proof (this repo):** `./mvnw clean verify` on Boot 4.1.0 + Spring Cloud 2025.1.2 → **BUILD SUCCESS, 43 modules, all tests pass**, including the `gateway` module. Resolved on the classpath: `spring-cloud-gateway-server-webmvc:5.0.2`, `spring-boot-autoconfigure:4.1.0`, `spring-core:7.0.8`.

**Scope — this is train-wide, not Gateway-specific.** Spring Cloud ships as a *single* BOM/release train: one `spring-cloud-dependencies:2025.1.2` import version pins every component. So the Boot-4.1.0 compatibility we proved for Gateway applies uniformly to **Eureka Server, Eureka Client, Config Server, Config Client, OpenFeign, Stream, Bus, Gateway, Contract, …** — but, again, that uniformity is nowhere written down. A team adopting, say, Eureka + Config on Boot 4.1.0 gets no documented green light; they'd have to repeat the start.spring.io / build dance themselves.

**Update (2026-08-23) — partially closed.** The Initializr's own metadata (`https://start.spring.io/actuator/info`) now states the 2025.1.2 BOM range **explicitly**: Spring Boot `>=4.0.0` and `<4.2.0-M1`. That is a machine-readable compatibility statement, and it is why the 4.1.0 → **4.1.1** bump needed no Spring Cloud train change. The Supported-Versions wiki is *still* stale. So the gap narrows from "nowhere stated" to "stated only in an undocumented actuator endpoint that no release note points at".

**Workaround / how to verify:**
1. Open `start.spring.io` (or read `start.spring.io/actuator/info` directly for the declared BOM ranges), pick the Boot version, and confirm the Spring Cloud train is offered (and which patch).
2. Prove it with a build (`mvn -pl <cloud-module> -am verify`) and record the *resolved* component versions (`dependency:list`), not just the train number.
3. Treat the Supported-Versions wiki as a **lagging** indicator, not ground truth.

---

## Gap 2 — Spring AI 2.0.0-RC2 is a "hidden" hotfix release

**The question:** between RC1 and GA, was there an intermediate Spring AI release, and what did it change?

**Yes — `2.0.0-RC2`, published 2026-06-09**, three days before GA (2026-06-12). It is a genuine hotfix release and exists in all three "official" channels:

- **Git tag** `v2.0.0-RC2`
- **Maven Central** artifact `spring-ai-bom:2.0.0-RC2` (verified in `maven-metadata.xml`: `… RC1, RC2, 2.0.0`)
- **GitHub Release** entry (published 2026-06-09, `prerelease=true`)

**…yet it is effectively invisible:**

1. **The GA release notes never mention it.** The `v2.0.0` GA notes read as a direct **RC1 → GA** delta — grepping the GA release body for `RC2`/`RC1`/`hotfix`/`regression` returns **nothing**. A reader following the GitHub releases sees `M8 → RC1 → GA` and has no signal that RC2 happened or that its fixes are folded into GA.
2. **The RC2 release is mis-labelled.** Every other Spring AI release is named `Spring AI 2.0.0-RC1`, `Spring AI 2.0.0 GA`, `Spring AI 2.0.0-M8`, … but the RC2 release `name` is the bare string **`2.0.0-RC2`** (no `Spring AI` prefix). It sorts and reads differently from its siblings.
3. **It's a `prerelease`, hidden behind the "Latest" badge.** GitHub pins the GA "Latest" badge and collapses prereleases, so RC2 sits below the fold.

**What actually shipped in RC2 (folded silently into GA, absent from GA notes):**

- **Restore compatibility with Spring Framework < 7.0.4** (#6334) — a real compatibility fix.
- **Always auto-register `ToolCallingAdvisor` to support runtime-injected tools** (#6349) — **directly relevant to this workshop's Stage 6 `mcp/04-dynamic-tool-calling`** (tools registered at runtime).
- **Restore options *replacing* instead of *merging* in `ChatModel`** (#6336) — a behavioural fix to option handling.
- **Bedrock fixes:** `BedrockProxyChatModel` option handling (#6370), `spring-ai-autoconfigure-model-bedrock-ai` deps (#6368), and an **RC1 regression** needing an extra Bedrock SDK dep (#6367).
- Make Anthropic / OpenAI HTTP client configurable (#6354 / #6294).
- Replay `reasoning_content` in OpenAI assistant history (#6296); `OllamaChatModel` thinking-content fix.

These are not cosmetic — `#6334` (Framework compat), `#6349` (runtime tools), and `#6336` (option semantics) all change behaviour, and a team that read only "RC1 → GA" would never know to look for them.

**The `start.spring.io` angle:** Initializr resolves the Spring AI BOM version **server-side** and never exposes it in the generated POM's *human-readable* metadata, release notes, or any published matrix. During the **June 9–12 window**, the "latest Spring AI" that Initializr would pin was **`2.0.0-RC2` — a prerelease, not GA**. So a project generated in that window silently depended on RC2, and there was no documentation telling you that "latest" meant "a release candidate that the GA notes don't describe."

**Workaround / how to verify the *real* latest GA:**
- Check Maven Central `maven-metadata.xml` and read **`<release>`** (the stable pointer) — currently `2.0.0`. Do **not** trust the GitHub "latest tag," a release `name`, or `start.spring.io`'s server-side pin to tell you GA-vs-prerelease.
- To understand a GA, read the prerelease notes *between* the last milestone you were on and GA (here: **RC1 + RC2**), not just the GA page.

---

## Gap 3 — GA release notes are a non-cumulative delta

Generalising Gap 2: each Spring AI release's notes document only the delta from the **immediately preceding tag**, and the GA notes specifically skip the RC2 intermediate. There is **no single "everything that changed since M8/RC1 → GA" cumulative changelog** on the GitHub releases. Spring AI does publish *consolidated upgrade notes* (#6333), but they live in the **reference documentation**, separate from the GitHub Releases stream most people read first — so the two surfaces disagree on completeness, and neither cross-links to RC2.

**Consequence for upgraders:** "read the GA release notes" is *insufficient* to know what you're getting. You must stitch together RC1 + RC2 + GA, or find the reference-doc upgrade notes.

---

## Gap 4 — Maven Central `<latest>` can point at a prerelease

`spring-ai-bom/maven-metadata.xml` exposes two pointers:

```xml
<latest>2.0.0</latest>     <!-- "most recently published" — can be a prerelease -->
<release>2.0.0</release>   <!-- "most recent STABLE/GA" -->
```

They happen to match **now**, but during **June 9–12** `<latest>` was `2.0.0-RC2` while `<release>` was still `2.0.0-RC1` (RC2 is a prerelease, so it advanced `<latest>` but not `<release>`). Any tooling, script, or "use the latest" heuristic that keys off `<latest>` (or "newest tag") would have selected **RC2**. The GA-safe field is **`<release>`** — but this distinction is a Maven convention, not something the Spring docs call out.

**Workaround:** in automation, resolve stable versions from `<release>`, never `<latest>`; or pin explicitly.

---

## Gap 5 — This project's own docs assert the stack as free-text only

The workshop's *own* documentation states its stack as prose banners — e.g. README's `Spring Boot 4.1.1 | Spring AI 2.0.1 | Java 25`, the `SPRING_AI_INTRODUCTION.md` header, and `OpenApiConfig`'s tech-stack string. These are:

- **not machine-checkable** (nothing fails if a banner drifts from the actual resolved version), and
- **not linked to an authoritative compatibility source** (no pointer to start.spring.io / the build evidence).

This is the *project-documentation* face of the same problem: a reader can't tell whether "Boot 4.1.1 | Spring AI 2.0.1" is a *verified-compatible* combination or just an aspiration.

**What we're doing about it (the good pattern to keep):** the `SPRING_AI_*_UPGRADE_PLAN.md` docs now record the **empirically resolved** versions straight from `dependency:list` after a green `clean verify` (e.g. `spring-cloud-gateway-server-webmvc:5.0.2`, `spring-boot:4.1.1`, `spring-core:7.0.9`, `spring-ai-openai:2.0.1`, `mcp:2.0.0`). That turns "the banner claims X" into "the build resolved X and passed," which is the evidence the official docs omit.

---

## Gap 6 — a *patch* release that ships eleven breaking changes

**The question:** is it safe to take Spring AI `2.0.0` → `2.0.1` without reading anything?

Under any normal reading of semantic versioning, yes — the patch digit moved. In fact **2.0.1 ships eleven documented breaking changes**, several of which are *silent behavioural* changes rather than compile errors:

- fallback tool resolution **disabled by default** (#6751) — bean-registered tools that were never attached to a request simply stop being callable, at runtime, with no compile-time signal;
- `DefaultToolCallingManager` now **caps** tool calls at 40 per tool / 150 total (#6726) — a long agent loop that used to finish now throws `ToolCallLimitExceededException`;
- `OpenAiChatModel` no longer forces `strict(true)` tool schemas (#6755) — the request payload changes shape;
- `ToolCallingAdvisor` **accumulates** token usage across the tool loop (#6424) — every dashboard, alert or cost calculation keyed on reported usage shifts upward.

A project that upgrades on the strength of the version number alone gets none of these warnings. Nothing fails to compile.

**Where the information actually lives — and doesn't:**

| Surface | What it tells you |
|---|---|
| GitHub release `v2.0.1` | A flat list of ~90 PR titles under **New Features / Bug Fixes / Documentation / Dependency Upgrades**. The breaking changes are *scattered through those four sections*, indistinguishable from routine fixes — "Make tool resolution fallback configurable" reads like a feature, not a default flip |
| The one-line pointer at the top of the release notes | A link to `upgrade-notes.html#upgrading-to-2-0-1` — the **only** place the eleven are enumerated as breaking |
| A PR *titled* "Document additional 2.0.1 breaking changes" (#6771) | Filed under **:star: New Features**, next to "Harden Ollama integration tests" |
| The version number `2.0.1` | Nothing. It actively misleads |

**Why it matters:** the upgrade-notes page is good — thorough, with before/after code. The gap is *discoverability and signalling*: nothing in the version string, the release title, or the section headings tells a reader that this particular patch needs the migration guide. Compare Gap 3 (GA notes being a non-cumulative delta): same root cause, different surface — the release notes are organised by *change type*, never by *blast radius*.

**Workaround:** treat **every** Spring AI version bump — patch included — as requiring a read of `upgrade-notes.html`, and grep your own source for each listed item rather than trusting the version digit. This repo now does that as a standing step in the bump workflow; the audit table lives in [`SPRING_AI_GA_TO_2_0_1_UPGRADE_PLAN.md`](SPRING_AI_GA_TO_2_0_1_UPGRADE_PLAN.md) Part 1.

---

## Practical playbook — how to actually pin a compatible Spring stack

Because the official surfaces are incomplete, use this order of trust:

1. **`start.spring.io`** — for *which trains co-exist* (Boot ↔ Spring Cloud ↔ Spring AI). Authoritative for compatibility, implicit about exact versions.
2. **Maven Central `maven-metadata.xml` → `<release>`** — for *what the latest GA actually is* (immune to prerelease "latest" confusion).
3. **A real `clean verify` + `dependency:list`** — for *what your project actually resolves*, recorded as evidence.
4. **Release notes** — for *what changed*, but read **every** intermediate prerelease since your current version, not just the GA page. For Spring AI specifically, always open `upgrade-notes.html` for the target version **even on a patch bump** (Gap 6).
5. **Compatibility wikis** — last, and only as a *lagging* hint; assume they trail the latest patch line.

---

*Authored 2026-06-15 alongside the RC1 → GA bump; revisited 2026-08-23 alongside the 2.0.0 → 2.0.1 / Boot 4.1.0 → 4.1.1 bump (Gap 1 update, Gap 6 added). Findings 1–2 reported by the workshop maintainer; 3–6 surfaced during verification. Evidence: Spring AI / Spring Cloud `maven-metadata.xml`, GitHub Releases API (`gh api`), the Spring Cloud Supported-Versions wiki, and this repo's reactor build.*
