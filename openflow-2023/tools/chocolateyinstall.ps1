$ErrorActionPreference = 'Stop'

# =====================================================
# CONFIGURAÇÕES PERSONALIZADAS DO PACOTE
# EXTENSÃO DO ARQUIVO (msi, exe, zip, etc)
# HASH SHA256 DO ARQUIVO 
# =====================================================
$fileType = 'exe' 
$expectedHash = "7B83700D8A638112D64E8196E055CD7D01868D63130ECBDB59FCF89C484D3C63"
$silentArgs = '-i silent'

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
# Nome real do instalador no share (difere do padrao <id>-<versao>:
# o instalador 2023 esta em openflow2023\openflow2023-1.0.0.exe)
$installerName = "openflow2023-1.0.0.exe"
$toolsDir     = Split-Path -Parent $MyInvocation.MyCommand.Definition
$networkPath  = "\\179.97.96.73\repositorio$\installers\openflow2023\$installerName"
$localExePath = Join-Path $toolsDir $installerName

# =====================================================
# FUNCOES AUXILIARES (helper compartilhada: tools\helpers.ps1)
# =====================================================
. "$toolsDir\helpers.ps1"

# =====================================================
# COPIAR INSTALADOR SE NECESSARIO
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
[Environment]::SetEnvironmentVariable("BEICIP_LICENSE_FILE", "2701@10.80.16.2", "Machine")
[Environment]::SetEnvironmentVariable("LM_LICENSE_FILE", "@10.80.16.2", "Machine")

Log "Variáveis de ambiente configuradas com sucesso."