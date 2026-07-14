#!/bin/bash
set -e
exec > >(tee /var/log/startup-script-progress.log) 2>&1

echo "== [1/6] Pacotes base =="
apt-get update -y
apt-get install -y tmux git curl build-essential ca-certificates gnupg

echo "== [2/6] Docker (pacote docker.io do Ubuntu) =="
apt-get install -y docker.io docker-compose-v2
systemctl enable --now docker

echo "== [3/6] Node.js 22 LTS (OpenSpec CLI, Next.js, Playwright) =="
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt-get install -y nodejs

echo "== [4/6] Python (backend FastAPI) =="
apt-get install -y python3-pip python3-venv

echo "== [5/6] GitHub CLI =="
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list
apt-get update -y
apt-get install -y gh

echo "== [6/6] Concluido =="
