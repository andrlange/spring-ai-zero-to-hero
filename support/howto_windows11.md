# Windows 11 Setup Guide — Spring AI Zero-to-Hero Workshop

> **Target stack:** Spring Boot 4.0.5 | Spring AI 2.0.0-M4 | Java 25 | Maven 3.9.14
>
> This guide uses **WSL2 with Ubuntu 24.04** as the primary environment.
> All workshop scripts run natively inside WSL2 — no PowerShell ports needed.
>
> **Important:** This guide requires **Windows 11 on physical hardware** (Intel, AMD, or Snapdragon/Qualcomm). Running Windows 11 inside a virtual machine (Parallels, UTM, VMware Fusion on macOS) does **not** work — WSL2 requires hardware virtualization that nested VMs cannot provide. WSL1 is not sufficient either, as it lacks Docker and systemd support. If you are on a Mac, run the workshop directly on macOS.

---

## Table of Contents

1. [Overview](#1-overview)
2. [Install WSL2 with Ubuntu 24.04](#2-install-wsl2-with-ubuntu-2404)
3. [Install Docker Desktop](#3-install-docker-desktop)
4. [Install Java 25 (inside WSL2)](#4-install-java-25-inside-wsl2)
5. [Install Ollama](#5-install-ollama)
6. [Clone the Workshop Repository](#6-clone-the-workshop-repository)
7. [IDE Setup](#7-ide-setup)
8. [Run the Workshop](#8-run-the-workshop)
9. [Troubleshooting](#9-troubleshooting)
10. [ARM64 (Snapdragon / Qualcomm) Notes](#10-arm64-snapdragon--qualcomm-notes)

---

## 1. Overview

The workshop runs entirely inside WSL2 (Windows Subsystem for Linux 2). WSL2 provides a real Linux kernel, so all bash scripts, Maven, Java, and Docker work identically to a native Ubuntu machine. Your Windows browser, IDE, and GPU are still accessible.

### Architecture at a Glance

```
 Windows 11
 +-----------------------------------------+
 |  Browser (Swagger, Grafana, Dashboard)  |
 |  IDE (VS Code / IntelliJ)               |
 |  Docker Desktop (WSL2 backend)          |
 |  Ollama (option A: native Windows)      |
 +-----------------------------------------+
          |  localhost ports shared
 +-----------------------------------------+
 |  WSL2 — Ubuntu 24.04                    |
 |    Java 25 (SDKMAN)                     |
 |    Maven (wrapper — ./mvnw)             |
 |    workshop.sh, ollama.sh               |
 |    docker CLI (from Docker Desktop)     |
 |    Ollama (option B: WSL2 install)      |
 |    git, curl, ss                        |
 +-----------------------------------------+
```

Ports published inside WSL2 (e.g., `localhost:8080`) are automatically accessible from your Windows browser — no extra configuration needed.

---

## 2. Install WSL2 with Ubuntu 24.04

### 2.1 Enable WSL2 and Update

Open **PowerShell as Administrator** and run:

```powershell
wsl --install --no-distribution
```

This enables the required Windows features (**Virtual Machine Platform** and **Windows Subsystem for Linux**) without installing a default distro. **Reboot Windows** after this step.

After rebooting, open PowerShell again and update WSL:

```powershell
wsl --update
wsl --set-default-version 2
```

The `--set-default-version 2` ensures all new distributions use WSL2 (not WSL1). This is important — older WSL versions may not list Ubuntu 24.04 as an available distribution.

### 2.2 Check Available Distributions

```powershell
wsl --list --online
```

Look for Ubuntu 24.04 in the output. The exact name varies — it may appear as `Ubuntu-24.04`, `Ubuntu24.04LTS`, or simply `Ubuntu`. Note the exact name shown in the `NAME` column.

### 2.3 Install Ubuntu 24.04

Use the exact name from the previous step:

```powershell
wsl --install -d Ubuntu-24.04
```

If that gives an error like `WSL_E_DISTRO_NOT_FOUND`, try these alternatives:

```powershell
# Try without the hyphen
wsl --install -d Ubuntu24.04LTS

# Or install the latest Ubuntu (currently 24.04)
wsl --install -d Ubuntu
```

If none of these work, install **Ubuntu 24.04 LTS** directly from the **Microsoft Store** app — search for "Ubuntu 24.04".

You will be prompted to create a Linux username and password.

**Reboot Windows after the installation completes.** WSL2 requires a restart to fully initialize the Linux kernel and networking layer. Without a reboot, you may encounter errors when launching the distribution or connecting to Docker.

### 2.4 Verify the Distro Name

After installation, check what name WSL assigned to your distribution:

```powershell
wsl --list --verbose
```

This shows all installed distributions with their exact names and WSL version. Example output:

```
  NAME            STATE           VERSION
* Ubuntu-24.04    Running         2
```

Use this exact name whenever you need to launch or reference the distribution (e.g., `wsl -d Ubuntu-24.04`).

### 2.5 Launch and Verify

Open a new terminal (Windows Terminal recommended) and launch Ubuntu using the name from the previous step:

```powershell
wsl -d Ubuntu-24.04
```

Inside the Ubuntu shell, verify:

```bash
lsb_release -a
# Should show: Ubuntu 24.04.x LTS

bash --version
# Should show: GNU bash, version 5.2.x
```

### 2.3 Enable systemd

WSL2 needs systemd enabled for Docker and other services to work correctly. Check if it's already enabled:

```bash
cat /etc/wsl.conf
```

If the file doesn't exist or doesn't contain `[boot] systemd=true`, create/update it:

```bash
sudo bash -c 'cat > /etc/wsl.conf << EOF
[boot]
systemd=true
EOF'
```

Then **shut down and restart** the WSL2 instance (see next section).

### How to Reboot WSL2

WSL2 has no `reboot` command inside the Linux shell. The lifecycle is controlled from Windows. To restart your Ubuntu instance, open **Windows PowerShell** and run:

```powershell
wsl --shutdown
wsl -d Ubuntu-24.04
```

`wsl --shutdown` stops **all** running WSL2 instances. The second command relaunches Ubuntu. Use this whenever the guide says "restart WSL2".

### 2.4 Update System Packages

```bash
sudo apt update && sudo apt upgrade -y
```

If the upgrade fails with a `systemd` error like:

```
Failed to take /etc/passwd lock: Invalid argument
dpkg: error processing package systemd (--configure)
```

This is a known WSL2 bug where `systemd-sysusers` cannot acquire a file lock during package configuration — even when systemd is enabled in `wsl.conf`. The `systemd` post-install script calls `systemd-sysusers` which tries to lock `/etc/passwd`, but the WSL2 kernel rejects the lock syscall with `Invalid argument`.

**Step 1 — Verify systemd is enabled:**

```bash
cat /etc/wsl.conf
# Must contain:
#   [boot]
#   systemd=true

# If missing, create it:
sudo bash -c 'cat > /etc/wsl.conf << EOF
[boot]
systemd=true
EOF'
```

Restart WSL2 (from Windows PowerShell):

```powershell
wsl --shutdown
wsl -d Ubuntu-24.04
```

**Step 2 — Retry the upgrade:**

```bash
sudo dpkg --configure -a
sudo apt upgrade -y
```

**Step 3 — If it still fails with `Failed to take /etc/passwd lock`:**

The system users that `systemd-sysusers` needs to create already exist in a fresh Ubuntu install. The workaround is to temporarily replace `systemd-sysusers` with a no-op script:

```bash
# Back up the real binary
sudo cp /usr/bin/systemd-sysusers /usr/bin/systemd-sysusers.bak

# Replace with a no-op script
sudo bash -c 'printf "#!/bin/sh\nexit 0\n" > /usr/bin/systemd-sysusers'
sudo chmod +x /usr/bin/systemd-sysusers

# Fix the broken packages
sudo dpkg --configure -a

# Restore the real binary
sudo mv /usr/bin/systemd-sysusers.bak /usr/bin/systemd-sysusers

# Finish the upgrade
sudo apt upgrade -y
```

### 2.4 Install Essential Tools

```bash
sudo apt install -y git curl unzip zip wslu
```

The `wslu` package provides `wslview`, which allows the workshop scripts to open URLs in your Windows browser directly from WSL2.

---

## 3. Install Docker Desktop

### 3.1 Download and Install

Download **Docker Desktop for Windows** from https://www.docker.com/products/docker-desktop/ and run the installer.

During installation, ensure **"Use WSL 2 based engine"** is checked.

### 3.2 Enable WSL2 Integration

After installation:

1. Open Docker Desktop
2. Go to **Settings > Resources > WSL Integration**
3. Enable integration with your **Ubuntu-24.04** distribution
4. Click **Apply & restart**

If Docker Desktop shows **"You don't have any WSL 2 distros installed"**, your Ubuntu is running as WSL1 instead of WSL2. Fix from Windows PowerShell:

```powershell
# Check the VERSION column
wsl --list --verbose

# If Ubuntu shows VERSION 1, convert it:
wsl --set-version Ubuntu-24.04 2
```

If the conversion fails with `HCS_E_HYPERV_NOT_INSTALLED`, the Virtual Machine Platform is not enabled. Run `wsl --install --no-distribution` from an Administrator PowerShell and reboot (see [step 2.1](#21-enable-wsl2-and-update)).

### 3.3 Verify Docker in WSL2

Open your Ubuntu terminal and run:

```bash
docker --version
# Should show: Docker version 27.x or later

docker compose version
# Should show: Docker Compose version v2.x

docker run --rm hello-world
# Should print: Hello from Docker!
```

The `docker` CLI is now available inside WSL2, backed by Docker Desktop's engine.

### 3.4 Resource Allocation

The workshop runs PostgreSQL (pgvector), Grafana LGTM stack, and a Spring Boot application simultaneously. Increase Docker Desktop resources:

1. **Settings > Resources > Advanced**
2. Set memory to at least **6 GB** (8 GB recommended)
3. Set CPUs to at least **4**

---

## 4. Install Java 25 (inside WSL2)

All commands in this section run inside your WSL2 Ubuntu terminal.

### 4.1 Install SDKMAN

```bash
curl -s "https://get.sdkman.io" | bash
source "$HOME/.sdkman/bin/sdkman-init.sh"

sdk version
# Should show: SDKMAN! 5.x.x
```

### 4.2 Install Java 25

```bash
sdk install java 25.0.2-librca
sdk use java 25.0.2-librca
```

Verify:

```bash
java -version
# Should show: openjdk version "25.0.2" ...

javac -version
# Should show: javac 25.0.2
```

SDKMAN sets `JAVA_HOME` automatically. The Maven wrapper (`./mvnw`) will use this JDK.

---

## 5. Install Ollama

You have two options. Choose **one**.

### Option A: Ollama on Windows (Recommended for NVIDIA GPUs)

This is the best option if you have an NVIDIA GPU — it gets full CUDA acceleration natively.

1. Download and install from https://ollama.com/download/windows
2. After installation, Ollama runs as a background service on `localhost:11434`
3. Open a **Windows** terminal (PowerShell or CMD) and pull the workshop models:

```powershell
ollama pull mistral
ollama pull nomic-embed-text
ollama pull llava
```

4. Verify from inside WSL2 — the Ollama server is accessible via localhost:

```bash
curl -s http://localhost:11434/api/tags | head -20
# Should show JSON with your pulled models
```

WSL2 mirrors the Windows network by default, so `localhost:11434` reaches the Windows Ollama server without any configuration.

### Option B: Ollama inside WSL2

This option keeps everything inside WSL2. NVIDIA GPU passthrough works if you have the NVIDIA WSL drivers installed. AMD GPUs are not supported in WSL2.

1. Inside your WSL2 Ubuntu terminal:

```bash
curl -fsSL https://ollama.com/install.sh | sh
```

2. Start the Ollama server:

```bash
ollama serve &
```

3. Pull the workshop models:

```bash
ollama pull mistral
ollama pull nomic-embed-text
ollama pull llava
```

4. Verify:

```bash
ollama list
# Should show: mistral, nomic-embed-text, llava
```

### Which Option Should I Choose?

| Scenario | Recommendation |
|----------|---------------|
| NVIDIA GPU (x86_64) | **Option A** — best GPU acceleration |
| No GPU / Intel integrated | **Option B** — simpler, CPU inference |
| AMD GPU | **Option A** — DirectML support on Windows |
| ARM64 / Snapdragon | **Option B** — see [ARM64 notes](#10-arm64-snapdragon--qualcomm-notes) |

---

## 6. Clone the Workshop Repository

### 6.1 Clone Inside the WSL2 Filesystem

**Important:** Always clone the repository inside the WSL2 native filesystem (`/home/...`), **not** on the Windows drive (`/mnt/c/...`). The Windows filesystem accessed from WSL2 is 5-10x slower for I/O-heavy operations like Maven builds.

```bash
mkdir -p ~/projects
cd ~/projects
git clone https://github.com/<your-org>/spring-ai-zero-to-hero.git
cd spring-ai-zero-to-hero
```

### 6.2 Verify Git Line Endings

The repository includes a `.gitattributes` file that ensures shell scripts keep LF line endings on Windows. Verify:

```bash
file workshop.sh
# Should show: ... Bourne-Again shell script, ASCII text executable
# If it shows "CRLF" or "with CRLF line terminators", run:
# git config core.autocrlf input
# git checkout -- .
```

### 6.3 Verify Script Permissions

```bash
ls -la workshop.sh models/ollama.sh
# Both should show -rwxr-xr-x (executable)

# If not executable:
chmod +x workshop.sh models/ollama.sh
```

---

## 7. IDE Setup

### 7.1 VS Code (Recommended for WSL2)

VS Code has first-class WSL2 support via the Remote-WSL extension.

1. Install **VS Code** on Windows from https://code.visualstudio.com/
2. Install the **WSL** extension (ms-vscode-remote.remote-wsl)
3. From your WSL2 terminal, inside the project directory:

```bash
code .
```

This opens VS Code on Windows, connected to the WSL2 filesystem. The integrated terminal runs inside WSL2. All file operations happen on the Linux filesystem — fast and correct.

Install these VS Code extensions for the best experience:
- Extension Pack for Java
- Spring Boot Extension Pack
- Docker

### 7.2 IntelliJ IDEA

IntelliJ can open projects from the WSL2 filesystem:

1. Open IntelliJ on Windows
2. **File > Open** and navigate to `\\wsl$\Ubuntu-24.04\home\<username>\projects\spring-ai-zero-to-hero`
3. Configure the project JDK:
   - **File > Project Structure > SDKs > Add SDK > WSL**
   - Point to the SDKMAN Java installation: `/home/<username>/.sdkman/candidates/java/25.0.2-librca`

Alternatively, IntelliJ 2024.2+ has built-in WSL support under **File > Remote Development > WSL**.

---

## 8. Run the Workshop

All commands run inside your WSL2 Ubuntu terminal.

### 8.1 Prerequisites Check

```bash
cd ~/projects/spring-ai-zero-to-hero
./workshop.sh check
```

This verifies Java, Maven, Docker, and Ollama are installed and accessible. Fix any items marked with a red cross.

### 8.2 Setup (First Time)

```bash
./workshop.sh setup
```

This pulls Docker images, Ollama models, and compiles the project. Takes a few minutes on the first run.

### 8.3 Start the Workshop

Interactive mode — shows a TUI menu:

```bash
./workshop.sh
```

Or start directly with a specific provider:

```bash
# Ollama provider with pgvector + observability + dashboard
./workshop.sh start ollama --profiles pgvector,observation,ui
```

### 8.4 Access the Web UIs

Open these URLs in your **Windows browser** — WSL2 ports are automatically forwarded:

| Service | URL |
|---------|-----|
| Workshop Dashboard | http://localhost:8080/dashboard |
| Swagger UI | http://localhost:8080/swagger-ui.html |
| Grafana | http://localhost:3000 |
| pgAdmin | http://localhost:15433 |

If the `workshop.sh` menu "Open" options don't launch your browser automatically, install `wslu`:

```bash
sudo apt install wslu
```

This provides `wslview` which opens URLs in your default Windows browser.

### 8.5 Stop the Workshop

```bash
./workshop.sh stop
```

### 8.6 Ollama Model Management

```bash
# Interactive menu
./models/ollama.sh

# Or direct commands
./models/ollama.sh list      # Check which models are installed
./models/ollama.sh pull      # Pull all workshop models
./models/ollama.sh export    # Export models to models.tar.gz
./models/ollama.sh import    # Import models from models.tar.gz
```

If you installed Ollama on Windows (Option A), the `ollama.sh` script's `list` and `pull` commands call the `ollama` CLI — make sure the Ollama CLI is accessible inside WSL2. You can verify with:

```bash
# If Ollama is on Windows, the CLI won't be in WSL2 PATH.
# Use the export/import feature instead, or install the CLI in WSL2 too:
curl -fsSL https://ollama.com/install.sh | sh
# (The CLI will connect to whichever Ollama server is listening on localhost:11434)
```

---

## 9. Troubleshooting

### Port 8080 already in use

```bash
# Check what's using the port
ss -tlnp | grep :8080

# Stop the workshop and any orphaned processes
./workshop.sh stop
```

### Docker commands fail inside WSL2

```
Cannot connect to the Docker daemon
```

1. Ensure Docker Desktop is **running** on Windows
2. Check WSL integration: **Docker Desktop > Settings > Resources > WSL Integration** — Ubuntu-24.04 must be enabled
3. Restart the WSL2 instance:

```powershell
# From Windows PowerShell:
wsl --shutdown
wsl -d Ubuntu-24.04
```

### Maven build is very slow

You are likely running from the Windows filesystem (`/mnt/c/...`). Move the project to the WSL2 native filesystem:

```bash
mv /mnt/c/Users/<name>/projects/spring-ai-zero-to-hero ~/projects/
cd ~/projects/spring-ai-zero-to-hero
```

### Ollama not reachable from WSL2

If Ollama runs on Windows (Option A) but `curl http://localhost:11434` fails from WSL2:

1. Check that Ollama is running on Windows (look for the Ollama icon in the system tray)
2. Verify WSL2 networking mode — in newer Windows 11 builds, mirrored networking is default. Check with:

```powershell
# From Windows PowerShell:
wsl --version
```

If networking is in NAT mode, you may need to use the Windows host IP instead of `localhost`:

```bash
# Inside WSL2, find the Windows host IP:
ip route show default | awk '{print $3}'
# Use that IP instead of localhost in application.yaml
```

### Shell scripts show errors about `\r`

This means line endings were converted to CRLF. Fix with:

```bash
# Fix line endings
git config core.autocrlf input
git rm --cached -r .
git reset --hard HEAD
```

Or reinstall by cloning fresh inside WSL2 (not from a Windows-cloned copy).

### "Permission denied" running scripts

```bash
chmod +x workshop.sh models/ollama.sh
```

If this happens repeatedly, clone the repo inside the WSL2 filesystem (`~/projects/`), not on `/mnt/c/...`.

### WSL2 conversion fails with `HCS_E_HYPERV_NOT_INSTALLED`

```
WSL2 wird von Ihrer aktuellen Computerkonfiguration nicht unterstützt.
Fehlercode: Wsl/Service/CreateVm/HCS/HCS_E_HYPERV_NOT_INSTALLED
```

**On physical hardware:** Enable all required Windows features from PowerShell as Administrator:

```powershell
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
dism.exe /online /enable-feature /featurename:Microsoft-Hyper-V-All /all /norestart
```

Reboot Windows, then retry `wsl --set-version Ubuntu-24.04 2`.

If Hyper-V is not available (e.g., Windows 11 Home), try:

```powershell
dism.exe /online /enable-feature /featurename:Microsoft-Hyper-V /all /norestart
```

**On a virtual machine (Parallels, UTM, VMware Fusion):** WSL2 requires nested virtualization — a VM inside a VM. This must be enabled in the host hypervisor:

- **Parallels Pro/Business on Apple Silicon**: Even with "Nested Virtualization" enabled via `prlctl set "<VM>" --nested-virt on` and "Adaptive Hypervisor" disabled, WSL2 may still fail with `HCS_E_HYPERV_NOT_INSTALLED` on Parallels 26 + Apple Silicon. This is a known limitation — the Apple Hypervisor.framework does not fully expose the virtualization extensions needed for Hyper-V inside an ARM64 guest. **WSL2 inside Parallels on Apple Silicon is currently not reliable.** Note: Parallels **Standard** edition does not support nested virtualization at all.
- **VMware Fusion**: Shut down VM > Settings > Processors & Memory > Advanced > enable **"Enable hypervisor applications in this virtual machine"**
- **UTM**: Nested virtualization is not supported on Apple Silicon

To check if you're running inside a VM, run from PowerShell:

```powershell
Get-CimInstance Win32_Processor | Select-Object Name
# "Apple Silicon" or "Virtual" in the name indicates a VM
```

**If you are running Windows in a VM on a Mac, WSL2 will most likely not work.** Run the workshop directly on macOS instead — it is fully supported with no changes needed (see the main README).

This limitation does **not** affect attendees running Windows 11 on real hardware (Intel, AMD, Snapdragon) — WSL2 works natively without nested virtualization on physical machines.

### WSL2 runs out of memory

WSL2 defaults to using 50% of host RAM (capped at 8 GB on older builds). Create or edit `%USERPROFILE%\.wslconfig` on Windows:

```ini
[wsl2]
memory=8GB
processors=4
```

Then restart WSL2:

```powershell
wsl --shutdown
```

---

## 10. ARM64 (Snapdragon / Qualcomm) Notes

> **Important:** This section applies to **native ARM64 hardware** (e.g., Surface Pro with Snapdragon X, Lenovo ThinkPad with Qualcomm). If you are running Windows 11 ARM64 as a **virtual machine** on Apple Silicon (via Parallels, UTM, or VMware Fusion), WSL2 requires nested virtualization — see [troubleshooting](#wsl2-conversion-fails-with-hcs_e_hyperv_not_installed). If nested virtualization is not available, run the workshop directly on macOS instead.

Windows 11 on ARM64 is supported with these caveats:

| Component | ARM64 Status | Notes |
|-----------|:---:|-------|
| WSL2 | Supported | Runs ARM64 Ubuntu natively |
| Java 25 | Supported | SDKMAN provides AArch64 builds |
| Maven | Supported | Pure Java — architecture independent |
| Docker Desktop | Supported | Runs arm64 containers natively; amd64 images via QEMU emulation (slower) |
| Docker images (pgvector, grafana, etc.) | Supported | All workshop images publish arm64 variants |
| Ollama | Limited | CPU inference works; GPU acceleration depends on Qualcomm driver support (limited ecosystem) |

### Performance Expectations on ARM64

- **Build times**: Comparable to x86_64 on Snapdragon X Elite / X Plus
- **Ollama inference**: CPU-only inference is slower than GPU-accelerated. Expect ~5-15 tokens/sec for `mistral` on Snapdragon X Elite. Sufficient for the workshop but noticeably slower than NVIDIA GPU
- **Docker**: Native arm64 images run at full speed. If an image only has amd64, Docker uses QEMU emulation (~2-5x slower) — this does not affect our workshop since all images are multi-arch

### ARM64 Setup Differences

The setup is identical to x86_64 with one exception:

- **Ollama**: Use **Option B** (install inside WSL2). The Windows native Ollama client has limited ARM64 GPU support.

```bash
# Inside WSL2
curl -fsSL https://ollama.com/install.sh | sh
ollama serve &
ollama pull mistral
ollama pull nomic-embed-text
ollama pull llava
```
