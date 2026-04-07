# OS Compatibility Analysis — Spring AI Zero-to-Hero Workshop

> **Date:** 2026-04-07
> **Target stack:** Spring Boot 4.0.5 | Spring AI 2.0.0-M4 | Java 25 | Maven 3.9.14

---

## Table of Contents

1. [Inventory of Scripts and External Dependencies](#1-inventory-of-scripts-and-external-dependencies)
2. [macOS 26+ (Tahoe)](#2-macos-26-tahoe)
3. [Ubuntu 24.04 LTS / Debian (kernel 6.8+)](#3-ubuntu-2404-lts--debian-kernel-68)
4. [Windows 11 (x86_64 and ARM64)](#4-windows-11-x86_64-and-arm64)
5. [Cross-Platform Comparison Matrix](#5-cross-platform-comparison-matrix)
6. [Recommendations](#6-recommendations)

---

## 1. Inventory of Scripts and External Dependencies

### 1.1 Shell Scripts in the Project

| Script | Purpose | Bash Features | OS-Specific Commands |
|--------|---------|---------------|----------------------|
| `workshop.sh` | Main workshop orchestrator (interactive TUI + CLI) | arrays, `${BASH_SOURCE[0]}`, `set -euo pipefail`, `[[ ]]`, `=~` regex, process group `kill -- -$pid` | `lsof -ti:8080` (macOS), `ss -tlnp` (Linux), `open` (macOS) / `xdg-open` (Linux) |
| `models/ollama.sh` | Export/import Ollama models | arrays, `${var%%:*}` parameter expansion, `mktemp -d`, `trap`, `read -rp` | `du -h` (differs on macOS vs GNU) |
| `applications/provider-google/refresh-vertex-token.sh` | GCP auth refresh | Minimal — just calls `gcloud` | `gcloud` CLI |
| `mvnw` | Maven wrapper (Unix) | POSIX-compatible with some bash extensions | `uname`, `which`/`command -v` |
| `mvnw.cmd` | Maven wrapper (Windows) | Batch + PowerShell hybrid | Native Windows |
| `.envrc` | direnv config — adds `bin/`, `docker/` dirs to PATH | direnv-specific `PATH_add` | None |

> **Out of scope:** `docker/postgres/pg` and `docker/observability-stack/ostack` are Docker container management wrappers. They invoke `docker compose` which runs containers independently of the host OS — no compatibility concerns.

### 1.2 External Tool Dependencies

| Tool | Required? | Used By | Purpose |
|------|-----------|---------|---------|
| **Java 25** | Yes | `mvnw`, all Spring Boot apps | Runtime + compilation |
| **Maven 3.9.14** | Auto (wrapper) | `mvnw` / `mvnw.cmd` | Build system |
| **Docker + Docker Compose** | Yes (for pgvector/observability) | `workshop.sh` | PostgreSQL, Grafana LGTM, MailDev (containers are host-independent) |
| **Ollama** | Yes (for ollama provider) | `workshop.sh`, `models/ollama.sh` | Local LLM inference |
| **curl** | Yes | `workshop.sh` health checks | HTTP probing |
| **git** | Yes | Development workflow | Version control |
| **lsof** | macOS only | `workshop.sh` port conflict detection | Port checking |
| **ss** | Linux only | `workshop.sh` port conflict detection (fallback) | Port checking |
| **direnv** | Optional | `.envrc` | Automatic PATH setup |
| **gcloud** | Optional | `refresh-vertex-token.sh` | Google provider only |
| **SDKMAN** | Recommended | Install instructions in `workshop.sh` | Java version management |

### 1.3 Bash Feature Compatibility Summary

All scripts target **bash 3.2+** (macOS default) with the following features:

- Arrays: `arr=(a b c)`, `${arr[@]}`, `${#arr[@]}`, `${arr[$i]}`
- Parameter expansion: `${var:-default}`, `${var%%pattern}`, `${var#pattern}`, `${var//old/new}`
- `[[ ]]` test syntax with `=~` regex matching
- `set -euo pipefail` (strict mode)
- `$'\e[...'` ANSI escape sequences
- Process substitution: `<<<` here-strings
- `trap ... EXIT` for cleanup
- `read -r -p` for user prompts
- `BASH_SOURCE[0]` for script self-location
- `command -v` for tool detection

**Not used (bash 4+ only features that are avoided):**
- Associative arrays (`declare -A`)
- `${var,,}` / `${var^^}` case modification
- `readarray` / `mapfile`
- `|&` pipe stderr

---

## 2. macOS 26+ (Tahoe)

### 2.1 Shell Environment

| Aspect | Status |
|--------|--------|
| Default shell | **zsh** (since macOS Catalina / 10.15) |
| Bash version | **bash 3.2.57** (Apple ships ancient GPLv2 bash) |
| Script compatibility | All scripts use `#!/usr/bin/env bash` shebang — works regardless of login shell |
| Architectures | Apple Silicon (arm64) primary, Intel (x86_64) via Rosetta 2 |

### 2.2 Prerequisite Installation

| Tool | How to Install | Notes |
|------|----------------|-------|
| Java 25 | `sdk install java 25.0.2-librca` (SDKMAN) or Adoptium `.pkg` | No macOS-bundled JDK; must install |
| SDKMAN | `curl -s "https://get.sdkman.io" \| bash` | Requires bash/zsh |
| Docker | Docker Desktop for Mac (arm64 native) | Free for personal/education use |
| Ollama | `brew install ollama` or download from ollama.com | Native arm64, Metal GPU acceleration |
| curl | Pre-installed | Ships with macOS |
| git | Pre-installed (Xcode CLT) or `brew install git` | |
| lsof | Pre-installed | Used by `workshop.sh` for port detection |
| direnv | `brew install direnv` | Optional |
| gcloud | `brew install google-cloud-sdk` | Only for Google provider |

### 2.3 Compatibility Assessment

| Component | Status | Notes |
|-----------|--------|-------|
| `workshop.sh` | **Works** | Uses `lsof` (present), `open` (present), bash 3.2 compatible |
| `models/ollama.sh` | **Works** | All bash features within 3.2; `du -h` works (slightly different output format) |
| `mvnw` | **Works** | Unix shell script |
| Docker | **Works** | Docker Desktop provides `docker compose`; all images available for arm64 |
| Ollama models | **Works** | GGUF is architecture-independent; Metal GPU acceleration on Apple Silicon |

### 2.4 macOS-Specific Issues

1. **`du -h` output format**: macOS `du` outputs `4.0G` vs GNU `du` outputs `4.0G` — functionally identical for display purposes, no action needed.
2. **File descriptor limits**: macOS has a default soft limit of 256 open files. For large builds, may need `ulimit -n 10240`.
3. **Docker Desktop resource limits**: Default 2GB RAM may be insufficient for LGTM stack + PostgreSQL + app. Recommend 6GB+ in Docker Desktop settings.
4. **Gatekeeper**: First-time Ollama launch may require "Allow" in System Settings > Privacy & Security.

### 2.5 Verdict: macOS 26+

> **Fully supported. No changes required.** This is the primary development platform and everything works natively.

---

## 3. Ubuntu 24.04 LTS / Debian (kernel 6.8+)

### 3.1 Matching Debian Versions

| Distribution | Kernel | Status |
|-------------|--------|--------|
| **Ubuntu 24.04 LTS** (Noble Numbat) | 6.8 | Primary Linux target |
| **Debian 13 (Trixie)** | 6.12+ | Matches or exceeds Ubuntu 24.04 kernel; currently testing/unstable |
| **Debian 12 (Bookworm)** | 6.1 | Older kernel but functional; backports available for 6.8+ |

> For "same kernel as Ubuntu 24.04", **Debian 13 (Trixie)** is the match. Debian 12 with backport kernel 6.8 is also viable.

### 3.2 Shell Environment

| Aspect | Status |
|--------|--------|
| Default shell | **bash 5.2+** (Ubuntu 24.04), **dash** is `/bin/sh` |
| Script compatibility | All scripts use `#!/usr/bin/env bash` — invokes bash, not dash |
| Architectures | x86_64 (primary), arm64/aarch64 (Raspberry Pi, cloud instances) |

### 3.3 Prerequisite Installation

| Tool | How to Install | Notes |
|------|----------------|-------|
| Java 25 | `sdk install java 25.0.2-librca` (SDKMAN) or Adoptium APT repo | `apt` repos only have up to Java 21 (Ubuntu 24.04) |
| SDKMAN | `curl -s "https://get.sdkman.io" \| bash` | Needs `zip`, `unzip`, `curl` |
| Docker | Official Docker APT repo (`docs.docker.com/engine/install/ubuntu/`) | **Not** `docker.io` from Ubuntu repos (outdated) |
| Docker Compose | Included as `docker compose` plugin (v2) with Docker Engine | Do **not** install `docker-compose` (v1, deprecated) |
| Ollama | `curl -fsSL https://ollama.com/install.sh \| sh` | Installs as systemd service; supports NVIDIA CUDA + AMD ROCm |
| curl | `apt install curl` | Usually pre-installed |
| git | `apt install git` | Usually pre-installed |
| ss | Pre-installed (`iproute2` package) | Used by `workshop.sh` as Linux fallback for port detection |
| lsof | `apt install lsof` | May not be pre-installed on minimal installs |
| direnv | `apt install direnv` | Optional |

### 3.4 Compatibility Assessment

| Component | Status | Notes |
|-----------|--------|-------|
| `workshop.sh` | **Works** | Uses `ss` on Linux (present via `iproute2`), `xdg-open` for URLs |
| `models/ollama.sh` | **Works** | GNU bash 5.2+; all features supported |
| `mvnw` | **Works** | Unix shell script |
| Docker | **Works** | Docker Engine + Compose v2 plugin; all images available for amd64 and arm64 |
| Ollama models | **Works** | GGUF is arch-independent; GPU accel via CUDA/ROCm |

### 3.5 Linux-Specific Issues

1. **`xdg-open` for browser**: `workshop.sh` uses `xdg-open` as Linux fallback for opening URLs. Requires a desktop environment. On headless servers, it gracefully falls back to printing the URL.
2. **Docker permissions**: User must be in the `docker` group (`sudo usermod -aG docker $USER`) or use `sudo`. Workshop scripts do not prefix `docker` with `sudo`.
3. **Ollama as systemd service**: Default install runs as user `ollama`, storing models in `/usr/share/ollama/.ollama/models`. The `models/ollama.sh` script handles this path. If running as current user (`ollama serve`), models are in `~/.ollama/models`.
4. **Firewall**: Ubuntu's `ufw` may block Docker-published ports. Run `sudo ufw allow` for workshop ports or disable during the workshop.
5. **Process group kill**: `kill -- -$pid` in `workshop.sh` requires the process to be a group leader. Works correctly when launched from the script.

### 3.6 Debian-Specific Differences from Ubuntu

| Aspect | Ubuntu 24.04 | Debian 13 (Trixie) |
|--------|-------------|---------------------|
| Java in repos | OpenJDK 21 max | OpenJDK 21 max |
| Docker install | Same official repo | Same official repo |
| `snap` (for some tools) | Pre-installed | Not available by default |
| `xdg-open` | Pre-installed (desktop) | Install `xdg-utils` |

### 3.7 Verdict: Ubuntu 24.04 / Debian

> **Fully supported. No script changes required.** Minor setup differences (Docker group, SDKMAN for Java 25). The scripts already handle Linux-specific commands (`ss`, `xdg-open`).

---

## 4. Windows 11 (x86_64 and ARM64)

### 4.1 The Core Challenge

The workshop has **4 host-side bash scripts** that need to run on the attendee's machine (`workshop.sh`, `models/ollama.sh`, `mvnw`, `refresh-vertex-token.sh`). Docker container scripts (`pg`, `ostack`) are host-independent and excluded from this analysis. Windows does not natively run bash. There are three possible strategies:

| Strategy | Complexity | User Experience | Maintenance Burden |
|----------|-----------|-----------------|-------------------|
| **A) WSL2 (recommended)** | Low | Near-identical to Linux | Minimal — reuse all existing scripts |
| **B) Native PowerShell ports** | Very High | Native Windows feel | Double maintenance — every script change must be mirrored |
| **C) Hybrid (WSL2 + native Java)** | Medium | Mixed | Moderate |

### 4.2 Strategy A: WSL2 (Recommended)

#### What is WSL2?

Windows Subsystem for Linux 2 runs a real Linux kernel in a lightweight VM. It is built into Windows 11 and fully supported by Microsoft.

#### Prerequisites

```
wsl --install -d Ubuntu-24.04
```

This single command installs WSL2 + Ubuntu 24.04. Available on both x86_64 and ARM64 Windows 11.

#### How the Workshop Runs Under WSL2

| Component | Where It Runs | How |
|-----------|--------------|-----|
| `workshop.sh` | WSL2 (Ubuntu) | Directly — native bash |
| `models/ollama.sh` | WSL2 (Ubuntu) | Directly — native bash |
| `mvnw` | WSL2 (Ubuntu) | Directly — Unix script |
| Java 25 | WSL2 (Ubuntu) | SDKMAN install inside WSL2 |
| Docker | Docker Desktop (Windows) with WSL2 backend | Docker CLI available inside WSL2 transparently |
| Ollama | Windows native app **or** WSL2 install | See details below |
| Browser (Swagger, Grafana) | Windows | `localhost` ports are forwarded from WSL2 automatically |
| IDE (IntelliJ, VS Code) | Windows | VS Code: Remote-WSL extension; IntelliJ: open project from `\\wsl$\Ubuntu-24.04\...` |

#### Ollama on Windows + WSL2

Two options:

1. **Ollama for Windows** (native): Install from ollama.com. Runs on Windows, listens on `localhost:11434`. WSL2 can reach it via `localhost` (WSL2 networking mirrors the host by default on Windows 11).
   - **x86_64**: Full support, NVIDIA GPU acceleration via CUDA.
   - **ARM64**: Experimental/limited. CPU inference works. GPU acceleration depends on Qualcomm drivers (limited ecosystem).

2. **Ollama in WSL2**: `curl -fsSL https://ollama.com/install.sh | sh` inside WSL2. NVIDIA GPU passthrough works in WSL2 (requires NVIDIA drivers for WSL). No AMD ROCm in WSL2.

**Recommendation**: Use native Ollama for Windows on x86_64 (best GPU support). On ARM64, install in WSL2 with CPU-only inference.

#### Docker on Windows + WSL2

- **Docker Desktop** with WSL2 backend: Install Docker Desktop for Windows. Enable "Use WSL 2 based engine" in settings. The `docker` CLI becomes available inside WSL2 automatically.
- **ARM64 Windows 11**: Docker Desktop is available for ARM64 Windows as of 2024. Works with both amd64 (emulated) and arm64 images.
- All Docker images used by this workshop (`pgvector/pgvector:pg18`, `grafana/otel-lgtm`, `maildev/maildev`, `dpage/pgadmin4`) publish multi-arch images including arm64.

#### WSL2-Specific Adjustments Needed

| Issue | Impact | Solution |
|-------|--------|----------|
| `open` / `xdg-open` not available in WSL2 by default | `workshop.sh` menu items 8-10 (open browser) | Add WSL2 detection: use `wslview` (from `wslu` package) or `cmd.exe /c start` |
| Line endings | Git checkout on Windows may convert `LF` to `CRLF` | Add `.gitattributes` with `*.sh text eol=lf` |
| File permissions | Windows filesystem doesn't track Unix execute bit | Set `git config core.fileMode false` in WSL2 or clone inside WSL2 filesystem (`/home/user/`) |
| Path performance | `/mnt/c/...` (Windows filesystem from WSL2) is slow for Maven builds | Clone repo inside WSL2 native fs (`~/projects/`) for 5-10x build speedup |
| `lsof` not installed by default | `workshop.sh` port detection | `sudo apt install lsof` or rely on `ss` fallback (already implemented) |

#### Required Workshop Changes for WSL2

1. **`.gitattributes`** (new file) — force LF line endings for scripts:
   ```
   *.sh text eol=lf
   mvnw text eol=lf
   .envrc text eol=lf
   ```

2. **`workshop.sh`** — add `wslview` / `cmd.exe` support in `open_url()`:
   ```bash
   open_url() {
       local url="$1"
       if command -v open &>/dev/null; then
           open "${url}"                          # macOS
       elif command -v wslview &>/dev/null; then
           wslview "${url}"                       # WSL2 (wslu package)
       elif command -v xdg-open &>/dev/null; then
           xdg-open "${url}"                      # Linux desktop
       elif command -v cmd.exe &>/dev/null; then
           cmd.exe /c start "" "${url}"           # WSL2 fallback
       else
           info "Open in browser: ${url}"
       fi
   }
   ```

3. **Workshop setup docs** — add a Windows/WSL2 section explaining:
   - Install WSL2 + Ubuntu 24.04
   - Install Docker Desktop with WSL2 backend
   - Clone the repo inside WSL2 filesystem (not `/mnt/c/`)
   - Install SDKMAN + Java 25 inside WSL2
   - Install Ollama (native Windows or WSL2)

### 4.3 Strategy B: Native PowerShell Ports (Not Recommended)

For completeness, here is the analysis of what a native Windows port would require.

#### Scripts That Would Need PowerShell Equivalents

| Script | Lines | Complexity | PowerShell Port Effort |
|--------|-------|------------|----------------------|
| `workshop.sh` | 858 | High — TUI, process mgmt, health checks, Docker orchestration | **Very High** — 2-3 days; `kill -- -$pid` has no direct equivalent, process group management differs fundamentally |
| `models/ollama.sh` | 190 | Medium — file operations, tar, interactive menu | **Medium** — 1 day; `tar` available in Windows 10+, paths need `\` conversion |
| `refresh-vertex-token.sh` | 1 | Trivial | Trivial — `gcloud auth application-default login` works on Windows |

#### Windows-Specific Translation Challenges

| Bash Feature | PowerShell Equivalent | Difficulty |
|-------------|----------------------|------------|
| `set -euo pipefail` | `$ErrorActionPreference = 'Stop'` | Easy |
| Arrays `("a" "b" "c")` | `@("a", "b", "c")` | Easy |
| `${var%%:*}` parameter expansion | `.Split(':')[0]` | Easy |
| `$'\e[0;32m'` ANSI colors | `$([char]27)[0;32m` or `Write-Host -ForegroundColor` | Medium |
| `kill -- -$pid` (process group kill) | `Stop-Process -Id $pid -Force` + find child processes manually | **Hard** |
| `lsof -ti:8080` | `Get-NetTCPConnection -LocalPort 8080` | Medium |
| `trap ... EXIT` | `try/finally` blocks | Medium |
| `mktemp -d` | `[System.IO.Path]::GetTempPath() + [System.IO.Path]::GetRandomFileName()` | Easy |
| `tar -czf` | `tar -czf` (built-in since Win10 1803) or `Compress-Archive` | Easy (tar) |
| `read -rp "prompt"` | `Read-Host "prompt"` | Easy |
| `grep -oE 'pattern'` | `Select-String -Pattern 'pattern'` | Medium |
| `docker compose` | Same | Easy |
| `curl -sf` | `Invoke-WebRequest` or `curl.exe` (aliased by default) | Medium — `curl` in PowerShell is an alias for `Invoke-WebRequest` which has different semantics |

#### Maintenance Cost

Every change to any script would need to be duplicated across bash and PowerShell versions. With `workshop.sh` alone at 858 lines plus `models/ollama.sh` at 190 lines, this creates a permanent maintenance tax.

**Verdict: Not recommended.** WSL2 eliminates the need entirely.

### 4.4 Strategy C: Hybrid (Not Recommended)

Run Java/Maven natively on Windows, bash scripts via WSL2.

| Pros | Cons |
|------|------|
| Native Java performance | Complexity: two Java installs, path confusion |
| IDE works naturally | Docker must bridge WSL2 and native Windows |
| | `workshop.sh` can't manage native Java processes |
| | Attendee confusion switching between terminals |

**Verdict: Not recommended.** Pure WSL2 is simpler and more consistent.

### 4.5 Windows ARM64 Specific Considerations

| Component | ARM64 Status |
|-----------|-------------|
| WSL2 | Fully supported, runs ARM64 Ubuntu |
| Java 25 (Adoptium/OpenJDK) | ARM64 builds available (AArch64) |
| Docker Desktop | Available for ARM64 Windows; runs arm64 containers natively, amd64 via QEMU emulation |
| Docker images (pgvector, grafana, etc.) | Multi-arch images — arm64 variants available |
| Ollama | Windows native arm64 support is limited; CPU inference works; GPU depends on Qualcomm/Snapdragon X driver support |
| Maven | Pure Java — runs on any architecture |
| Build performance | Comparable to x86_64 on Snapdragon X Elite; QEMU emulation for amd64-only images adds overhead |

### 4.6 Verdict: Windows 11

> **Supported via WSL2.** Requires:
> 1. A `.gitattributes` file to enforce LF line endings
> 2. A small `open_url()` patch in `workshop.sh` for browser opening
> 3. Setup documentation for WSL2 + Docker Desktop + SDKMAN
>
> Native PowerShell ports are **not recommended** due to high effort and ongoing maintenance cost.

---

## 5. Cross-Platform Comparison Matrix

### 5.1 Tool Availability

| Tool | macOS 26 (arm64) | Ubuntu 24.04 (amd64) | Debian 13 (amd64) | Windows 11 + WSL2 | Windows 11 Native |
|------|:-:|:-:|:-:|:-:|:-:|
| bash 3.2+ | Yes (3.2) | Yes (5.2) | Yes (5.2) | Yes (5.2 in WSL) | No |
| Java 25 | SDKMAN | SDKMAN | SDKMAN | SDKMAN (WSL) | Adoptium installer |
| Maven (wrapper) | `mvnw` | `mvnw` | `mvnw` | `mvnw` (WSL) | `mvnw.cmd` |
| Docker Compose v2 | Desktop | Engine+plugin | Engine+plugin | Desktop+WSL2 | Desktop |
| Ollama | Native (Metal) | Native (CUDA/ROCm) | Native (CUDA/ROCm) | WSL2 or native | Native (CUDA) |
| curl | Built-in | Built-in | `apt install` | Built-in (WSL) | `curl.exe` |
| git | Xcode CLT | `apt install` | `apt install` | `apt install` (WSL) | Git for Windows |
| lsof | Built-in | `apt install` | `apt install` | `apt install` (WSL) | N/A |
| ss | N/A | Built-in | Built-in | Built-in (WSL) | N/A |
| open/xdg-open | `open` | `xdg-open` | `xdg-open` | `wslview`/`cmd.exe` | `start` |

### 5.2 Script Compatibility

| Script | macOS 26 | Ubuntu 24.04 | Debian 13 | Win11 + WSL2 | Win11 Native |
|--------|:-:|:-:|:-:|:-:|:-:|
| `workshop.sh` | Yes | Yes | Yes | Yes (with `open_url` patch) | No |
| `models/ollama.sh` | Yes | Yes | Yes | Yes | No |
| `mvnw` | Yes | Yes | Yes | Yes | N/A (use `mvnw.cmd`) |
| `mvnw.cmd` | N/A | N/A | N/A | N/A | Yes |

> `docker/postgres/pg` and `docker/observability-stack/ostack` are excluded — they manage Docker containers which run independently of the host OS.

### 5.3 Docker Image Architecture

| Image | amd64 | arm64 | Notes |
|-------|:-:|:-:|-------|
| `pgvector/pgvector:pg18` | Yes | Yes | Multi-arch |
| `grafana/otel-lgtm:latest` | Yes | Yes | Multi-arch |
| `maildev/maildev:2.2.1` | Yes | Yes | Multi-arch |
| `dpage/pgadmin4:latest` | Yes | Yes | Multi-arch |

---

## 6. Recommendations

### 6.1 Minimal Required Changes

These changes should be made to support all target platforms:

#### 1. Add `.gitattributes` (new file in project root)

```gitattributes
# Force LF line endings for all shell scripts (critical for WSL2 on Windows)
*.sh text eol=lf
mvnw text eol=lf
.envrc text eol=lf

# Windows scripts keep CRLF
*.cmd text eol=crlf
*.bat text eol=crlf
*.ps1 text eol=crlf
```

#### 2. Patch `open_url()` in `workshop.sh`

Add WSL2 browser support (see section 4.2 for code).

#### 3. Workshop Setup Documentation

Create per-OS setup guides in `support/` or `docs/`:
- `setup-macos.md` — Homebrew, SDKMAN, Docker Desktop, Ollama
- `setup-linux.md` — APT repos, SDKMAN, Docker Engine, Ollama
- `setup-windows.md` — WSL2, Docker Desktop, SDKMAN in WSL, Ollama

### 6.2 Optional Improvements

| Improvement | Effort | Benefit |
|-------------|--------|---------|
| Add OS detection to `workshop.sh check` that warns WSL2 users to clone inside WSL filesystem | Low | Prevents slow build performance |
| Add `wslview` install hint when running in WSL2 without browser opener | Low | Better UX |
| Create a unified `setup.sh` that detects OS and runs the right setup steps | Medium | Single entry point for all platforms |
| Add Windows ARM64 Ollama CPU-only warning in `workshop.sh check` | Low | Set expectations for ARM64 Windows users |

### 6.3 What NOT to Do

- **Do not create PowerShell ports** of existing scripts. WSL2 provides a complete Linux environment with zero script changes.
- **Do not require native Windows Java**. Running everything inside WSL2 is simpler and avoids path/encoding issues.
- **Do not split into "Windows way" and "Unix way"**. One consistent Linux-based workflow for all platforms (macOS native, Linux native, Windows via WSL2).

---

## Summary

| Platform | Support Status | Changes Needed |
|----------|---------------|----------------|
| **macOS 26+ (arm64/x86_64)** | Fully supported | None |
| **Ubuntu 24.04 LTS** | Fully supported | None |
| **Debian 13 / kernel 6.8+** | Fully supported | None (same as Ubuntu) |
| **Windows 11 x86_64 (WSL2)** | Supported with minor changes | `.gitattributes`, `open_url()` patch, setup docs |
| **Windows 11 ARM64 (WSL2)** | Supported with caveats | Same as x86_64 + Ollama limited to CPU inference |
| **Windows 11 Native** | Not recommended | Would require PowerShell ports of all scripts |
