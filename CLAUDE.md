# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

This repo provisions a disposable Google Cloud VM used as a remote host for AI coding agents (Claude Code + OpenSpec + CI/E2E). It is two scripts, not an application:

- `provision.ps1` — runs on the operator's Windows machine (PowerShell / Google Cloud SDK Shell). Configures the GCP project, an IAP-SSH firewall rule, a Cloud Router + Cloud NAT, and creates the VM.
- `startup.sh` — passed to the VM as the GCE `startup-script` metadata (see `provision.ps1:43`). Runs once as root on first boot to install the toolchain (base packages, Docker, Node 22, Playwright OS dependencies, Python, GitHub CLI, tmux, git). Its output is teed to `/var/log/startup-script-progress.log`.

The two files are coupled: `provision.ps1` injects `startup.sh` into the VM. Editing the installed toolchain means editing `startup.sh`; editing VM size/zone/image means editing `provision.ps1`.

## Running

```powershell
# Prerequisite: gcloud auth login already done in this shell.
# Edit $PROJECT_ID in provision.ps1 first (default placeholder "seu-projeto-id").
./provision.ps1

# Connect once the startup-script finishes (~1-2 min after create):
gcloud compute ssh claude-code-vm --zone=us-central1-a --tunnel-through-iap
```

There is no build, lint, or test step. Verification is operational: run `provision.ps1`, then SSH in and confirm the tools installed. Check the startup script finished cleanly with `cat /var/log/startup-script-progress.log` — it should end on `== [7/7] Concluido ==`.

## Key details to preserve when editing

- **No external IP** (`--no-address`): the VM is reachable only via SSH-over-IAP. The firewall rule allows `tcp:22` from the IAP range `35.235.240.0/20` only. Do not add a public address or open other ports without reason.
- **Cloud NAT is mandatory, not optional**: because the VM has no external IP, outbound internet (Docker Hub, GitHub, npm, claude.ai, NodeSource) only works through the Cloud Router (`nat-router`) + NAT (`nat-config`) created in `provision.ps1`. Without them the VM can reach only Ubuntu's internal mirror and `startup.sh` fails. Do not remove these when editing.
- **VM identifiers** (`$PROJECT_ID`, `$ZONE`, `$REGION`, `$VM_NAME`) are defined once at the top of `provision.ps1` and reused; the SSH command in the closing `Write-Host` and any docs must match them. `$REGION` is used by the router/NAT (which are regional); `$ZONE` by the VM.
- **`startup.sh` runs as root, non-interactively, with `set -e`** — every apt step must be non-interactive and idempotent-tolerant on a fresh Ubuntu 24.04 image. The firewall-rule and router/NAT creates in `provision.ps1` are expected to error with "already exists" on re-runs (they are per-project/per-region, one-time); that is safe to ignore.
- Node 22 is required by OpenSpec CLI, Next.js, and Playwright; Python venv/pip is for a FastAPI backend. These constrain version bumps in `startup.sh`.
