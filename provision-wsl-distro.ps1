<#
.SYNOPSIS
    Criador de Distros WSL V5 (Hardware + Auto-Home)
    Fluxo: Lista -> Instala -> Renomeia -> User/Pass -> Hardware -> Auto-Home -> Limpa.
#>

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# --- FUNÇÃO DE HARDWARE ---
function Configurar-Hardware {
    Write-Host "`n==========================================" -ForegroundColor Magenta
    Write-Host "   CONFIGURAÇÃO DE HARDWARE (.wslconfig)  " -ForegroundColor Magenta
    Write-Host "==========================================" -ForegroundColor Magenta
    
    $conf = Read-Host "Deseja configurar limites de RAM/CPU para o WSL? (S/N)"
    if ($conf -ne "S" -and $conf -ne "s") { return }

    Write-Host "`nRecomendado para seu PC (32GB RAM / Ryzen 4600G):" -ForegroundColor Gray
    Write-Host "Memória: 26GB | Processadores: 10 ou 12" -ForegroundColor Gray
    
    $mem = Read-Host "`nLimite de MEMÓRIA (ex: 26GB)"
    $cpus = Read-Host "Limite de PROCESSADORES (ex: 12)"
    $swap = Read-Host "Swap/Memória Virtual (ex: 8GB) [Opcional, Enter para pular]"

    $content = "[wsl2]`nmemory=$mem"
    if ($cpus) { $content += "`nprocessors=$cpus" }
    if ($swap) { $content += "`nswap=$swap" }
    
    $wslConfigPath = "$env:UserProfile\.wslconfig"
    Set-Content -Path $wslConfigPath -Value $content
    
    Write-Host "`nConfiguração salva. O WSL será reiniciado no final." -ForegroundColor Yellow
}

# --- INÍCIO DO SCRIPT ---
Clear-Host
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "   CRIADOR DE AMBIENTE YOCTO (V5)         " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
param ([string]$BaseDir = "C:\WSL")

# 1. Coleta de Dados
wsl --list --online
Write-Host ""
$baseDistro = Read-Host "1. Distro BASE (ex: Ubuntu-22.04)"
if (-not $baseDistro) { exit }

$customName = Read-Host "2. NOVO NOME (ex: Yocto-Project)"
if (-not $customName) { exit }
if ((wsl -l -q) -contains $customName) { Write-Error "Nome já existe."; exit }

$linuxUser = Read-Host "3. USUÁRIO Linux (ex: vitor)"
if (-not $linuxUser) { exit }

$securePass = Read-Host "4. SENHA (ficará oculta)" -AsSecureString
$plainPass = [System.Net.NetworkCredential]::new("", $securePass).Password
if (-not $plainPass) { Write-Error "Senha vazia."; exit }

# 2. Execução
$targetDir = "$BaseDir\$customName"
$tempTar = "$BaseDir\temp_install.tar"

if (-not (Test-Path $targetDir)) { New-Item -ItemType Directory -Force -Path $targetDir | Out-Null }

# A. Instala Base
if (-not ((wsl -l -q) -contains $baseDistro)) {
    Write-Host "`n[1/6] Baixando base..." -ForegroundColor Cyan
    wsl --install -d $baseDistro
    Start-Sleep -Seconds 5
}

# B. Exporta
Write-Host "[2/6] Exportando imagem..." -ForegroundColor Cyan
wsl --export $baseDistro $tempTar

# C. Importa
Write-Host "[3/6] Criando '$customName'..." -ForegroundColor Cyan
wsl --import $customName $targetDir $tempTar --version 2

# D. Configura User e Senha
Write-Host "[4/6] Configurando usuário e senha..." -ForegroundColor Cyan
$cmdUser = "useradd -m -s /bin/bash $linuxUser && echo '$linuxUser:$plainPass' | chpasswd && adduser $linuxUser sudo && echo -e '[user]\ndefault=$linuxUser' > /etc/wsl.conf"
wsl -d $customName -u root bash -c $cmdUser

# E. Configura Auto-Home (~/)
Write-Host "[5/6] Configurando início automático na HOME (~)..." -ForegroundColor Cyan
# Adiciona o comando 'cd ~' ao final do .bashrc do usuário
$cmdHome = "echo 'cd ~' >> /home/$linuxUser/.bashrc"
wsl -d $customName -u root bash -c $cmdHome
Write-Host "Agora o terminal sempre abrirá em /home/$linuxUser" -ForegroundColor Green

# F. Hardware e Limpeza
Configurar-Hardware

Write-Host "[6/6] Limpando..." -ForegroundColor Cyan
Remove-Item $tempTar -Force
$cleanup = Read-Host "Excluir a base '$baseDistro'? (S/N)"
if ($cleanup -eq "S") { wsl --unregister $baseDistro }

Write-Host "`nReiniciando WSL para aplicar tudo..." -ForegroundColor Red
wsl --shutdown

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "       AMBIENTE PRONTO!                   " -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host "Para acessar, digite: wsl -d $customName"
Read-Host "Pressione Enter para sair..."