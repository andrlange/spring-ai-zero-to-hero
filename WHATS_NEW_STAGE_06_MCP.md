# What's New — Stage 6: Model Context Protocol (MCP)

> A walkthrough of the Stage 6 chapter for workshop attendees and trainers.
> Covers what MCP is, how each of the five demos works, how to run them from the dashboard **or** the command line, and what to demonstrate in what order.

## TL;DR

Stage 6 used to be CLI-only. Now it's the same five demos (01–05) — each is still a separate Spring Boot application you can launch from Maven — but they're also **runnable, inspectable, and invokable from the workshop dashboard** at `http://localhost:8080/dashboard/stage/6`, with a single coordinated lifecycle script.

```bash
./workshop.sh start ollama ui       # provider app + dashboard
./workshop.sh mcp start all         # builds 01 jar, starts 02 (:8081), 04 (:8082), 05 (:8083)
open http://localhost:8080/dashboard/stage/6
```

Five cards, live status pills, clickable **List tools / Invoke / List resources / List prompts / Run demo / Trigger dynamic registration / Docs** buttons, a dark/light theme toggle you already get from 2.2.2, and a one-stop curl cheatsheet next to every form.

---

## What is MCP?

**MCP** (Model Context Protocol) is an open standard from Anthropic that standardizes how AI applications find and use external tools, data, and prompt templates. Before MCP, every integration was bespoke — hardcoded function bindings, custom RPC, glue code per vendor. MCP gives you one protocol that any client (Claude Desktop, Cursor, custom ChatClient apps, your own Spring AI code) can speak to any server.

The four capabilities an MCP server can advertise:

| Capability | What it is | Spring AI annotation |
|------------|------------|----------------------|
| **Tools** | Executable functions the model can call with structured args | `@Tool` + `@ToolParam` |
| **Resources** | Readable data the model can fetch (files, profiles, records, anything URI-addressable) | `@McpResource` |
| **Prompts** | Reusable prompt templates with typed arguments | `@McpPrompt` + `@McpArg` |
| **Completions** | Autocomplete suggestions for resource URIs and prompt arguments | `@McpComplete` |

Two transports:

| Transport | When to use | Starter |
|-----------|-------------|---------|
| **STDIO** — stdin/stdout, JSON-RPC over piped streams | Local desktop integrations, CLI tools spawned as subprocesses (e.g. Claude Desktop launching an MCP server per conversation) | `spring-ai-starter-mcp-server` |
| **Streamable HTTP** — HTTP POST to `/mcp` | Remote servers, networked microservice-style access | `spring-ai-starter-mcp-server-webmvc` |

Stage 6 gives you one demo each (01 STDIO, 02 HTTP), a client (03), a dynamic-registration example (04), and a full-capabilities showcase (05).

---

## The Five Demos at a Glance

| # | Module | What it shows | Port | Transport |
|---|--------|---------------|------|-----------|
| **01** | `mcp/01-mcp-stdio-server/` | Weather tools exposed via STDIO. Subprocess spawned per call. | — | STDIO |
| **02** | `mcp/02-mcp-http-server/` | Same tool, HTTP transport. Shows that Spring AI tool code is transport-agnostic. | 8081 | Streamable HTTP |
| **03** | `mcp/03-mcp-client/` | A `ChatClient` using MCP-discovered tools. Two modes: **local** (01+02) and **external** (Brave + filesystem). | — | client |
| **04** | `mcp/04-dynamic-tool-calling/` | Register new tools at runtime via `McpSyncServer.addTool()` after the server starts. | 8082 | Streamable HTTP |
| **05** | `mcp/05-mcp-capabilities/` | Full MCP: tools + resources + prompts + completions. Declarative via `@McpResource`/`@McpPrompt`. | 8083 | Streamable HTTP |

The progression is deliberate: each demo introduces exactly one new idea building on the previous.

---

## Recommended Walkthrough (for trainers and first-time attendees)

### 1. Start everything (once)

```bash
./workshop.sh start ollama ui        # provider app with dashboard
./workshop.sh mcp start all          # build 01 jar + start 02/04/05
./workshop.sh mcp status             # confirm everything is up
```

Open the dashboard in a browser: `http://localhost:8080/dashboard/stage/6`.

You'll see five demo cards, each with a live status pill (green = running). Port legend at the top, `./workshop.sh mcp` cheatsheet right next to it.

### 2. Demo 01 — STDIO server

> **Concept to land:** an MCP server can be any program that speaks JSON-RPC over stdin/stdout. No port, no HTTP, no framework beyond what's needed to read/write lines.

1. Click **List tools** on the 01 card → modal opens, spawns the jar as a subprocess for this one call, prints `getTemperature`.
2. Expand **Invoke** under the tool → the form has three args (`latitude`, `longitude`, `city`), all marked optional with example hints inline.
3. Submit `city=Berlin` only → the server geocodes Berlin → fetches the weather → returns `{resolvedLocation, latitude, longitude, temperatureCelsius, note}`.
4. Note the `Curl` line below the Submit button — copy it and show attendees the same call works from a terminal.
5. Look at the response time (~1–2s) and explain it's cold-start overhead: the jar is spawned, initialized, called, torn down per request. That's the STDIO lifecycle.

### 3. Demo 02 — Same tool, HTTP transport

> **Concept to land:** swapping STDIO for HTTP is a single config line (`protocol: STREAMABLE`) and a different starter dependency. **The tool code is unchanged.**

1. Click **List tools** on 02 → same `getTemperature`.
2. Invoke it (use different inputs from 01, e.g. `city=Tokyo`).
3. Compare response times: 02 is instant because there's a long-lived HTTP connection. 01 was slower per call because every call spawned a process.
4. Show the `diff mcp/01-mcp-stdio-server/src/main/java/com/example/WeatherTools.java mcp/02-mcp-http-server/src/main/java/com/example/WeatherTools.java` output — **identical**.
5. Only differences: `pom.xml` (different starter) and `application.yaml` (transport config).

### 4. Demo 03 — MCP client

> **Concept to land:** MCP client code is agnostic to *which* servers are backing the tools. Same `ChatClient.toolCallbacks(provider)` call, different server set behind the scenes.

1. Click **Run demo (local)** on the 03 card.
2. Wait ~3–5s (Ollama needs to round-trip): attendee sees question + answer chat bubbles, plus a `tools from: 01+02` badge showing which servers contributed tools.
3. Because both 01 and 02 expose `getTemperature`, the dashboard enables a prefix generator (`DefaultMcpToolNamePrefixGenerator`) so the model sees them as two distinct tools — `basic-stdio-mcp-server_getTemperature` and `basic-http-mcp-server_getTemperature`. Worth showing the **Raw response** collapsible for attendees who want to see the tool_call the model actually made.
4. **External mode** (Brave + filesystem via `npx`) is CLI-only — the dashboard returns HTTP 400 and points at `./mvnw spring-boot:run -pl mcp/03-mcp-client -Dspring-boot.run.profiles=mcp-external`. Mention it, don't demo it unless someone has `BRAVE_API_KEY` set.

### 5. Demo 04 — Dynamic tool registration

> **Concept to land:** MCP servers aren't static. You can register new tools at runtime on a running server via `McpSyncServer.addTool()` — the MCP spec includes a change-notification so connected clients re-list automatically.

1. Click **List tools** on 04 → shows one tool (`weatherForecast`).
2. Click **Trigger dynamic registration** → the dashboard POSTs to `http://localhost:8082/updateTools`, which fires a `CountDownLatch` in the server that runs `mcpSyncServer.addTool(...)` for the three `MathTools` methods (`sumNumbers`, `multiplyNumbers`, `divideNumbers`).
4. Click **List tools** again → now shows **four** tools.
5. Invoke `sumNumbers` with `number1=3, number2=5` → `8`. Invoke the original `weatherForecast` too — old tool still works, new tools stack alongside.
6. Caveat worth calling out: the server uses a one-shot `CountDownLatch`, so Trigger only registers once per server process. To reset: `./workshop.sh mcp stop 04 && ./workshop.sh mcp start 04`.

### 6. Demo 05 — Full MCP capabilities

> **Concept to land:** MCP is more than tools. Resources expose data, prompts are reusable templates, completions power IDE-like autocomplete. Spring AI makes all four declarative.

1. Click **List tools** → two tools from `api.weather.gov`: `getWeatherForecastByLocation` (US lat/lon) and `getAlerts` (US 2-letter state code). The `getAlerts` parameter description enumerates all 50 state codes inline so attendees pick valid values.
2. Click **List resources** → modal shows **0 concrete resources, 9 URI templates**. Explain the JSON-RPC split: the MCP spec has two separate calls (`resources/list` vs `resources/templates/list`) — the dashboard merges them. Walk through a few templates:
   - `user-profile://{username}` — full profile text
   - `user-attribute://{username}/{attribute}` — single field (name, email, age, location)
   - `user-status://{username}` — icon-style status (🟢 🟠 ⚪ 🔴)
   - `user-avatar://{username}` — BLOB with `mimeType: image/png`
   Known usernames: `john`, `jane`, `bob`, `alice`.
3. Click **Read** on `user-profile://{username}` after changing it to `user-profile://alice`. Response is a `ReadResourceResult` with text content.
4. Click **List prompts** → shows prompts with typed `@McpArg` parameters. Try **`personalized-message`** with `name=Alice, age=28, interests="AI, hiking"`.
5. (Completions are registered but not surfaced in the dashboard UI — mention that the protocol supports them and link to `AutocompleteProvider.java` for trainers who want to dive into it.)

### 7. Stop everything

```bash
./workshop.sh mcp stop all           # stop 02/04/05
./workshop.sh stop                   # also stops the provider app + infra
```

---

## UI vs CLI — Two Equivalent Workflows

| Task | Dashboard | CLI |
|------|-----------|-----|
| Start 02 | N/A — must be running already | `./workshop.sh mcp start 02` |
| List tools on 02 | Click **List tools** on 02's card | `curl http://localhost:8080/dashboard/mcp/02/tools` |
| Invoke `getTemperature` | Invoke form in modal | See `SPRING_AI_STAGE_6.md § Demo 02 — Curl equivalents` |
| Run 03 demo (local) | Click **Run demo (local)** | `./mvnw spring-boot:run -pl mcp/03-mcp-client` |
| Trigger 04 dynamic registration | Click **Trigger dynamic registration** | `curl http://localhost:8082/updateTools` |
| Open Stage 6 doc | Click **Docs** on any card | `open docs/spring-ai/SPRING_AI_STAGE_6.md` |
| Stop 02 | N/A | `./workshop.sh mcp stop 02` |

Every dashboard form has a **live curl line** below it — as you edit inputs, the curl command rebuilds, and **Copy** puts it on your clipboard. Same pattern as stages 1–5.

---

## Trainer Notes

### Time budget (approximate)

| Phase | Minutes |
|-------|---------|
| Start infra + MCP servers | 2 |
| Demo 01 (STDIO) | 5 |
| Demo 02 (HTTP) + 01/02 diff | 5 |
| Demo 03 (client) | 7 |
| Demo 04 (dynamic) | 7 |
| Demo 05 (capabilities) | 10 |
| Q&A | 5–10 |
| **Total** | **40–45** |

### Things attendees commonly ask

- **"Why doesn't external mode work from the dashboard?"** — Dashboard can't safely spawn arbitrary `npx` subprocesses with user-supplied commands, and `BRAVE_API_KEY` isn't something the dashboard manages. CLI path exists for attendees who want to try it.
- **"Why does 01 take 1–2 seconds per call but 02 is instant?"** — STDIO is subprocess-per-call; HTTP is long-lived connection. Pedagogically accurate tradeoff.
- **"Why does 04 show a 503 on `/actuator/health` on first status poll?"** — Server's `CountDownLatch` blocks Spring context readiness until `/updateTools` fires. The dashboard uses a TCP-port probe instead of HTTP health to avoid the false negative.
- **"What happens if two MCP servers expose the same tool name?"** — `DefaultMcpToolNamePrefixGenerator` prefixes each tool with the server's implementation name. The LLM sees two distinct tools; you're not forced to rename anything.
- **"Why are there no concrete resources in 05?"** — Because the `@McpResource` annotations all use URI templates (`user-profile://{username}`). Templates go in `resources/templates/list`, concrete go in `resources/list`. The dashboard calls both.

### Live-demo pitfalls to avoid

- **Don't** start the provider app on a different port than 8080 — the dashboard assumes 8080 for its own API.
- **Don't** forget to run `./workshop.sh mcp build-01` before demoing 01 — without the jar, the status pill stays muted and the Invoke button is disabled.
- **Don't** press **Trigger dynamic registration** twice in a row without restarting 04 — it's a no-op the second time (one-shot latch). If you need to re-demo, `./workshop.sh mcp stop 04 && start 04`.
- **Do** start `./workshop.sh mcp start all` *before* opening the dashboard — status polling will otherwise show everything muted for the first 3 seconds (harmless, but looks weird on a projector).

### Gateway spy profile — **not** for MCP

The Stage 1–5 `spy` profile routes chat traffic through a gateway at `:7777` for inspection. **MCP traffic does not flow through the spy gateway** — MCP clients talk JSON-RPC directly to each server on its own port. Use the dashboard's inspector modal + curl lines to observe MCP traffic instead.

---

## Troubleshooting Quick Reference

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| 01 status pill stays muted | Jar not built | `./workshop.sh mcp build-01` |
| 02/04/05 pill stays muted | Server not started | `./workshop.sh mcp start NN` |
| `Port 8081 already in use` | Stale process | `lsof -ti:8081 \| xargs kill` |
| 04 Trigger button does nothing | One-shot latch already fired | `./workshop.sh mcp stop 04 && ./workshop.sh mcp start 04` |
| 03 Run demo returns `degraded: true` | `ChatClient.Builder` not on classpath (provider app not running with a chat starter) | Restart via `./workshop.sh start <provider> ui` |
| 05 Read resource returns 404 | URI still has `{placeholder}` | Replace with a known username (`john`, `jane`, `bob`, `alice`) |
| 05 getAlerts returns 404 | `state` is empty or not a US code | Use one of AL, AK, AZ…WY, DC, PR |

Full section in `docs/troubleshooting.md § Stage 6 / MCP`.

---

## Deeper Reading

| Resource | Purpose |
|----------|---------|
| [`docs/spring-ai/SPRING_AI_STAGE_6.md`](docs/spring-ai/SPRING_AI_STAGE_6.md) | Canonical deep dive — per-demo flow diagrams, key code, MCP JSON-RPC endpoints, curl equivalents, resource catalog |
| [`docs/guide.md`](docs/guide.md) — Stage 6 section | Concise module table + `workshop.sh mcp` commands |
| [`mcp/*/README.md`](mcp/) | Per-module quickstart with the "New in Stage 6 UI" intro box |
| [`docs/troubleshooting.md`](docs/troubleshooting.md) | Stage 6 / MCP troubleshooting section |
| [MCP specification](https://modelcontextprotocol.io/) | Upstream protocol spec |
| [Spring AI MCP docs](https://docs.spring.io/spring-ai/reference/api/mcp/mcp-overview.html) | Spring AI's MCP starter reference |

---

## Implementation Highlights (for trainers curious about the UI internals)

The Stage 6 dashboard is built on the existing workshop dashboard stack (Thymeleaf + Bootstrap 5 + vanilla JS). Key Spring AI 2.0.0-M4 APIs used:

- **`McpClient.sync(transport).requestTimeout(…).build()`** — caller-managed client for 02/04/05 (long-lived) and 01 (per-request spawn).
- **`HttpClientStreamableHttpTransport.builder(baseUrl).endpoint("/mcp")`** — HTTP client transport. No SSE anywhere in this codebase.
- **`StdioClientTransport(ServerParameters, McpJsonDefaults.getMapper())`** — STDIO subprocess transport. 2-arg constructor in MCP SDK 1.1.x.
- **`SyncMcpToolCallbackProvider.builder().mcpClients(list).toolNamePrefixGenerator(new DefaultMcpToolNamePrefixGenerator()).build()`** — wraps live `McpSyncClient` instances into a `ToolCallbackProvider` that `ChatClient.toolCallbacks(...)` accepts, with automatic name disambiguation when multiple servers expose the same tool.
- **`SyncMcpAnnotationProviders.resourceSpecifications(...)` / `.promptSpecifications(...)` / `.completeSpecifications(...)`** — server-side declarative capability registration from `@McpResource` / `@McpPrompt` / `@McpComplete` annotated beans.

See `components/config-dashboard/src/main/java/com/example/dashboard/mcp/` for the backend, `components/config-dashboard/src/main/resources/templates/stage/mcp.html` + `fragments/mcp-card.html` + `static/js/mcp.js` for the frontend.
