# ============================================================
# Provisionamento da VM de agentes (Claude Code + OpenSpec + CI/E2E)
# Versao simplificada: 1-2 projetos simultaneos
# Execute a partir do PowerShell ou Google Cloud SDK Shell
# Pre-requisito: gcloud auth login ja realizado neste notebook
# ============================================================

$PROJECT_ID = "seu-projeto-id"          
$ZONE       = "us-central1-a"
$VM_NAME    = "claude-code-vm"

# Define o projeto ativo
gcloud config set project $PROJECT_ID

# Regra de firewall para SSH via IAP (rode so uma vez por projeto GCP;
# se ja existir, o comando abaixo vai retornar erro "already exists" - pode ignorar)
gcloud compute firewall-rules create allow-iap-ssh `
  --direction=INGRESS --action=ALLOW --rules=tcp:22 `
  --source-ranges=35.235.240.0/20 --network=default

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
