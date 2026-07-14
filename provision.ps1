# ============================================================
# Provisionamento da VM de agentes (Claude Code + OpenSpec + CI/E2E)
# Versao simplificada: 1-2 projetos simultaneos
# Execute a partir do PowerShell ou Google Cloud SDK Shell
# Pre-requisito: gcloud auth login ja realizado neste notebook
# ============================================================

$PROJECT_ID = "seu-projeto-id"          # <-- ajuste aqui
$ZONE       = "us-central1-a"           
$REGION     = "us-central1"
$VM_NAME    = "claude-code-vmDev"

# Define o projeto ativo
gcloud config set project $PROJECT_ID

# Regra de firewall para SSH via IAP (rode so uma vez por projeto GCP;
# se ja existir, o comando abaixo vai retornar erro "already exists" - pode ignorar)
gcloud compute firewall-rules create allow-iap-ssh `
  --direction=INGRESS --action=ALLOW --rules=tcp:22 `
  --source-ranges=35.235.240.0/20 --network=default

# Cloud NAT - OBRIGATORIO porque a VM nao tem IP externo (--no-address).
# Sem isso, a VM so acessa o mirror interno do Ubuntu - nada de Docker Hub,
# GitHub, npm, claude.ai etc. (rode so uma vez por projeto/regiao GCP;
# se ja existir, os comandos abaixo retornam erro "already exists" - pode ignorar)
gcloud compute routers create nat-router `
  --network=default --region=$REGION

gcloud compute routers nats create nat-config `
  --router=nat-router --region=$REGION `
  --auto-allocate-nat-external-ips --nat-all-subnet-ip-ranges

# Cria a VM - tamanho reduzido para 1-2 projetos simultaneos
# e2-standard-2 = 2 vCPU / 8GB RAM (suficiente para Claude Code + Playwright + Docker leve)
gcloud compute instances create $VM_NAME `
  --zone=$ZONE `
  --machine-type=e2-standard-2 `
  --image-family=ubuntu-2404-lts-amd64 `
  --image-project=ubuntu-os-cloud `
  --boot-disk-size=40GB `
  --boot-disk-type=pd-balanced `
  --no-address `
  --metadata-from-file startup-script=startup.sh

Write-Host ""
Write-Host "VM criada. Aguarde ~1-2 minutos para o startup-script terminar de instalar os pacotes."
Write-Host "Para conectar:"
Write-Host "  gcloud compute ssh $VM_NAME --zone=$ZONE --tunnel-through-iap"
Write-Host ""
Write-Host "Apos conectar, confira se o script terminou sem erro:"
Write-Host "  cat /var/log/startup-script-progress.log"
Write-Host "Deve terminar na linha '== [6/6] Concluido =='"
