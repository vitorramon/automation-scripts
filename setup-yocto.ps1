param([string]$BaseDir = "C:\WSL")
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Pause-Exit {
    param($Msg)
    if ($Msg) { Write-Host "ERRO: $Msg" -ForegroundColor Red }
    Read-Host "Pressione Enter para fechar..."
    exit
}

function Config-Hardware {
    Write-Host "--- CONFIG HARDWARE ---" -ForegroundColor Magenta
    $conf = Read-Host "Configurar limites de RAM/CPU? (S/N)"
    if ($conf -ne "S" -and $conf -ne "s") { return }
    
    $mem = Read-Host "Limite de MEMORIA (ex: 26GB)"
    $cpus = Read-Host "Limite de PROCESSADORES (ex: 10)"
    
    $content = "[wsl2]`nmemory=$mem"
    if ($cpus) { $content += "`nprocessors=$cpus" }
    
    $path = "$env:UserProfile\.wslconfig"
    Set-Content -Path $path -Value $content -Force
    Write-Host "Configuracao salva." -ForegroundColor Yellow
}

try {
    Clear-Host
    Write-Host "=== SETUP YOCTO WSL (V11 - FINAL) ===" -ForegroundColor Cyan

    wsl --list --online
    $base = Read-Host "`n1. Distro BASE (ex: Ubuntu-22.04)"
    if (!$base) { Pause-Exit "Nome invalido." }

    $name = Read-Host "2. NOVO NOME (ex: Yocto-Project)"
    if (!$name) { Pause-Exit "Nome invalido." }
    if ((wsl -l -q) -contains $name) { Pause-Exit "Ja existe." }

    $user = Read-Host "3. USUARIO Linux (ex: vitor)"
    if (!$user) { Pause-Exit "Usuario invalido." }

    $pass = Read-Host "4. SENHA" -AsSecureString
    $passStr = [System.Net.NetworkCredential]::new("", $pass).Password
    if (!$passStr) { Pause-Exit "Senha vazia." }

    $target = "$BaseDir\$name"
    $tar = "$BaseDir\temp.tar"

    if (!(Test-Path $BaseDir)) { New-Item -Type Directory -Path $BaseDir -Force | Out-Null }
    if (!(Test-Path $target)) { New-Item -Type Directory -Path $target -Force | Out-Null }

    if (!((wsl -l -q) -contains $base)) {
        Write-Host "Baixando base..." -ForegroundColor Cyan
        wsl --install -d $base
        Start-Sleep -s 5
    }

    Write-Host "Exportando..." -ForegroundColor Cyan
    wsl --export $base $tar

    Write-Host "Criando nova distro..." -ForegroundColor Cyan
    wsl --import $name $target $tar --version 2

    Write-Host "Configurando usuario..." -ForegroundColor Cyan
    # CORRECAO AQUI: Usando ${user} para isolar a variavel
    wsl -d $name -u root bash -c "useradd -m -s /bin/bash ${user}"
    wsl -d $name -u root bash -c "echo '${user}:${passStr}' | chpasswd"
    wsl -d $name -u root bash -c "adduser ${user} sudo"
    wsl -d $name -u root bash -c "echo -e '[user]\ndefault=${user}' > /etc/wsl.conf"
    
    Write-Host "Configurando Home..." -ForegroundColor Cyan
    wsl -d $name -u root bash -c "echo 'cd ~' >> /home/${user}/.bashrc"

    Config-Hardware

    Remove-Item $tar -Force
    $del = Read-Host "Excluir a base original ($base)? (S/N)"
    if ($del -eq "S") { wsl --unregister $base }

    Write-Host "Reiniciando WSL..." -ForegroundColor Red
    wsl --shutdown
    
    Write-Host "SUCESSO! Digite: wsl -d $name" -ForegroundColor Green
    Read-Host "Enter para sair..."
}
catch {
    Write-Host "ERRO FATAL: $_" -ForegroundColor Red
    Read-Host
}
