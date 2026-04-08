# Workshop Prerequisites — Spring AI Zero-to-Hero

> **Please complete all steps below before the workshop day.**
> Installing and downloading everything takes 30-60 minutes depending on your internet connection.
> We will not have time to troubleshoot installations during the workshop.

---

## Tech Stack

| Component | Version |
|-----------|---------|
| Spring Boot | 4.0.5 |
| Spring AI | 2.0.0-M4 |
| Java | 25 |
| Maven | 3.9.14 (included via wrapper) |

## Supported Operating Systems

| OS | Status | Notes |
|----|--------|-------|
| **macOS 26+** (Apple Silicon or Intel) | Fully supported | Primary development platform |
| **Ubuntu 24.04 LTS** | Fully supported | |
| **Debian 13** (kernel 6.8+) | Fully supported | Same setup as Ubuntu |
| **Windows 11** (Intel, AMD, Snapdragon) | Supported via WSL2 | See [Windows 11 Setup Guide](howto_windows11.md) |

> **Windows users:** The entire workshop runs inside WSL2 (Ubuntu 24.04). Follow the dedicated [Windows 11 Setup Guide](howto_windows11.md) — it covers WSL2 installation, Docker, Java, and all known issues. Then return here for the verification steps.

---

## 1. Java 25

Spring Boot 4.0.5 requires Java 25. We recommend using SDKMAN to manage Java versions.

### Install SDKMAN

```bash
curl -s "https://get.sdkman.io" | bash
source "$HOME/.sdkman/bin/sdkman-init.sh"
```

### Install Java 25

```bash
sdk install java 25.0.2-librca
sdk use java 25.0.2-librca
```

### Verify

```bash
java -version
# Expected: openjdk version "25.0.2" ...

javac -version
# Expected: javac 25.0.2
```

---

## 2. Docker

Docker is required for PostgreSQL (pgvector) and the observability stack (Grafana, Loki, Tempo, OpenTelemetry Collector).

### macOS

Install **Docker Desktop for Mac** from https://www.docker.com/products/docker-desktop/

After installation, increase resources in **Settings > Resources > Advanced**:
- Memory: **6 GB** minimum (8 GB recommended)
- CPUs: **4** minimum

### Linux (Ubuntu / Debian)

Install Docker Engine from the official repository (**not** the `docker.io` package from Ubuntu repos):

```bash
# Add Docker's official GPG key and repository
sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
  https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
```

Add your user to the docker group (so you don't need `sudo`):

```bash
sudo usermod -aG docker $USER
# Log out and back in for the group change to take effect
```

### Windows

See [Windows 11 Setup Guide](howto_windows11.md) — Docker Desktop with WSL2 backend.

### Verify (all platforms)

```bash
docker --version
# Expected: Docker version 27.x or later

docker compose version
# Expected: Docker Compose version v2.x

docker run --rm hello-world
# Expected: Hello from Docker!
```

---

## 3. Ollama (optional — needed only for local provider)

Ollama is the local LLM server used for the `provider-ollama` module. It runs models locally, so no API keys are needed. **Skip this section if you plan to use a cloud provider** (OpenAI, Anthropic, Azure, Google, or AWS).

### macOS

```bash
brew install ollama
```

Or download from https://ollama.com/

### Linux (Ubuntu / Debian)

```bash
curl -fsSL https://ollama.com/install.sh | sh
```

### Windows

See [Windows 11 Setup Guide](howto_windows11.md) — install natively on Windows or inside WSL2.

### Pull Workshop Models

After installing Ollama, start the server and pull the required models:

```bash
# Start the Ollama server (if not running as a service)
ollama serve &

# Pull the workshop models (total download: ~7 GB)
ollama pull qwen3
ollama pull nomic-embed-text
ollama pull llava
```

### Verify

```bash
ollama list
# Expected: qwen3, nomic-embed-text, llava listed
```

---

## 4. Git

### macOS

```bash
# Xcode Command Line Tools (includes git)
xcode-select --install

# Or via Homebrew
brew install git
```

### Linux

```bash
sudo apt install -y git
```

### Windows

Git is available inside WSL2 Ubuntu — `sudo apt install -y git`.

### Verify

```bash
git --version
# Expected: git version 2.x
```

---

## 5. Clone the Repository

```bash
git clone https://github.com/<your-org>/spring-ai-zero-to-hero.git
cd spring-ai-zero-to-hero
```

> **Windows (WSL2):** Clone inside the WSL2 filesystem (`~/projects/`), **not** on `/mnt/c/...`. The Windows filesystem is 5-10x slower for Maven builds.

---

## 6. Build the Project

The Maven wrapper is included in the repository — no separate Maven installation needed.

```bash
./mvnw clean compile -T 4
```

This downloads all dependencies and compiles all modules. First run takes a few minutes.

### Verify

```bash
./mvnw --version
# Expected: Apache Maven 3.9.14
```

---

## 7. Start Infrastructure (Optional Pre-Check)

If you want to verify everything works end-to-end before the workshop:

```bash
# Start PostgreSQL with pgvector
docker compose -f docker/postgres/docker-compose.yaml up -d

# Start the observability stack (Grafana, Loki, Tempo, OTel Collector)
docker compose -f docker/observability-stack/docker-compose.yaml up -d
```

### Verify

```bash
# PostgreSQL
docker exec postgres-postgres-1 psql -U postgres -c "SELECT 1"
# Expected: a result row

# Grafana
curl -sf http://localhost:3000/api/health
# Expected: {"commit":"...","database":"ok",...}
```

Stop the infrastructure after verification (it will be started again during the workshop):

```bash
docker compose -f docker/postgres/docker-compose.yaml down
docker compose -f docker/observability-stack/docker-compose.yaml down
```

---

## 8. Run the Automated Check

The workshop includes a built-in prerequisite checker that validates everything at once:

```bash
./workshop.sh check
```

This checks Java version, Maven wrapper, Ollama (if installed), Docker containers, and cloud provider credentials. Fix any items marked with a red cross before the workshop.

To configure API keys for cloud providers (OpenAI, Anthropic, Azure, Google, AWS):

```bash
./workshop.sh creds
```

---

## Quick Reference — All-in-One Setup

For experienced developers who want the minimal command sequence:

### macOS

```bash
# Java
curl -s "https://get.sdkman.io" | bash
source "$HOME/.sdkman/bin/sdkman-init.sh"
sdk install java 25.0.2-librca

# Docker — install Docker Desktop from https://www.docker.com/products/docker-desktop/

# Ollama (optional — only needed for local provider)
# brew install ollama
# ollama pull qwen3 && ollama pull nomic-embed-text && ollama pull llava

# Clone and build
git clone https://github.com/<your-org>/spring-ai-zero-to-hero.git
cd spring-ai-zero-to-hero
./mvnw clean compile -T 4

# Verify
./workshop.sh check
```

### Linux (Ubuntu 24.04)

```bash
# System packages
sudo apt update && sudo apt install -y git curl unzip zip

# Java
curl -s "https://get.sdkman.io" | bash
source "$HOME/.sdkman/bin/sdkman-init.sh"
sdk install java 25.0.2-librca

# Docker (official repo — see step 2 above for full commands)
# ...install Docker Engine...
sudo usermod -aG docker $USER
# Log out and back in

# Ollama (optional — only needed for local provider)
# curl -fsSL https://ollama.com/install.sh | sh
# ollama pull qwen3 && ollama pull nomic-embed-text && ollama pull llava

# Clone and build
git clone https://github.com/<your-org>/spring-ai-zero-to-hero.git
cd spring-ai-zero-to-hero
./mvnw clean compile -T 4

# Configure cloud provider credentials (if not using Ollama)
./workshop.sh creds

# Verify
./workshop.sh check
```

### Windows 11

Follow the [Windows 11 Setup Guide](howto_windows11.md), then:

```bash
# Inside WSL2 Ubuntu — same as Linux above
./workshop.sh check
```

---

## Checklist

Use this checklist to confirm you're ready:

- [ ] Java 25 installed — `java -version` shows `25.0.2`
- [ ] Docker running — `docker run --rm hello-world` succeeds
- [ ] *(optional)* Ollama installed — `ollama --version` shows a version (only for local provider)
- [ ] *(optional)* Ollama models pulled — `ollama list` shows `qwen3`, `nomic-embed-text`, `llava`
- [ ] Repository cloned
- [ ] Build succeeds — `./mvnw clean compile -T 4` completes without errors
- [ ] `./workshop.sh check` shows all green

---

## Optional Tools

These are not required but improve the workshop experience:

| Tool | Purpose | Install |
|------|---------|---------|
| **direnv** | Auto-loads project PATH settings | `brew install direnv` (macOS) / `apt install direnv` (Linux) |
| **SDKMAN** | Manage Java versions | Already installed above |
| **IDE** | Code editing | IntelliJ IDEA or VS Code with Java + Spring Boot extensions |

## Disk Space Requirements

| Component | Size |
|-----------|------|
| Java 25 (SDKMAN) | ~300 MB |
| Maven dependencies (first build) | ~1.5 GB |
| Docker images (pgvector, grafana, pgadmin, maildev) | ~2 GB |
| Ollama models *(optional)* (qwen3, nomic-embed-text, llava) | ~7 GB |
| **Total (with Ollama)** | **~11 GB** |
| **Total (cloud only, no Ollama)** | **~4 GB** |

Ensure you have at least **5 GB** of free disk space (15 GB if using Ollama).

---

## Need Help?

- **macOS / Linux issues**: Check the [OS Compatibility Analysis](os-compatibility-analysis.md)
- **Windows issues**: See the [Windows 11 Setup Guide](howto_windows11.md) — includes detailed troubleshooting
- **During the workshop**: The instructor will help with any remaining issues
