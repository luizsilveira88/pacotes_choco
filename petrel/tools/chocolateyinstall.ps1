$ErrorActionPreference = 'Stop'

# =====================================================
# CONFIGURAÇÕES PERSONALIZADAS DO PACOTE
# EXTENSÃO DO ARQUIVO (msi, exe, zip, etc)
# HASH SHA256 DO ARQUIVO 
# =====================================================
$fileType = 'msi' 
$expectedHash = "BD09C3EB971A8367FE00F7F9F280C1D2C4C82747425C08A386026176D95B14B2"
$silentArgs = '/quiet /norestart'

# =====================================================
# VARIÁVEIS DO NUSPEC (id, title, version)
# =====================================================
$packageId      = $env:ChocolateyPackageName
$packageTitle   = $env:ChocolateyPackageTitle
$packageVersion = $env:ChocolateyPackageVersion

# =====================================================
# Caminhos de rede e local do instalador
# =====================================================

$installerExtension = ".$fileType"
$installerName = "$packageId-$packageVersion$installerExtension"
$toolsDir     = Split-Path -Parent $MyInvocation.MyCommand.Definition
$networkPath  = "\\179.97.96.73\repositorio$\installers\$packageId\$installerName"
$localExePath = Join-Path $toolsDir $installerName
. "$toolsDir\helpers.ps1"

# =====================================================
# COPIAR INSTALADOR SE NECESSÁRIO
# =====================================================
$needCopy = $true

if (Test-Path $localExePath) {
    Log "Instalador já presente localmente. Validando hash..."

    if (Hash-Valid $localExePath $expectedHash) {
        Log "Hash válido. Reutilizando instalador local."
        $needCopy = $false
    }
    else {
        Log "Hash incorreto. Será necessário copiar novamente."
    }
}

if ($needCopy) {

    if (-not (Test-Path $networkPath)) {
        Throw "O instalador não foi encontrado na rede: $networkPath"
    }

    Log "Copiando instalador da rede..."
    Copy-Item $networkPath $localExePath -Force

    Log "Validando integridade..."
    if (-not (Hash-Valid $localExePath $expectedHash)) {
        Throw "ERRO: O hash do instalador copiado está incorreto. Abortando."
    }

    Log "Hash validado com sucesso."
}

# =====================================================
# INSTALAÇÃO
# =====================================================
$packageArgs = @{
    packageName  = $packageId
    fileType     = $fileType
    file         = $localExePath
    silentArgs   = $silentArgs
    checksum     = $expectedHash
    checksumType = 'sha256'
    validExitCodes = @(0, 1, 3010, 1641)
}

Log "Executando instalador..."
Install-ChocolateyInstallPackage @packageArgs

Log "Instalação concluída com sucesso!"

# ------------------------------------------------------
# TAREFAS ADICIONAIS PERSONALIZADAS
# ------------------------------------------------------
[Environment]::SetEnvironmentVariable("SLBSLS_LICENSE_FILE", "@10.80.16.4", "Machine")
$shortcut = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Schlumberger\Petrel 2024\Petrel 2024.lnk"
Log "Variáveis de ambiente configuradas com sucesso."
$target = Join-Path $env:PUBLIC "Desktop\Petrel 2024.lnk"

if (Test-Path $shortcut) {
    Copy-Item -Path $shortcut -Destination $target -Force
    Log "Atalho criado: $target"
}
else {
    Log "Atalho não encontrado: $shortcut"
}

