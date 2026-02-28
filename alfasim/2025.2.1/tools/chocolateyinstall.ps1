$ErrorActionPreference = 'Stop'

# =====================================================
# CONFIGURAÇÕES PERSONALIZADAS DO PACOTE
# EXTENSÃO DO ARQUIVO (msi, exe, zip, etc)
# HASH SHA256 DO ARQUIVO 
# =====================================================
$fileType = 'exe' 
$expectedHash = "AC662F2E2557729772B96E44C788A4378F82C2D640507F03D9218EE2CEE29251"
$silentArgs = '/silent /forcecloseapplications /nocancel /norestart'

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
. "$toolsDir\helpers-1.0.0.ps1"

# =====================================================
# REMOÇÃO DE LEGADOS (SE NECESSARIO)
# =====================================================
$legacyDisplayName = "*$packageId*"
$legacyApp = Get-LegacyInstall $legacyDisplayName

if ($legacyApp) {
    Uninstall-Legacy $legacyApp
}
else {
    Log "Nenhuma instalação legada detectada."
}

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
# Definir variáveis de ambiente
# ------------------------------------------------------

[Environment]::SetEnvironmentVariable("ALFASIM_PLUGINS_DIR", $destPlugins, "Machine")
[Environment]::SetEnvironmentVariable("ESSS_LICENSE_FILE", "1515@10.80.16.4", "Machine")

Log "Variáveis de ambiente configuradas com sucesso."