# vmDev_provision

## Objetivo

Este repositório provisiona uma VM descartável do Google Cloud usada como host remoto para agentes de código de IA (Claude Code + OpenSpec + CI/E2E). São dois scripts, não uma aplicação:

- `provision.ps1` — executa na máquina Windows do operador (PowerShell / Google Cloud SDK Shell). Configura o projeto GCP, uma regra de firewall para SSH via IAP e cria a VM.
- `startup.sh` — passado para a VM como metadado `startup-script` do GCE (veja `provision.ps1:31`). Executa uma vez como root no primeiro boot para instalar o toolchain (Docker, Node 22, Python, GitHub CLI, tmux, git).

Os dois arquivos são acoplados: `provision.ps1` injeta `startup.sh` na VM. Alterar o toolchain instalado significa editar `startup.sh`; alterar tamanho/zona/imagem da VM significa editar `provision.ps1`.

## Execução

```powershell
# Pré-requisito: gcloud auth login já realizado neste shell.
# Edite $PROJECT_ID em provision.ps1 primeiro (placeholder padrão "seu-projeto-id").
./provision.ps1

# Conecte assim que o startup-script terminar (~1-2 min após a criação):
gcloud compute ssh claude-code-vm --zone=us-central1-a --tunnel-through-iap
```

Não há etapa de build, lint ou teste. A verificação é operacional: execute o `provision.ps1`, depois conecte via SSH e confirme se as ferramentas foram instaladas.

## Detalhes importantes a preservar ao editar

- **Sem IP externo** (`--no-address`): a VM é acessível apenas via SSH sobre IAP. A regra de firewall permite `tcp:22` somente a partir da faixa IAP `35.235.240.0/20`. Não adicione um endereço público nem abra outras portas sem motivo.
- **Identificadores da VM** (`$PROJECT_ID`, `$ZONE`, `$VM_NAME`) são definidos uma única vez no topo de `provision.ps1` e reutilizados; o comando SSH no `Write-Host` final e qualquer documentação devem coincidir com eles.
- **`startup.sh` executa como root, de forma não interativa, com `set -e`** — cada etapa do apt deve ser não interativa e tolerante à idempotência em uma imagem Ubuntu 24.04 limpa. A criação da regra de firewall em `provision.ps1` deve retornar erro "already exists" em novas execuções; isso é seguro e pode ser ignorado.
- Node 22 é exigido pelo OpenSpec CLI, Next.js e Playwright; o venv/pip do Python é para um backend FastAPI. Isso restringe atualizações de versão no `startup.sh`.
