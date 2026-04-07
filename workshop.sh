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

# ── Constants ────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_FILE="${SCRIPT_DIR}/.workshop.pid"
PROVIDER_PID_FILE="${SCRIPT_DIR}/.workshop-provider.pid"

POSTGRES_COMPOSE="${SCRIPT_DIR}/docker/postgres/docker-compose.yaml"
LGTM_COMPOSE="${SCRIPT_DIR}/docker/observability-stack/docker-compose.yaml"
POSTGRES_CONTAINER="postgres-postgres-1"
LGTM_CONTAINER="grafana-lgtm"

OLLAMA_MODELS=("mistral" "nomic-embed-text" "llava")
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

    header "Ollama"
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
                    fail "Model ${model} — not pulled"
                    info "Run: ollama pull ${model}"
                fi
            done
        else
            warn "Ollama server is not running — start with: ollama serve"
        fi
    else
        fail "Ollama not installed"
        info "Install from https://ollama.com/"
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

    header "Pulling Ollama models"
    if command -v ollama &>/dev/null; then
        for model in "${OLLAMA_MODELS[@]}"; do
            echo -e "  ${CYAN}→${NC} Pulling ${model}..."
            ollama pull "${model}"
            ok "${model} ready"
        done
    else
        fail "Ollama not installed — skipping model pull"
        info "Install from https://ollama.com/"
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

    header "Ollama"
    if command -v ollama &>/dev/null; then
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
    else
        warn "Ollama not installed"
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
# Interactive TUI menu helpers
# ─────────────────────────────────────────────────────────────
draw_menu() {
    clear
    echo -e "${BOLD}${CYAN}┌───────────────────────────────────────────┐${NC}"
    echo -e "${BOLD}${CYAN}│${NC}  ${BOLD}Spring AI Zero-to-Hero Workshop${NC}          ${BOLD}${CYAN}│${NC}"
    echo -e "${BOLD}${CYAN}│${NC}  Boot 4.0.5 | AI 2.0.0-M4 | Java 25       ${BOLD}${CYAN}│${NC}"
    echo -e "${BOLD}${CYAN}├───────────────────────────────────────────┤${NC}"
    echo -e "${BOLD}${CYAN}│${NC}                                           ${BOLD}${CYAN}│${NC}"
    echo -e "${BOLD}${CYAN}│${NC}  ${GREEN} 1)${NC} Check prerequisites                  ${BOLD}${CYAN}│${NC}"
    echo -e "${BOLD}${CYAN}│${NC}  ${GREEN} 2)${NC} Setup (pull models + images + build) ${BOLD}${CYAN}│${NC}"
    echo -e "${BOLD}${CYAN}│${NC}  ${GREEN} 3)${NC} Start infrastructure                 ${BOLD}${CYAN}│${NC}"
    echo -e "${BOLD}${CYAN}│${NC}  ${GREEN} 4)${NC} Start provider                       ${BOLD}${CYAN}│${NC}"
    echo -e "${BOLD}${CYAN}│${NC}  ${GREEN} 5)${NC} Stop all                             ${BOLD}${CYAN}│${NC}"
    echo -e "${BOLD}${CYAN}│${NC}  ${GREEN} 6)${NC} Reset demo state                     ${BOLD}${CYAN}│${NC}"
    echo -e "${BOLD}${CYAN}│${NC}  ${GREEN} 7)${NC} Status                               ${BOLD}${CYAN}│${NC}"
    echo -e "${BOLD}${CYAN}│${NC}  ${GREEN} 8)${NC} Open Grafana                         ${BOLD}${CYAN}│${NC}"
    echo -e "${BOLD}${CYAN}│${NC}  ${GREEN} 9)${NC} Open Swagger UI                      ${BOLD}${CYAN}│${NC}"
    echo -e "${BOLD}${CYAN}│${NC}  ${GREEN}10)${NC} Open Dashboard                       ${BOLD}${CYAN}│${NC}"
    echo -e "${BOLD}${CYAN}│${NC}  ${RED} q)${NC} Quit                                 ${BOLD}${CYAN}│${NC}"
    echo -e "${BOLD}${CYAN}│${NC}                                           ${BOLD}${CYAN}│${NC}"
    echo -e "${BOLD}${CYAN}└───────────────────────────────────────────┘${NC}"
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
