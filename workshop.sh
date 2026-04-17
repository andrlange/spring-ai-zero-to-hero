#!/usr/bin/env bash
# ============================================================
# workshop.sh — Spring AI Zero-to-Hero Workshop Helper
#
# Tech Stack: Spring Boot 4.0.5 | Spring AI 2.0.0-M4 | Java 25
#
# Compatibility: macOS (bash 3.2+) and Linux (bash 4+).
# Always invoked via bash shebang — works regardless of login shell.
#
# Usage:
#   ./workshop.sh               # Interactive TUI menu
#   ./workshop.sh <command>     # CLI mode
# ============================================================

set -euo pipefail

# ── Colors ──────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ── Helpers ──────────────────────────────────────────────────
ok()   { echo -e "  ${GREEN}✅${NC} $*"; }
fail() { echo -e "  ${RED}❌${NC} $*"; }
warn() { echo -e "  ${YELLOW}⚠️${NC}  $*"; }
info() { echo -e "  ${BLUE}ℹ️${NC}  $*"; }
header() { echo -e "\n${BOLD}${CYAN}$*${NC}"; }

# ── Health check helper ─────────────────────────────────────
app_is_ready() {
    # Try actuator health first, then OpenAPI docs, then swagger redirect
    curl -sf http://localhost:8080/actuator/health &>/dev/null && return 0
    curl -sf http://localhost:8080/v3/api-docs &>/dev/null && return 0
    curl -sf -o /dev/null -w '' http://localhost:8080/swagger-ui.html &>/dev/null && return 0
    return 1
}

# ─────────────────────────────────────────────────────────────
# MCP helpers — process lifecycle for mcp/ demos
# ─────────────────────────────────────────────────────────────
MCP_STATE_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}/.workshop/mcp"
MCP_DEMOS=(02 04 05)           # long-running demos; 01 is jar-build only
MCP_ALL_DEMOS=(01 02 04 05)    # 03 is a CLI runner, not a server

# bash 3.2 compatibility: no associative arrays — use case-based lookup helpers
mcp_port_for() {
    case "$1" in
        02) echo 8081 ;;
        04) echo 8082 ;;
        05) echo 8083 ;;
        *)  echo "" ;;
    esac
}

mcp_module_for() {
    case "$1" in
        01) echo "mcp/01-mcp-stdio-server" ;;
        02) echo "mcp/02-mcp-http-server" ;;
        04) echo "mcp/04-dynamic-tool-calling/server" ;;
        05) echo "mcp/05-mcp-capabilities" ;;
        *)  echo "" ;;
    esac
}

mcp_label_for() {
    case "$1" in
        01) echo "STDIO Server" ;;
        02) echo "HTTP Server" ;;
        04) echo "Dynamic Tool Calling (server)" ;;
        05) echo "Full Capabilities" ;;
        *)  echo "?" ;;
    esac
}

MCP_STDIO_JAR="mcp/01-mcp-stdio-server/target/01-mcp-stdio-server-0.0.1-SNAPSHOT.jar"

mcp_pid_file() { echo "${MCP_STATE_DIR}/${1}.pid"; }
mcp_log_file() { echo "${MCP_STATE_DIR}/${1}.log"; }

mcp_ensure_state_dir() {
    mkdir -p "${MCP_STATE_DIR}"
}

mcp_is_up() {
    local id="$1"
    local port
    port=$(mcp_port_for "${id}")
    [ -z "${port}" ] && return 1
    # TCP port-bound probe (not /actuator/health — 04 returns 503 until latch fires)
    if command -v nc &>/dev/null; then
        nc -z localhost "${port}" &>/dev/null
    else
        (echo > "/dev/tcp/localhost/${port}") &>/dev/null
    fi
}

mcp_stdio_jar_present() {
    [ -f "${SCRIPT_DIR}/${MCP_STDIO_JAR}" ]
}

mcp_build_01_jar() {
    header "Building 01 STDIO jar"
    echo -e "  ${CYAN}→${NC} ./mvnw package -DskipTests -pl mcp/01-mcp-stdio-server -am"
    if "${SCRIPT_DIR}/mvnw" package -DskipTests -pl mcp/01-mcp-stdio-server -am -q -f "${SCRIPT_DIR}/pom.xml"; then
        ok "01 jar built at ${MCP_STDIO_JAR}"
    else
        fail "01 jar build failed"
        return 1
    fi
}

mcp_port_in_use() {
    local port="$1"
    if command -v lsof &>/dev/null; then
        lsof -ti:"${port}" &>/dev/null
    elif command -v ss &>/dev/null; then
        ss -tlnp 2>/dev/null | grep -q ":${port} "
    else
        return 1
    fi
}

mcp_start_demo() {
    local id="$1"
    local port module label
    port=$(mcp_port_for "${id}")
    module=$(mcp_module_for "${id}")
    label=$(mcp_label_for "${id}")

    if [ -z "${port}" ] || [ -z "${module}" ]; then
        fail "Unknown MCP demo: ${id}"
        return 1
    fi

    mcp_ensure_state_dir

    if mcp_is_up "${id}"; then
        ok "MCP ${id} (${label}) already running on port ${port}"
        return 0
    fi

    if mcp_port_in_use "${port}"; then
        fail "Port ${port} already in use"
        info "Free the port: lsof -ti:${port} | xargs kill"
        return 1
    fi

    local log_file
    log_file=$(mcp_log_file "${id}")
    header "Starting MCP ${id} (${label}) on port ${port}"
    echo -e "  ${CYAN}→${NC} ./mvnw spring-boot:run -pl ${module}"
    echo -e "  ${CYAN}→${NC} logs: ${log_file}"

    (
        "${SCRIPT_DIR}/mvnw" spring-boot:run \
            -pl "${module}" \
            -f "${SCRIPT_DIR}/pom.xml" \
            > "${log_file}" 2>&1
    ) &
    local pid=$!
    echo "${pid}" > "$(mcp_pid_file "${id}")"

    echo -e "  ${CYAN}→${NC} Waiting for MCP ${id} on port ${port}..."
    local attempts=0
    while [ "${attempts}" -lt 60 ]; do
        if mcp_is_up "${id}"; then
            ok "MCP ${id} ready (PID ${pid})"
            return 0
        fi
        if ! kill -0 "${pid}" 2>/dev/null; then
            fail "MCP ${id} process exited unexpectedly — see ${log_file}"
            rm -f "$(mcp_pid_file "${id}")"
            return 1
        fi
        sleep 2
        attempts=$((attempts + 1))
    done
    warn "MCP ${id} startup timed out — check ${log_file}"
    return 1
}

mcp_stop_demo() {
    local id="$1"
    local pid_file port
    pid_file=$(mcp_pid_file "${id}")
    port=$(mcp_port_for "${id}")

    if [ ! -f "${pid_file}" ]; then
        if mcp_is_up "${id}"; then
            warn "MCP ${id} is up but no PID file — sweeping port ${port}"
            if command -v lsof &>/dev/null; then
                local orphan_pids
                orphan_pids=$(lsof -ti:"${port}" 2>/dev/null || true)
                if [ -n "${orphan_pids}" ]; then
                    echo "${orphan_pids}" | xargs kill -9 2>/dev/null || true
                    ok "MCP ${id} stopped (port ${port} swept)"
                fi
            else
                info "lsof not available — cannot sweep port ${port}"
            fi
        else
            info "MCP ${id} not running"
        fi
        return 0
    fi

    local pid
    pid=$(cat "${pid_file}")
    if kill -0 "${pid}" 2>/dev/null; then
        # Kill the entire process group (mvnw + forked JVM)
        kill -- -"${pid}" 2>/dev/null || kill "${pid}" 2>/dev/null || true
        # Wait briefly for graceful shutdown
        local waited=0
        while kill -0 "${pid}" 2>/dev/null && [ "${waited}" -lt 10 ]; do
            sleep 1
            waited=$((waited + 1))
        done
        if kill -0 "${pid}" 2>/dev/null; then
            kill -9 -- -"${pid}" 2>/dev/null || kill -9 "${pid}" 2>/dev/null || true
        fi
        ok "MCP ${id} stopped (PID ${pid})"
    else
        info "MCP ${id} process already gone"
    fi

    # Port-bound sweep — catches orphaned JVM children the process-group kill missed
    if command -v lsof &>/dev/null; then
        local port_pids
        port_pids=$(lsof -ti:"${port}" 2>/dev/null || true)
        if [ -n "${port_pids}" ]; then
            echo "${port_pids}" | xargs kill -9 2>/dev/null || true
        fi
    fi

    rm -f "${pid_file}"
}

mcp_status_table() {
    header "MCP demo status"
    printf "  %-4s %-34s %-6s %-7s %s\n" "ID" "Demo" "Port" "Up?" "PID"
    printf "  %-4s %-34s %-6s %-7s %s\n" "──" "──────────────────────────────" "────" "───" "─────"
    for id in "${MCP_ALL_DEMOS[@]}"; do
        local port label
        port=$(mcp_port_for "${id}")
        [ -z "${port}" ] && port="n/a"
        label=$(mcp_label_for "${id}")
        local pid_file
        pid_file=$(mcp_pid_file "${id}")
        local pid="—"
        [ -f "${pid_file}" ] && pid=$(cat "${pid_file}")
        local up="—"
        if [ "${id}" = "01" ]; then
            mcp_stdio_jar_present && up="jar ✓" || up="jar ✗"
            port="stdio"
        else
            mcp_is_up "${id}" && up="✓" || up="✗"
        fi
        printf "  %-4s %-34s %-6s %-7s %s\n" "${id}" "${label}" "${port}" "${up}" "${pid}"
    done
    echo ""
}

cmd_mcp() {
    local action="${1:-}"
    shift || true

    case "${action}" in
        start)
            if [ $# -eq 0 ]; then
                fail "Usage: ./workshop.sh mcp start <id>|all"
                return 1
            fi
            local rc=0
            for target in "$@"; do
                case "${target}" in
                    all)
                        mcp_build_01_jar
                        for id in "${MCP_DEMOS[@]}"; do mcp_start_demo "${id}" || true; done
                        ;;
                    01)
                        mcp_build_01_jar
                        ;;
                    02|04|05)
                        mcp_start_demo "${target}"
                        ;;
                    *)
                        fail "Unknown MCP id: ${target} (expected 01|02|04|05|all)"
                        rc=1
                        ;;
                esac
            done
            return ${rc}
            ;;
        stop)
            if [ $# -eq 0 ]; then
                fail "Usage: ./workshop.sh mcp stop <id>|all"
                return 1
            fi
            local rc=0
            for target in "$@"; do
                case "${target}" in
                    all) for id in "${MCP_DEMOS[@]}"; do mcp_stop_demo "${id}"; done ;;
                    02|04|05) mcp_stop_demo "${target}" ;;
                    01) info "01 is STDIO — nothing to stop (no long-running process)" ;;
                    *)
                        fail "Unknown MCP id: ${target} (expected 01|02|04|05|all)"
                        rc=1
                        ;;
                esac
            done
            return ${rc}
            ;;
        status)
            mcp_status_table
            ;;
        logs)
            local id="${1:-}"
            if [ -z "${id}" ]; then
                fail "Usage: ./workshop.sh mcp logs <id>"
                return 1
            fi
            local log_file
            log_file=$(mcp_log_file "${id}")
            if [ ! -f "${log_file}" ]; then
                fail "No log file for MCP ${id} at ${log_file}"
                return 1
            fi
            tail -f "${log_file}"
            ;;
        build-01)
            mcp_build_01_jar
            ;;
        "")
            echo "Usage: ./workshop.sh mcp <start|stop|status|logs|build-01> [args]"
            echo ""
            echo "Examples:"
            echo "  ./workshop.sh mcp start all          Build 01 jar, start 02/04/05"
            echo "  ./workshop.sh mcp start 02           Start only 02"
            echo "  ./workshop.sh mcp stop all           Stop 02/04/05"
            echo "  ./workshop.sh mcp status             Show demo table"
            echo "  ./workshop.sh mcp logs 04            Tail 04's log"
            echo "  ./workshop.sh mcp build-01           Build the STDIO jar"
            ;;
        *)
            fail "Unknown mcp subcommand: ${action}"
            return 1
            ;;
    esac
}

# ── Credential check helpers ────────────────────────────────
# Returns 0 if provider has a configured (non-placeholder) creds.yaml
provider_has_creds() {
    local provider="$1"

    # AWS uses ~/.aws/credentials instead of creds.yaml
    if [ "${provider}" = "aws" ]; then
        [ -f "${HOME}/.aws/credentials" ] && return 0
        return 1
    fi

    local creds_file="${SCRIPT_DIR}/applications/provider-${provider}/src/main/resources/creds.yaml"

    [ ! -f "${creds_file}" ] && return 1

    # Check for placeholder patterns that indicate unconfigured credentials
    if grep -qE '\.\.\..*here\.\.\.|sk-\.\.\.your|sk-ant-\.\.\.your' "${creds_file}" 2>/dev/null; then
        return 1
    fi
    return 0
}

# Returns a compact one-line credential status string
creds_status_line() {
    local line=""
    local providers=("openai" "anthropic" "azure" "google" "aws")
    for p in "${providers[@]}"; do
        if provider_has_creds "${p}"; then
            line+="${p} ${GREEN}✓${NC}  "
        else
            line+="${p} ${RED}✗${NC}  "
        fi
    done
    echo -e "${line}"
}

# ── Running services status ─────────────────────────────────
# Returns a compact services status line for the TUI header
services_status_line() {
    local line=""

    # Provider app on port 8080
    if command -v lsof &>/dev/null && lsof -ti:8080 &>/dev/null; then
        # Try to detect which provider from PID file or process
        local prov="unknown"
        if [ -f "${SCRIPT_DIR}/.workshop-provider.pid" ]; then
            # Check the process command line for provider name
            local ppid
            ppid=$(cat "${SCRIPT_DIR}/.workshop-provider.pid" 2>/dev/null)
            if [ -n "${ppid}" ] && kill -0 "${ppid}" 2>/dev/null; then
                for p in ollama openai anthropic azure google aws; do
                    if ps -p "${ppid}" -o args= 2>/dev/null | grep -q "provider-${p}"; then
                        prov="${p}"
                        break
                    fi
                done
            fi
        fi
        line+="provider:${GREEN}${prov}${NC}  "
    else
        line+="provider:${RED}off${NC}  "
    fi

    # Gateway/spy on port 7777
    if command -v lsof &>/dev/null && lsof -ti:7777 &>/dev/null; then
        line+="spy:${GREEN}on${NC}  "
    else
        line+="spy:${RED}off${NC}  "
    fi

    # UI profile — check if dashboard endpoint responds
    if curl -sf -o /dev/null http://localhost:8080/dashboard 2>/dev/null; then
        line+="ui:${GREEN}on${NC}  "
    else
        line+="ui:${RED}off${NC}  "
    fi

    # Docker: postgres
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "postgres"; then
        line+="pg:${GREEN}on${NC}  "
    else
        line+="pg:${RED}off${NC}  "
    fi

    # Docker: LGTM
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "grafana-lgtm"; then
        line+="lgtm:${GREEN}on${NC}"
    else
        line+="lgtm:${RED}off${NC}"
    fi

    local mcp_parts=()
    for id in "${MCP_DEMOS[@]}"; do
        if mcp_is_up "${id}"; then
            mcp_parts+=("${id}${GREEN}✓${NC}")
        else
            mcp_parts+=("${id}${RED}✗${NC}")
        fi
    done
    local mcp_summary=""
    if [ "${#mcp_parts[@]}" -gt 0 ]; then
        mcp_summary=" | MCP: $(IFS=' '; echo "${mcp_parts[*]}")"
    fi

    echo -e "${line}${mcp_summary}"
}

# ── Constants ────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_FILE="${SCRIPT_DIR}/.workshop.pid"
PROVIDER_PID_FILE="${SCRIPT_DIR}/.workshop-provider.pid"
GATEWAY_PID_FILE="${SCRIPT_DIR}/.workshop-gateway.pid"

POSTGRES_COMPOSE="${SCRIPT_DIR}/docker/postgres/docker-compose.yaml"
LGTM_COMPOSE="${SCRIPT_DIR}/docker/observability-stack/docker-compose.yaml"
POSTGRES_CONTAINER="postgres-postgres-1"
LGTM_CONTAINER="grafana-lgtm"

OLLAMA_MODELS=("qwen3" "nomic-embed-text" "llava")
DATABASES=("ollama" "openai" "azure")

PROVIDERS=("ollama" "openai" "anthropic" "azure" "google" "aws")
PROFILES=("pgvector" "observation" "ui" "spy")
PROFILE_DESC=(
    "PostgreSQL vector store"
    "Observability (LGTM stack)"
    "Workshop dashboard"
    "Gateway network spy"
)

# ─────────────────────────────────────────────────────────────
# cmd_check — Check all prerequisites
# ─────────────────────────────────────────────────────────────
cmd_check() {
    echo ""
    echo -e "${BOLD}Spring AI Zero-to-Hero — Prerequisite Check${NC}"
    echo -e "Tech Stack: Spring Boot 4.0.5 | Spring AI 2.0.0-M4 | Java 25"
    echo "──────────────────────────────────────────────"

    header "Java"
    if command -v java &>/dev/null; then
        local major
        major=$(java -version 2>&1 | head -1 | sed 's/.*"\([0-9]*\)\..*/\1/' | sed 's/.*"\([0-9]*\)".*/\1/')
        if [ "${major:-0}" -ge 25 ] 2>/dev/null; then
            ok "Java ${major} — meets requirement (25+)"
        else
            warn "Java ${major} detected — Spring Boot 4.0.5 requires Java 25+"
            info "Install via: sdk install java 25.0.2-librca"
        fi
    else
        fail "Java not installed"
        info "Install via: sdk install java 25.0.2-librca"
    fi

    header "Maven wrapper"
    if [ -f "${SCRIPT_DIR}/mvnw" ]; then
        local mvn_ver
        mvn_ver=$("${SCRIPT_DIR}/mvnw" --version 2>&1 | head -1)
        ok "Maven wrapper found — ${mvn_ver}"
    else
        fail "Maven wrapper (mvnw) not found"
    fi

    header "Ollama (optional — needed only for provider-ollama)"
    if command -v ollama &>/dev/null; then
        ok "Ollama installed — $(ollama --version 2>&1 | head -1)"
        # Check if Ollama server is running
        local model_list
        if model_list=$(ollama list 2>/dev/null); then
            ok "Ollama server is running"
            for model in "${OLLAMA_MODELS[@]}"; do
                if echo "${model_list}" | grep -q "${model}"; then
                    ok "Model ${model} — available"
                else
                    warn "Model ${model} — not pulled"
                    info "Run: ollama pull ${model}"
                fi
            done
        else
            warn "Ollama server is not running — start with: ollama serve"
        fi
    else
        info "Ollama not installed (not needed for cloud providers)"
        info "Install from https://ollama.com/ if you want to run locally"
    fi

    header "Docker"
    if command -v docker &>/dev/null; then
        ok "Docker installed — $(docker --version)"
        # Check PostgreSQL container
        if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${POSTGRES_CONTAINER}$"; then
            ok "PostgreSQL container running (${POSTGRES_CONTAINER})"
        else
            warn "PostgreSQL container not running"
            info "Start with: docker compose -f docker/postgres/docker-compose.yaml up -d"
        fi
        # Check LGTM container
        if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${LGTM_CONTAINER}$"; then
            ok "LGTM container running (${LGTM_CONTAINER})"
        else
            warn "LGTM container not running"
            info "Start with: docker compose -f docker/observability-stack/docker-compose.yaml up -d"
        fi
    else
        fail "Docker not installed"
    fi

    header "Cloud Provider Credentials"
    echo -e "  $(creds_status_line)"
    echo -e "  Run ${CYAN}./workshop.sh creds${NC} to configure API keys."

    echo ""
    echo "──────────────────────────────────────────────"
    echo -e "Check complete. Fix any ${RED}❌${NC} items above."
    echo -e "Run ${CYAN}./workshop.sh setup${NC} to download dependencies."
    echo ""
}

# ─────────────────────────────────────────────────────────────
# cmd_setup — Pull models, Docker images, build project
# ─────────────────────────────────────────────────────────────
cmd_setup() {
    echo ""
    echo -e "${BOLD}Spring AI Zero-to-Hero — Setup${NC}"
    echo "──────────────────────────────────────────────"

    header "Pulling Ollama models (optional)"
    if command -v ollama &>/dev/null; then
        for model in "${OLLAMA_MODELS[@]}"; do
            echo -e "  ${CYAN}→${NC} Pulling ${model}..."
            ollama pull "${model}"
            ok "${model} ready"
        done
    else
        info "Ollama not installed — skipping model pull (not needed for cloud providers)"
    fi

    header "Pulling Docker images"
    if command -v docker &>/dev/null; then
        echo -e "  ${CYAN}→${NC} Pulling PostgreSQL images..."
        docker compose -f "${POSTGRES_COMPOSE}" pull
        echo -e "  ${CYAN}→${NC} Pulling observability images..."
        docker compose -f "${LGTM_COMPOSE}" pull
        ok "Docker images ready"
    else
        fail "Docker not installed — skipping image pull"
    fi

    header "Building Maven project"
    echo -e "  ${CYAN}→${NC} Running mvnw clean compile -T 4..."
    "${SCRIPT_DIR}/mvnw" clean compile -T 4 -f "${SCRIPT_DIR}/pom.xml"
    ok "Build complete"

    echo ""
    echo "──────────────────────────────────────────────"
    ok "Setup complete!"
    echo -e "Run ${CYAN}./workshop.sh start <provider>${NC} to launch."
    echo ""
}

# ─────────────────────────────────────────────────────────────
# cmd_start — Start infrastructure + provider app
# ─────────────────────────────────────────────────────────────
cmd_start() {
    local provider="${1:-}"
    local profiles="${2:-}"

    if [ -z "${provider}" ]; then
        fail "Provider is required"
        echo "Usage: ./workshop.sh start <provider> [--profiles <profile1,profile2,...>]"
        echo "Providers: ${PROVIDERS[*]}"
        exit 1
    fi

    # Validate provider
    local valid=false
    for p in "${PROVIDERS[@]}"; do
        [ "${p}" = "${provider}" ] && valid=true && break
    done
    if [ "${valid}" = false ]; then
        fail "Unknown provider: ${provider}"
        echo "Valid providers: ${PROVIDERS[*]}"
        exit 1
    fi

    echo ""
    echo -e "${BOLD}Starting provider: ${CYAN}${provider}${NC}"
    [ -n "${profiles}" ] && echo -e "Profiles: ${CYAN}${profiles}${NC}"
    echo "──────────────────────────────────────────────"

    # Start infrastructure based on profiles
    if echo "${profiles}" | grep -q "pgvector"; then
        header "Starting PostgreSQL (pgvector profile)"
        docker compose -f "${POSTGRES_COMPOSE}" up -d
        ok "PostgreSQL started"
    fi

    if echo "${profiles}" | grep -q "observation"; then
        header "Starting LGTM observability stack"
        docker compose -f "${LGTM_COMPOSE}" up -d
        ok "LGTM stack started"
    fi

    # Check if port 8080 is already in use (works on macOS and Linux)
    if command -v lsof &>/dev/null; then
        if lsof -ti:8080 &>/dev/null; then
            local existing_pid
            existing_pid=$(lsof -ti:8080 | head -1)
            fail "Port 8080 is already in use (PID ${existing_pid})"
            info "Run ./workshop.sh stop or kill the process: kill ${existing_pid}"
            return 1
        fi
    elif command -v ss &>/dev/null; then
        if ss -tlnp 2>/dev/null | grep -q ':8080 '; then
            fail "Port 8080 is already in use"
            info "Run ./workshop.sh stop or: ss -tlnp | grep :8080"
            return 1
        fi
    fi

    # Install dependencies to local repo (spring-boot:run resolves from local repo, not reactor)
    header "Building project"
    echo -e "  ${CYAN}→${NC} Installing modules to local Maven repository..."
    "${SCRIPT_DIR}/mvnw" install -T 4 -DskipTests -q -f "${SCRIPT_DIR}/pom.xml"
    ok "Build complete"

    # Start gateway if spy profile is enabled
    if echo "${profiles}" | grep -q "spy"; then
        header "Starting Gateway (spy profile — port 7777)"
        # Check if gateway is already running
        if command -v lsof &>/dev/null && lsof -ti:7777 &>/dev/null; then
            ok "Gateway already running on port 7777"
        else
            # Pass observation profile to gateway if selected
            local gw_run_cmd=("${SCRIPT_DIR}/mvnw" spring-boot:run \
                -pl "applications/gateway" \
                -f "${SCRIPT_DIR}/pom.xml")
            if echo "${profiles}" | grep -q "observation"; then
                gw_run_cmd+=("-Dspring-boot.run.profiles=observation")
            fi
            "${gw_run_cmd[@]}" &
            local gw_pid=$!
            echo "${gw_pid}" > "${GATEWAY_PID_FILE}"
            # Wait for gateway to be ready on port 7777
            echo -e "  ${CYAN}→${NC} Waiting for gateway on port 7777..."
            local gw_attempts=0
            while [ "${gw_attempts}" -lt 60 ]; do
                if curl -sf http://localhost:7777/actuator/health &>/dev/null; then
                    ok "Gateway started (PID ${gw_pid})"
                    break
                fi
                if ! kill -0 "${gw_pid}" 2>/dev/null; then
                    fail "Gateway process exited unexpectedly"
                    return 1
                fi
                sleep 2
                gw_attempts=$((gw_attempts + 1))
            done
            if [ "${gw_attempts}" -ge 60 ]; then
                warn "Gateway startup timed out — provider may fail to connect"
            fi
        fi
    fi

    # Build the run command
    local run_cmd=("${SCRIPT_DIR}/mvnw" spring-boot:run
        -pl "applications/provider-${provider}"
        -f "${SCRIPT_DIR}/pom.xml")
    if [ -n "${profiles}" ]; then
        run_cmd+=("-Dspring-boot.run.profiles=${profiles}")
    fi

    header "Starting provider-${provider}"
    echo -e "  ${CYAN}→${NC} ${run_cmd[*]}"

    # Launch in background
    "${run_cmd[@]}" &
    local app_pid=$!
    echo "${app_pid}" > "${PROVIDER_PID_FILE}"
    ok "Provider started (PID ${app_pid})"
    echo -e "  PID saved to: ${PROVIDER_PID_FILE}"

    # Wait for app to respond (try actuator first, fall back to swagger/v3/api-docs)
    echo -e "  ${CYAN}→${NC} Waiting for application to start..."
    local attempts=0
    local max_attempts=90
    while [ "${attempts}" -lt "${max_attempts}" ]; do
        if app_is_ready; then
            ok "Application is ready"
            break
        fi
        # Check if process is still alive
        if ! kill -0 "${app_pid}" 2>/dev/null; then
            fail "Application process exited unexpectedly"
            rm -f "${PROVIDER_PID_FILE}"
            return 1
        fi
        sleep 2
        attempts=$((attempts + 1))
    done
    if [ "${attempts}" -ge "${max_attempts}" ]; then
        if app_is_ready; then
            ok "Application is ready"
        else
            warn "Startup check timed out after 3 minutes — application may still be starting"
            info "Check: curl http://localhost:8080/v3/api-docs"
        fi
    fi

    echo ""
    echo "──────────────────────────────────────────────"
    ok "Provider ${provider} is running"
    echo -e "  Swagger UI: ${CYAN}http://localhost:8080/swagger-ui.html${NC}"
    [ -n "$(echo "${profiles}" | grep 'observation' || true)" ] && \
        echo -e "  Grafana:    ${CYAN}http://localhost:3000${NC}"
    [ -n "$(echo "${profiles}" | grep 'spy' || true)" ] && \
        echo -e "  Gateway:    ${CYAN}http://localhost:7777${NC} (spy — all AI traffic logged)"
    echo ""
}

# ─────────────────────────────────────────────────────────────
# cmd_stop — Stop running provider + infrastructure
# ─────────────────────────────────────────────────────────────
cmd_stop() {
    echo ""
    echo -e "${BOLD}Stopping workshop services${NC}"
    echo "──────────────────────────────────────────────"

    # Stop provider app — kill Maven process group + anything on port 8080
    if [ -f "${PROVIDER_PID_FILE}" ]; then
        local pid
        pid=$(cat "${PROVIDER_PID_FILE}")
        if kill -0 "${pid}" 2>/dev/null; then
            echo -e "  ${CYAN}→${NC} Stopping provider (PID ${pid}) and child processes..."
            # Kill the entire process group (Maven + forked Java app)
            kill -- -"${pid}" 2>/dev/null || kill "${pid}" 2>/dev/null || true
            # Wait for graceful shutdown
            local waited=0
            while kill -0 "${pid}" 2>/dev/null && [ "${waited}" -lt 10 ]; do
                sleep 1
                waited=$((waited + 1))
            done
            if kill -0 "${pid}" 2>/dev/null; then
                kill -9 -- -"${pid}" 2>/dev/null || kill -9 "${pid}" 2>/dev/null || true
            fi
        fi
        rm -f "${PROVIDER_PID_FILE}"
    fi

    # Also kill anything still listening on port 8080 (catches orphaned Java processes)
    if command -v lsof &>/dev/null; then
        local port_pids
        port_pids=$(lsof -ti:8080 2>/dev/null || true)
        if [ -n "${port_pids}" ]; then
            echo -e "  ${CYAN}→${NC} Killing remaining processes on port 8080..."
            echo "${port_pids}" | xargs kill -9 2>/dev/null || true
            sleep 1
        fi
    elif command -v ss &>/dev/null; then
        local ss_pid
        ss_pid=$(ss -tlnp 2>/dev/null | grep ':8080 ' | sed 's/.*pid=\([0-9]*\).*/\1/' || true)
        if [ -n "${ss_pid}" ]; then
            echo -e "  ${CYAN}→${NC} Killing remaining processes on port 8080..."
            kill -9 "${ss_pid}" 2>/dev/null || true
            sleep 1
        fi
    fi

    ok "Provider stopped"

    # Stop all MCP demos
    header "Stopping MCP demos"
    for id in "${MCP_DEMOS[@]}"; do
        mcp_stop_demo "${id}"
    done

    # Stop gateway if running
    if [ -f "${GATEWAY_PID_FILE}" ]; then
        local gw_pid
        gw_pid=$(cat "${GATEWAY_PID_FILE}")
        if kill -0 "${gw_pid}" 2>/dev/null; then
            echo -e "  ${CYAN}→${NC} Stopping gateway (PID ${gw_pid})..."
            kill -- -"${gw_pid}" 2>/dev/null || kill "${gw_pid}" 2>/dev/null || true
            sleep 2
            kill -0 "${gw_pid}" 2>/dev/null && kill -9 "${gw_pid}" 2>/dev/null || true
        fi
        rm -f "${GATEWAY_PID_FILE}"
    fi
    # Also kill anything on port 7777
    if command -v lsof &>/dev/null; then
        local gw_port_pids
        gw_port_pids=$(lsof -ti:7777 2>/dev/null || true)
        if [ -n "${gw_port_pids}" ]; then
            echo -e "  ${CYAN}→${NC} Killing remaining processes on port 7777..."
            echo "${gw_port_pids}" | xargs kill -9 2>/dev/null || true
        fi
    fi
    ok "Gateway stopped"

    # Ask about Docker containers
    echo ""
    local stop_docker
    read -r -p "  Stop Docker containers (postgres + LGTM)? [y/N] " stop_docker
    if [[ "${stop_docker}" =~ ^[Yy]$ ]]; then
        echo -e "  ${CYAN}→${NC} Stopping PostgreSQL..."
        docker compose -f "${POSTGRES_COMPOSE}" down 2>/dev/null && ok "PostgreSQL stopped" || warn "PostgreSQL was not running"
        echo -e "  ${CYAN}→${NC} Stopping LGTM stack..."
        docker compose -f "${LGTM_COMPOSE}" down 2>/dev/null && ok "LGTM stopped" || warn "LGTM was not running"
    else
        info "Docker containers left running"
    fi

    echo ""
}

# ─────────────────────────────────────────────────────────────
# cmd_reset — Drop and recreate public schema in all databases
# ─────────────────────────────────────────────────────────────
cmd_reset() {
    echo ""
    echo -e "${BOLD}Resetting demo databases${NC}"
    echo "──────────────────────────────────────────────"
    warn "This will DROP and recreate the public schema in: ${DATABASES[*]}"
    echo ""

    local confirm
    read -r -p "  Are you sure? [y/N] " confirm
    if [[ ! "${confirm}" =~ ^[Yy]$ ]]; then
        info "Reset cancelled"
        return
    fi

    # Check postgres container is running
    if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${POSTGRES_CONTAINER}$"; then
        fail "PostgreSQL container (${POSTGRES_CONTAINER}) is not running"
        info "Start with: docker compose -f docker/postgres/docker-compose.yaml up -d"
        exit 1
    fi

    echo ""
    for db in "${DATABASES[@]}"; do
        echo -e "  ${CYAN}→${NC} Resetting database: ${db}"
        docker exec "${POSTGRES_CONTAINER}" psql -U postgres -d "${db}" \
            -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;" \
            -c "GRANT ALL ON SCHEMA public TO postgres;" \
            2>&1 | sed 's/^/      /'
        ok "Database ${db} reset"
    done

    echo ""
    ok "All databases reset to clean state"
    echo ""
}

# ─────────────────────────────────────────────────────────────
# cmd_status — Show running services + health
# ─────────────────────────────────────────────────────────────
cmd_status() {
    echo ""
    echo -e "${BOLD}Workshop Status${NC}"
    echo "──────────────────────────────────────────────"

    header "Provider App"
    if [ -f "${PROVIDER_PID_FILE}" ]; then
        local pid
        pid=$(cat "${PROVIDER_PID_FILE}")
        if kill -0 "${pid}" 2>/dev/null; then
            ok "Provider running (PID ${pid})"
            # Check health
            if app_is_ready; then
                ok "Health: UP — http://localhost:8080"
            else
                warn "Application not responding on port 8080"
            fi
        else
            warn "PID ${pid} not running (stale PID file)"
        fi
    else
        info "No provider running"
    fi

    header "Docker Containers"
    if command -v docker &>/dev/null; then
        local containers
        containers=$(docker ps --format '{{.Names}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null || true)
        if [ -n "${containers}" ]; then
            while IFS=$'\t' read -r name status ports; do
                ok "${name} — ${status}"
                [ -n "${ports}" ] && echo -e "       Ports: ${ports}"
            done <<< "${containers}"
        else
            info "No Docker containers running"
        fi
    else
        warn "Docker not available"
    fi

    if command -v ollama &>/dev/null; then
        header "Ollama"
        local status_model_list
        if status_model_list=$(ollama list 2>/dev/null); then
            ok "Ollama server running"
            for model in "${OLLAMA_MODELS[@]}"; do
                if echo "${status_model_list}" | grep -q "${model}"; then
                    ok "  Model: ${model}"
                else
                    warn "  Model not pulled: ${model}"
                fi
            done
        else
            warn "Ollama server not running"
        fi
    fi

    header "Endpoints"
    echo -e "  App:       ${CYAN}http://localhost:8080${NC}"
    echo -e "  Swagger:   ${CYAN}http://localhost:8080/swagger-ui.html${NC}"
    echo -e "  OpenAPI:   ${CYAN}http://localhost:8080/v3/api-docs${NC}"
    echo -e "  Grafana:   ${CYAN}http://localhost:3000${NC}"
    echo -e "  pgAdmin:   ${CYAN}http://localhost:15433${NC}"
    echo ""
}

# ─────────────────────────────────────────────────────────────
# cmd_logs — Tail logs
# ─────────────────────────────────────────────────────────────
cmd_logs() {
    local service="${1:-provider}"

    case "${service}" in
        provider|app)
            if [ -f "${PROVIDER_PID_FILE}" ]; then
                local pid
                pid=$(cat "${PROVIDER_PID_FILE}")
                ok "Tailing logs for provider (PID ${pid})"
                info "Press Ctrl+C to stop"
                # Use Spring Boot log file if present, otherwise follow process output
                local log_file="${SCRIPT_DIR}/logs/spring.log"
                if [ -f "${log_file}" ]; then
                    tail -f "${log_file}"
                else
                    warn "No log file found at ${log_file}"
                    info "Logs are printed to the terminal where the provider was started"
                fi
            else
                fail "No provider running"
            fi
            ;;
        postgres|db)
            docker compose -f "${POSTGRES_COMPOSE}" logs -f
            ;;
        lgtm|grafana|observability)
            docker compose -f "${LGTM_COMPOSE}" logs -f
            ;;
        *)
            fail "Unknown service: ${service}"
            echo "Valid services: provider, postgres, lgtm"
            exit 1
            ;;
    esac
}

# ─────────────────────────────────────────────────────────────
# cmd_help — Show usage
# ─────────────────────────────────────────────────────────────
cmd_help() {
    echo ""
    echo -e "${BOLD}Spring AI Zero-to-Hero Workshop${NC}"
    echo -e "Boot 4.0.5 | AI 2.0.0-M4 | Java 25"
    echo ""
    echo -e "${BOLD}Usage:${NC}"
    echo "  ./workshop.sh [command] [options]"
    echo ""
    echo -e "${BOLD}Commands:${NC}"
    echo "  check                          Check all prerequisites"
    echo "  creds [provider]               Configure API keys for cloud providers"
    echo "  setup                          Pull Ollama models, Docker images, build project"
    echo "  infra <postgres|lgtm|all>      Start Docker infrastructure"
    echo "  start <provider> [--profiles]  Start infrastructure + provider app"
    echo "  stop                           Stop running provider + infrastructure"
    echo "  reset                          Reset all databases to clean state"
    echo "  status                         Show running services + health"
    echo "  logs [service]                 Tail logs (provider, postgres, lgtm)"
    echo "  help                           Show this usage"
    echo ""
    echo -e "${BOLD}Providers:${NC}"
    echo "  ollama     Local, no API keys required"
    echo "  openai     Requires OPENAI_API_KEY"
    echo "  anthropic  Requires ANTHROPIC_API_KEY"
    echo "  azure      Requires Azure OpenAI credentials"
    echo "  google     Requires GCP credentials or API key"
    echo "  aws        Requires AWS credentials"
    echo ""
    echo -e "${BOLD}Profiles:${NC}"
    echo "  pgvector      Use PostgreSQL pgvector instead of SimpleVectorStore"
    echo "  observation   Enable full observability (traces, metrics, logs)"
    echo "  ui            Enable workshop dashboard"
    echo "  spy           Route API calls through gateway for inspection"
    echo ""
    echo -e "${BOLD}Examples:${NC}"
    echo "  ./workshop.sh start ollama --profiles pgvector,observation"
    echo "  ./workshop.sh start openai --profiles pgvector"
    echo "  ./workshop.sh reset"
    echo "  ./workshop.sh status"
    echo ""
}

# ─────────────────────────────────────────────────────────────
# cmd_creds — Manage provider credentials
# ─────────────────────────────────────────────────────────────

# Ensure creds.yaml exists by copying from template if needed
ensure_creds_file() {
    local provider="$1"
    local resources="${SCRIPT_DIR}/applications/provider-${provider}/src/main/resources"
    local creds="${resources}/creds.yaml"
    local template="${resources}/creds-template.yaml"

    if [ ! -f "${creds}" ] && [ -f "${template}" ]; then
        cp "${template}" "${creds}"
        info "Created creds.yaml from template"
    fi
}

# Replace a YAML value in creds.yaml using a key path pattern
# Usage: set_creds_value file "pattern-before-value" "new-value"
set_creds_value() {
    local file="$1"
    local pattern="$2"
    local value="$3"
    # Use sed to replace the value after the matched key
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s|${pattern}.*|${pattern} ${value}|" "${file}"
    else
        sed -i "s|${pattern}.*|${pattern} ${value}|" "${file}"
    fi
}

setup_openai_creds() {
    local creds="${SCRIPT_DIR}/applications/provider-openai/src/main/resources/creds.yaml"
    ensure_creds_file "openai"

    echo ""
    echo -e "${BOLD}OpenAI Credentials${NC}"
    echo -e "  Get a key at: ${CYAN}https://platform.openai.com/api-keys${NC}"
    echo ""

    local current=""
    if [ -f "${creds}" ]; then
        current=$(grep 'api-key:' "${creds}" 2>/dev/null | head -1 | sed 's/.*api-key: *//' | xargs)
    fi
    if [ -n "${current}" ] && ! echo "${current}" | grep -qE '\.\.\..*here|sk-\.\.\.'; then
        echo -e "  Current: ${current:0:12}...${current: -4}"
    fi

    local key
    read -r -p "  API key (or Enter to skip): " key
    if [ -n "${key}" ]; then
        set_creds_value "${creds}" "api-key:" "${key}"
        ok "OpenAI API key saved"
    else
        info "Skipped"
    fi
}

setup_anthropic_creds() {
    local creds="${SCRIPT_DIR}/applications/provider-anthropic/src/main/resources/creds.yaml"
    ensure_creds_file "anthropic"

    echo ""
    echo -e "${BOLD}Anthropic Credentials${NC}"
    echo -e "  Get a key at: ${CYAN}https://console.anthropic.com/settings/keys${NC}"
    echo ""

    local current=""
    if [ -f "${creds}" ]; then
        current=$(grep 'api-key:' "${creds}" 2>/dev/null | head -1 | sed 's/.*api-key: *//' | xargs)
    fi
    if [ -n "${current}" ] && ! echo "${current}" | grep -qE '\.\.\..*here|sk-ant-\.\.\.'; then
        echo -e "  Current: ${current:0:12}...${current: -4}"
    fi

    local key
    read -r -p "  API key (or Enter to skip): " key
    if [ -n "${key}" ]; then
        set_creds_value "${creds}" "api-key:" "${key}"
        ok "Anthropic API key saved"
    else
        info "Skipped"
    fi
}

setup_azure_creds() {
    local creds="${SCRIPT_DIR}/applications/provider-azure/src/main/resources/creds.yaml"
    ensure_creds_file "azure"

    echo ""
    echo -e "${BOLD}Azure OpenAI Credentials${NC}"
    echo -e "  Create resource: ${CYAN}az cognitiveservices account create ...${NC}"
    echo -e "  See creds-template.yaml for full instructions."
    echo ""

    local current_key="" current_endpoint="" current_deployment=""
    if [ -f "${creds}" ]; then
        current_key=$(grep 'api-key:' "${creds}" 2>/dev/null | head -1 | sed 's/.*api-key: *//' | xargs)
        current_endpoint=$(grep 'endpoint:' "${creds}" 2>/dev/null | head -1 | sed 's/.*endpoint: *//' | xargs)
        current_deployment=$(grep 'deployment-name:' "${creds}" 2>/dev/null | head -1 | sed 's/.*deployment-name: *//' | xargs)
    fi

    if [ -n "${current_key}" ] && ! echo "${current_key}" | grep -qE '\.\.\..*here'; then
        echo -e "  Current API key:    ${current_key:0:8}...${current_key: -4}"
    fi
    if [ -n "${current_endpoint}" ] && ! echo "${current_endpoint}" | grep -qE 'your-resource'; then
        echo -e "  Current endpoint:   ${current_endpoint}"
    fi
    if [ -n "${current_deployment}" ]; then
        echo -e "  Current deployment: ${current_deployment}"
    fi
    echo ""

    local key endpoint deployment
    read -r -p "  API key (or Enter to skip): " key
    read -r -p "  Endpoint URL, e.g. https://NAME.openai.azure.com/ (or Enter to skip): " endpoint
    read -r -p "  Deployment name, e.g. gpt-41-mini (or Enter to skip): " deployment

    local changed=false
    if [ -n "${key}" ]; then
        set_creds_value "${creds}" "api-key:" "${key}"
        changed=true
    fi
    if [ -n "${endpoint}" ]; then
        set_creds_value "${creds}" "endpoint:" "${endpoint}"
        changed=true
    fi
    if [ -n "${deployment}" ]; then
        set_creds_value "${creds}" "deployment-name:" "${deployment}"
        changed=true
    fi

    if [ "${changed}" = true ]; then
        ok "Azure OpenAI credentials saved"
    else
        info "Skipped"
    fi
}

setup_google_creds() {
    local creds="${SCRIPT_DIR}/applications/provider-google/src/main/resources/creds.yaml"
    ensure_creds_file "google"

    echo ""
    echo -e "${BOLD}Google AI Credentials${NC}"
    echo -e "  Get a Gemini API key at: ${CYAN}https://aistudio.google.com/apikey${NC}"
    echo -e "  Or use Vertex AI with GCP project credentials."
    echo ""

    local current_key="" current_project=""
    if [ -f "${creds}" ]; then
        current_key=$(grep 'api-key:' "${creds}" 2>/dev/null | head -1 | sed 's/.*api-key: *//' | xargs)
        current_project=$(grep 'project-id:' "${creds}" 2>/dev/null | head -1 | sed 's/.*project-id: *//' | xargs)
    fi

    if [ -n "${current_key}" ] && ! echo "${current_key}" | grep -qE '\.\.\..*here'; then
        echo -e "  Current API key:    ${current_key:0:8}...${current_key: -4}"
    fi
    if [ -n "${current_project}" ] && ! echo "${current_project}" | grep -qE 'your-project'; then
        echo -e "  Current project ID: ${current_project}"
    fi
    echo ""

    local key project
    read -r -p "  API key (or Enter to skip): " key
    read -r -p "  Project ID (or Enter to skip): " project

    local changed=false
    if [ -n "${key}" ]; then
        # Google template has two api-key entries (chat + embedding) — update both
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s|api-key:.*|api-key: ${key}|g" "${creds}"
        else
            sed -i "s|api-key:.*|api-key: ${key}|g" "${creds}"
        fi
        changed=true
    fi
    if [ -n "${project}" ]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s|project-id:.*|project-id: ${project}|g" "${creds}"
        else
            sed -i "s|project-id:.*|project-id: ${project}|g" "${creds}"
        fi
        changed=true
    fi

    if [ "${changed}" = true ]; then
        ok "Google AI credentials saved"
    else
        info "Skipped"
    fi
}

setup_aws_creds() {
    echo ""
    echo -e "${BOLD}AWS Bedrock Credentials${NC}"
    echo -e "  AWS Bedrock uses ${CYAN}~/.aws/credentials${NC} (standard AWS CLI profile)."
    echo -e "  No creds.yaml needed — region and model are in application.yaml."
    echo ""

    if [ -f "${HOME}/.aws/credentials" ]; then
        ok "AWS credentials file found (~/.aws/credentials)"
        if command -v aws &>/dev/null; then
            local identity
            identity=$(aws sts get-caller-identity --query 'Account' --output text 2>/dev/null || true)
            if [ -n "${identity}" ]; then
                ok "AWS account: ${identity}"
            else
                warn "AWS credentials exist but could not verify (run: aws sts get-caller-identity)"
            fi
        fi
    else
        warn "No AWS credentials found"
        info "Run: aws configure"
        echo ""
        local run_configure
        read -r -p "  Run 'aws configure' now? [y/N] " run_configure
        if [[ "${run_configure}" =~ ^[Yy]$ ]]; then
            aws configure
        fi
    fi
}

cmd_creds() {
    local provider="${1:-}"

    if [ -n "${provider}" ]; then
        # Direct provider mode
        case "${provider}" in
            openai)    setup_openai_creds ;;
            anthropic) setup_anthropic_creds ;;
            azure)     setup_azure_creds ;;
            google)    setup_google_creds ;;
            aws)       setup_aws_creds ;;
            *)
                fail "Unknown provider: ${provider}"
                echo "Valid providers: openai, anthropic, azure, google, aws"
                return 1
                ;;
        esac
        return
    fi

    # Interactive submenu
    while true; do
        echo ""
        echo -e "${BOLD}Configure Cloud Provider Credentials${NC}"
        echo "──────────────────────────────────────────────"
        echo -e "  $(creds_status_line)"
        echo ""
        echo -e "  ${GREEN}1)${NC} OpenAI        (API key)"
        echo -e "  ${GREEN}2)${NC} Anthropic     (API key)"
        echo -e "  ${GREEN}3)${NC} Azure OpenAI  (API key + endpoint + deployment)"
        echo -e "  ${GREEN}4)${NC} Google AI     (API key + project ID)"
        echo -e "  ${GREEN}5)${NC} AWS Bedrock   (AWS CLI credentials)"
        echo -e "  ${RED}b)${NC} Back"
        echo ""
        local choice
        read -r -p "  Select provider: " choice
        case "${choice}" in
            1) setup_openai_creds ;;
            2) setup_anthropic_creds ;;
            3) setup_azure_creds ;;
            4) setup_google_creds ;;
            5) setup_aws_creds ;;
            b|B) return ;;
            *) warn "Invalid choice" ;;
        esac
    done
}

# ─────────────────────────────────────────────────────────────
# Interactive TUI menu helpers
# ─────────────────────────────────────────────────────────────
draw_menu() {
    clear
    echo -e "${BOLD}${CYAN}┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BOLD}${CYAN}│${NC}  ${BOLD}Spring AI Zero-to-Hero Workshop${NC}                         ${BOLD}${CYAN}│${NC}"
    echo -e "${BOLD}${CYAN}│${NC}  Boot 4.0.5 | AI 2.0.0-M4 | Java 25                      ${BOLD}${CYAN}│${NC}"
    echo -e "${BOLD}${CYAN}├──────────────────────────────────────────────────────────┘${NC}"
    echo -e "${BOLD}${CYAN}│${NC}  Creds: $(creds_status_line)"
    echo -e "${BOLD}${CYAN}│${NC}  State: $(services_status_line)"
    echo -e "${BOLD}${CYAN}├──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BOLD}${CYAN}│${NC}                                                          ${BOLD}${CYAN}│${NC}"
    echo -e "${BOLD}${CYAN}│${NC}  ${GREEN} 1)${NC} Check prerequisites                                 ${BOLD}${CYAN}│${NC}"
    echo -e "${BOLD}${CYAN}│${NC}  ${GREEN} 2)${NC} Setup (pull models + images + build)                ${BOLD}${CYAN}│${NC}"
    echo -e "${BOLD}${CYAN}│${NC}  ${GREEN} 3)${NC} Start infrastructure                                ${BOLD}${CYAN}│${NC}"
    echo -e "${BOLD}${CYAN}│${NC}  ${GREEN} 4)${NC} Start provider                                      ${BOLD}${CYAN}│${NC}"
    echo -e "${BOLD}${CYAN}│${NC}  ${GREEN} 5)${NC} Stop all                                            ${BOLD}${CYAN}│${NC}"
    echo -e "${BOLD}${CYAN}│${NC}  ${GREEN} 6)${NC} Reset demo state                                    ${BOLD}${CYAN}│${NC}"
    echo -e "${BOLD}${CYAN}│${NC}  ${GREEN} 7)${NC} Status                                              ${BOLD}${CYAN}│${NC}"
    echo -e "${BOLD}${CYAN}│${NC}  ${GREEN} 8)${NC} Open Grafana                                        ${BOLD}${CYAN}│${NC}"
    echo -e "${BOLD}${CYAN}│${NC}  ${GREEN} 9)${NC} Open Swagger UI                                     ${BOLD}${CYAN}│${NC}"
    echo -e "${BOLD}${CYAN}│${NC}  ${GREEN}10)${NC} Open Dashboard                                      ${BOLD}${CYAN}│${NC}"
    echo -e "${BOLD}${CYAN}│${NC}  ${GREEN}11)${NC} Start MCP demo (01|02|04|05|all)                    ${BOLD}${CYAN}│${NC}"
    echo -e "${BOLD}${CYAN}│${NC}  ${GREEN}12)${NC} Stop MCP demo                                       ${BOLD}${CYAN}│${NC}"
    echo -e "${BOLD}${CYAN}│${NC}  ${GREEN}13)${NC} MCP status                                          ${BOLD}${CYAN}│${NC}"
    echo -e "${BOLD}${CYAN}│${NC}  ${GREEN}14)${NC} Tail MCP logs                                       ${BOLD}${CYAN}│${NC}"
    echo -e "${BOLD}${CYAN}│${NC}  ${YELLOW} c)${NC} Configure credentials                               ${BOLD}${CYAN}│${NC}"
    echo -e "${BOLD}${CYAN}│${NC}  ${RED} q)${NC} Quit                                                ${BOLD}${CYAN}│${NC}"
    echo -e "${BOLD}${CYAN}│${NC}                                                          ${BOLD}${CYAN}│${NC}"
    echo -e "${BOLD}${CYAN}└──────────────────────────────────────────────────────────┘${NC}"
    echo ""
}

open_url() {
    local url="$1"
    if command -v open &>/dev/null; then
        open "${url}"
    elif command -v xdg-open &>/dev/null; then
        xdg-open "${url}"
    else
        info "Open in browser: ${url}"
    fi
}

interactive_infra() {
    echo ""
    echo -e "${BOLD}Start infrastructure:${NC}"
    echo -e "  ${GREEN}1)${NC} PostgreSQL (pgvector)    port 15432"
    echo -e "  ${GREEN}2)${NC} LGTM observability       port 3000, 4317, 4318"
    echo -e "  ${GREEN}3)${NC} Both"
    echo -e "  ${RED}a)${NC} Abort"
    echo ""
    local choice
    read -r -p "  Enter choice: " choice
    case "${choice}" in
        a|A) info "Aborted"; return 1 ;;
        1)
            header "Starting PostgreSQL (pgvector)"
            docker compose -f "${POSTGRES_COMPOSE}" up -d
            ok "PostgreSQL started on port 15432"
            ;;
        2)
            header "Starting LGTM observability stack"
            docker compose -f "${LGTM_COMPOSE}" up -d
            ok "LGTM started — Grafana on port 3000"
            ;;
        3)
            header "Starting PostgreSQL (pgvector)"
            docker compose -f "${POSTGRES_COMPOSE}" up -d
            ok "PostgreSQL started on port 15432"
            header "Starting LGTM observability stack"
            docker compose -f "${LGTM_COMPOSE}" up -d
            ok "LGTM started — Grafana on port 3000"
            ;;
        *)
            warn "Invalid choice"
            ;;
    esac
    echo ""
}

interactive_provider_select() {
    echo ""
    echo -e "${BOLD}Select provider:${NC}"
    for i in "${!PROVIDERS[@]}"; do
        local idx=$((i + 1))
        local p="${PROVIDERS[$i]}"
        case "${p}" in
            ollama)    echo -e "  ${GREEN}${idx})${NC} ${p}     (local, no API keys)" ;;
            openai)    echo -e "  ${GREEN}${idx})${NC} ${p}     (requires API key)" ;;
            anthropic) echo -e "  ${GREEN}${idx})${NC} ${p}  (requires API key)" ;;
            azure)     echo -e "  ${GREEN}${idx})${NC} ${p}      (requires API key + endpoint)" ;;
            google)    echo -e "  ${GREEN}${idx})${NC} ${p}     (requires API key or GCP project)" ;;
            aws)       echo -e "  ${GREEN}${idx})${NC} ${p}        (requires AWS credentials)" ;;
        esac
    done
    echo -e "  ${RED}a)${NC} Abort"
    echo ""
    local choice
    while true; do
        read -r -p "  Enter choice: " choice
        if [[ "${choice}" =~ ^[aA]$ ]]; then
            info "Aborted"; return 1
        fi
        if [[ "${choice}" =~ ^[0-9]+$ ]] && [ "${choice}" -ge 1 ] && [ "${choice}" -le "${#PROVIDERS[@]}" ]; then
            SELECTED_PROVIDER="${PROVIDERS[$((choice - 1))]}"
            break
        fi
        warn "Invalid choice, try again"
    done
}

interactive_profile_select() {
    # selected_profile_flags: array of 0/1 per profile
    local flags=()
    for _ in "${PROFILES[@]}"; do
        flags+=(0)
    done
    # Defaults: pgvector, observation, ui on
    flags[0]=1
    flags[1]=1
    flags[2]=1

    while true; do
        echo ""
        echo -e "${BOLD}Profiles${NC} (enter numbers to toggle, 'done' to continue, 'a' to abort):"
        for i in "${!PROFILES[@]}"; do
            local mark="[ ]"
            [ "${flags[$i]}" -eq 1 ] && mark="[x]"
            echo -e "  $((i + 1))) ${mark} ${PROFILES[$i]}    ${PROFILE_DESC[$i]}"
        done
        echo ""
        local input
        read -r -p "  > " input
        if [[ "${input}" =~ ^[aA]$ ]]; then
            info "Aborted"; return 1
        fi
        if [ "${input}" = "done" ] || [ -z "${input}" ]; then
            break
        fi
        if [[ "${input}" =~ ^[0-9]+$ ]] && [ "${input}" -ge 1 ] && [ "${input}" -le "${#PROFILES[@]}" ]; then
            local idx=$((input - 1))
            if [ "${flags[$idx]}" -eq 1 ]; then
                flags[$idx]=0
            else
                flags[$idx]=1
            fi
        else
            warn "Enter a number between 1 and ${#PROFILES[@]}, or 'done'"
        fi
    done

    # Build comma-separated profiles string
    SELECTED_PROFILES=""
    for i in "${!PROFILES[@]}"; do
        if [ "${flags[$i]}" -eq 1 ]; then
            if [ -n "${SELECTED_PROFILES}" ]; then
                SELECTED_PROFILES="${SELECTED_PROFILES},${PROFILES[$i]}"
            else
                SELECTED_PROFILES="${PROFILES[$i]}"
            fi
        fi
    done
}

interactive_start() {
    SELECTED_PROVIDER=""
    SELECTED_PROFILES=""

    interactive_provider_select || return 0
    interactive_profile_select || return 0

    echo ""
    local start_infra
    read -r -p "  Start infrastructure? [Y/n] " start_infra
    if [[ "${start_infra}" =~ ^[aA]$ ]]; then
        info "Aborted"; return 0
    fi
    cmd_start "${SELECTED_PROVIDER}" "${SELECTED_PROFILES}"
}

interactive_mcp_start() {
    echo ""
    echo -e "${BOLD}Start MCP demo:${NC}"
    echo -e "  ${GREEN}1)${NC} 01 (build STDIO jar)"
    echo -e "  ${GREEN}2)${NC} 02 (HTTP server :8081)"
    echo -e "  ${GREEN}3)${NC} 04 (Dynamic Tool Calling :8082)"
    echo -e "  ${GREEN}4)${NC} 05 (Full Capabilities :8083)"
    echo -e "  ${GREEN}5)${NC} all"
    echo -e "  ${RED}a)${NC} Abort"
    echo ""
    local choice
    read -r -p "  Enter choice: " choice
    case "${choice}" in
        1) cmd_mcp start 01 ;;
        2) cmd_mcp start 02 ;;
        3) cmd_mcp start 04 ;;
        4) cmd_mcp start 05 ;;
        5) cmd_mcp start all ;;
        a|A) info "Aborted" ;;
        *) warn "Invalid choice" ;;
    esac
}

interactive_mcp_stop() {
    echo ""
    echo -e "${BOLD}Stop MCP demo:${NC}"
    echo -e "  ${GREEN}1)${NC} 02"
    echo -e "  ${GREEN}2)${NC} 04"
    echo -e "  ${GREEN}3)${NC} 05"
    echo -e "  ${GREEN}4)${NC} all"
    echo -e "  ${RED}a)${NC} Abort"
    echo ""
    local choice
    read -r -p "  Enter choice: " choice
    case "${choice}" in
        1) cmd_mcp stop 02 ;;
        2) cmd_mcp stop 04 ;;
        3) cmd_mcp stop 05 ;;
        4) cmd_mcp stop all ;;
        a|A) info "Aborted" ;;
        *) warn "Invalid choice" ;;
    esac
}

interactive_mcp_logs() {
    echo ""
    echo -e "${BOLD}Tail MCP logs:${NC}"
    echo -e "  ${GREEN}1)${NC} 02"
    echo -e "  ${GREEN}2)${NC} 04"
    echo -e "  ${GREEN}3)${NC} 05"
    echo -e "  ${RED}a)${NC} Abort"
    echo ""
    local choice
    read -r -p "  Enter choice: " choice
    case "${choice}" in
        1) cmd_mcp logs 02 ;;
        2) cmd_mcp logs 04 ;;
        3) cmd_mcp logs 05 ;;
        a|A) info "Aborted" ;;
        *) warn "Invalid choice" ;;
    esac
}

run_menu() {
    while true; do
        draw_menu
        local choice
        read -r -p "  Select option: " choice
        case "${choice}" in
            1) cmd_check; read -r -p "  Press Enter to continue..." _ ;;
            2) cmd_setup; read -r -p "  Press Enter to continue..." _ ;;
            3) interactive_infra || true; read -r -p "  Press Enter to continue..." _ ;;
            4) interactive_start || true; read -r -p "  Press Enter to continue..." _ ;;
            5) cmd_stop; read -r -p "  Press Enter to continue..." _ ;;
            6) cmd_reset; read -r -p "  Press Enter to continue..." _ ;;
            7) cmd_status; read -r -p "  Press Enter to continue..." _ ;;
            8) open_url "http://localhost:3000"; info "Opening Grafana..."; read -r -p "  Press Enter to continue..." _ ;;
            9) open_url "http://localhost:8080/swagger-ui.html"; info "Opening Swagger UI..."; read -r -p "  Press Enter to continue..." _ ;;
            10) open_url "http://localhost:8080/dashboard"; info "Opening Dashboard..."; read -r -p "  Press Enter to continue..." _ ;;
            11) interactive_mcp_start; read -r -p "  Press Enter to continue..." _ ;;
            12) interactive_mcp_stop; read -r -p "  Press Enter to continue..." _ ;;
            13) cmd_mcp status; read -r -p "  Press Enter to continue..." _ ;;
            14) interactive_mcp_logs ;;
            c|C) cmd_creds; read -r -p "  Press Enter to continue..." _ ;;
            q|Q) echo ""; info "Goodbye!"; echo ""; exit 0 ;;
            *) warn "Invalid option: ${choice}" ;;
        esac
    done
}

# ─────────────────────────────────────────────────────────────
# Argument parsing / dispatch
# ─────────────────────────────────────────────────────────────
main() {
    if [ $# -eq 0 ]; then
        run_menu
        return
    fi

    local cmd="${1}"
    shift

    case "${cmd}" in
        check)
            cmd_check
            ;;
        setup)
            cmd_setup
            ;;
        infra)
            local target="${1:-all}"
            case "${target}" in
                postgres|pg|pgvector)
                    header "Starting PostgreSQL (pgvector)"
                    docker compose -f "${POSTGRES_COMPOSE}" up -d
                    ok "PostgreSQL started on port 15432"
                    ;;
                lgtm|observability|obs)
                    header "Starting LGTM observability stack"
                    docker compose -f "${LGTM_COMPOSE}" up -d
                    ok "LGTM started — Grafana on port 3000"
                    ;;
                all|both)
                    header "Starting PostgreSQL (pgvector)"
                    docker compose -f "${POSTGRES_COMPOSE}" up -d
                    ok "PostgreSQL started on port 15432"
                    header "Starting LGTM observability stack"
                    docker compose -f "${LGTM_COMPOSE}" up -d
                    ok "LGTM started — Grafana on port 3000"
                    ;;
                *)
                    fail "Unknown target: ${target}"
                    echo "Usage: ./workshop.sh infra <postgres|lgtm|all>"
                    exit 1
                    ;;
            esac
            ;;
        mcp)
            cmd_mcp "$@"
            ;;
        start)
            local provider="${1:-}"
            local profiles=""
            shift || true
            # Parse --profiles flag
            while [ $# -gt 0 ]; do
                case "$1" in
                    --profiles)
                        profiles="${2:-}"
                        shift 2
                        ;;
                    --profiles=*)
                        profiles="${1#--profiles=}"
                        shift
                        ;;
                    *)
                        shift
                        ;;
                esac
            done
            cmd_start "${provider}" "${profiles}"
            ;;
        stop)
            cmd_stop
            ;;
        reset)
            cmd_reset
            ;;
        status)
            cmd_status
            ;;
        creds)
            cmd_creds "${1:-}"
            ;;
        logs)
            cmd_logs "${1:-provider}"
            ;;
        help|--help|-h)
            cmd_help
            ;;
        *)
            fail "Unknown command: ${cmd}"
            cmd_help
            exit 1
            ;;
    esac
}

main "$@"
