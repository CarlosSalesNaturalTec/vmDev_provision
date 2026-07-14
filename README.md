# vmDev_provision

## Objetivo

Este repositório provisiona uma VM descartável do Google Cloud usada como host remoto para agentes de código de IA (Claude Code + OpenSpec + CI/E2E). São dois scripts, não uma aplicação:

- `provision.ps1` — executa na máquina Windows do operador (PowerShell / Google Cloud SDK Shell). Configura o projeto GCP, uma regra de firewall para SSH via IAP, um Cloud Router + Cloud NAT e cria a VM.
- `startup.sh` — passado para a VM como metadado `startup-script` do GCE (veja `provision.ps1:43`). Executa uma vez como root no primeiro boot para instalar o toolchain (pacotes base, Docker, Node 22, dependências de SO do Playwright, Python, GitHub CLI, tmux, git). Sua saída é gravada em `/var/log/startup-script-progress.log`.

Os dois arquivos são acoplados: `provision.ps1` injeta `startup.sh` na VM. Alterar o toolchain instalado significa editar `startup.sh`; alterar tamanho/zona/imagem da VM significa editar `provision.ps1`.

## Execução

```powershell
# Pré-requisito: gcloud auth login já realizado neste shell.
# Edite $PROJECT_ID em provision.ps1 primeiro (placeholder padrão "seu-projeto-id").
./provision.ps1

# Conecte assim que o startup-script terminar (~1-10 min após a criação):
gcloud compute ssh [sua_conta_google]@claude-code-vm --zone=us-central1-a --tunnel-through-iap

Ex: gcloud compute ssh naturalbahia@claude-code-vm --zone=us-central1-a --tunnel-through-iap
```

Não há etapa de build, lint ou teste. A verificação é operacional: execute o `provision.ps1`, depois conecte via SSH e confirme se as ferramentas foram instaladas. 

Verifique se o startup-script terminou sem erro com `cat /var/log/startup-script-progress.log` — deve terminar na linha `== [7/7] Concluido ==`.

## Autentique o GitHub CLI uma vez por VM (necessário para clonar repos privados)
`gh auth login`
* GitHub.com → HTTPS → autenticar via navegador.  
* Copie a url fornecida, cole em um navegador e aprove

## Criar pasta para projetos
```
# Direto na conexão SSH, sem nem precisar abrir tmux ainda
mkdir -p ~/projetos
```

# Preparando um novo repositório na VM

Depois de conectar via SSH, um fluxo típico para clonar um projeto e deixá-lo pronto para rodar (incluindo testes E2E com Playwright) é:

```bash
# Abra (ou reconecte a) uma sessão tmux, para o trabalho sobreviver a quedas da conexão SSH
tmux new -s dev        # cria a sessão "dev"
tmux attach -t dev     # reconecta a uma sessão já existente
# Ctrl+b d para se desconectar sem encerrar a sessão

tmux ls                # lista as sessões ativas
tmux kill-session -t dev  # encerra a sessão "dev"

# Clone o repositório
cd ~/projetos
git clone https://github.com/<org>/<repo>.git
cd <repo>

# Instale as dependências do projeto
npm install

# Instale os binários dos navegadores do Playwright (as libs de SO já foram
# instaladas pelo startup.sh — veja "== [4/7] Dependencias de sistema do Playwright ==")
npx playwright install chromium firefox webkit

```

Como a VM não tem IP externo, todo esse fluxo (clone, npm install, download dos binários do Playwright) depende do Cloud NAT descrito abaixo — se algum passo travar ou falhar ao resolver DNS/baixar pacotes, confirme que o NAT está configurado.

## Detalhes importantes a preservar ao editar

- **Sem IP externo** (`--no-address`): a VM é acessível apenas via SSH sobre IAP. A regra de firewall permite `tcp:22` somente a partir da faixa IAP `35.235.240.0/20`. Não adicione um endereço público nem abra outras portas sem motivo.
- **Cloud NAT é obrigatório, não opcional**: como a VM não tem IP externo, o acesso à internet de saída (Docker Hub, GitHub, npm, claude.ai, NodeSource) só funciona através do Cloud Router (`nat-router`) + NAT (`nat-config`) criados em `provision.ps1`. Sem eles a VM só acessa o mirror interno do Ubuntu e o `startup.sh` falha. Não remova isso ao editar.
- **Identificadores da VM** (`$PROJECT_ID`, `$ZONE`, `$REGION`, `$VM_NAME`) são definidos uma única vez no topo de `provision.ps1` e reutilizados; o comando SSH no `Write-Host` final e qualquer documentação devem coincidir com eles. `$REGION` é usado pelo router/NAT (que são regionais); `$ZONE` pela VM.
- **`startup.sh` executa como root, de forma não interativa, com `set -e`** — cada etapa do apt deve ser não interativa e tolerante à idempotência em uma imagem Ubuntu 24.04 limpa. A criação da regra de firewall e do router/NAT em `provision.ps1` deve retornar erro "already exists" em novas execuções (são por projeto/região, uma única vez); isso é seguro e pode ser ignorado.
- Node 22 é exigido pelo OpenSpec CLI, Next.js e Playwright; o venv/pip do Python é para um backend FastAPI. Isso restringe atualizações de versão no `startup.sh`.

## Bloco para colar no CLAUDE.md de cada novo projeto

Toda vez que um novo repositório for clonado e configurado nesta VM (`claude-code-vm`), rode `/init` no Claude Code normalmente para gerar o `CLAUDE.md` daquele projeto — e
depois cole o bloco abaixo nele (ex.: entre as seções `Commands` e `Architecture`, se o `CLAUDE.md` gerado seguir essa estrutura). Isso mantém o Claude Code ciente do ambiente
compartilhado sem precisar redescobrir isso a cada sessão, e evita reinstalar algo que já está pronto na VM.

Este bloco é a fonte de verdade — se o toolchain do `startup.sh` mudar (nova versão do Node, novo componente instalado), atualize aqui também, e replique nos `CLAUDE.md` dos
projetos já existentes.

````markdown
## Environment (GCP VM)

This repo runs on a dedicated Compute Engine VM (Ubuntu 24.04, `us-central1-a`, no
external IP — egress via Cloud NAT). Other unrelated projects may be running
concurrently on the same VM, each in its own tmux session — don't assume exclusive use
of the machine, and check for port conflicts (e.g. local Postgres, dev servers) before
binding.

Pre-installed at the VM level — don't reinstall or re-provision these:
- Docker + `docker-compose-v2`, enabled
- Node.js 22 LTS, Python 3.12, `gh` (already authenticated)
- Playwright OS-level dependencies (`playwright install-deps` already run) — when
  setting up Playwright for this repo, run `npx playwright install chromium firefox webkit`
  **without** `--with-deps`; the system libraries are already present

Not shared / per-checkout: Playwright's browser *binaries* are cached per project
(tied to the `@playwright/test` version in this repo's `package.json`), so they still
need to be installed once per checkout with the command above.
````