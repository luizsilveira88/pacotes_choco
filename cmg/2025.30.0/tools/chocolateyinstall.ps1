$ErrorActionPreference = "Stop"

# =====================================================
# CONFIGURAÇÕES PERSONALIZADAS DO PACOTE
# EXTENSÃO DO ARQUIVO (msi, exe, zip, etc)
# HASH SHA256 DO ARQUIVO 
# =====================================================
$fileType = "exe"
$expectedHash = "B38091B3659EAE6414A1D88B41A5430C1BEFD67CA9FF057C29AA3A87A1AC4E9A"
$silentArgs = '/s /v"/qn /norestart LICENSETYPE=NC CMGLICHOST=BALLMHOST"'

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

# =====================================================
# FUNÇÕES AUXILIARES
# =====================================================
function Log($msg) {
    Write-Host "[$packageTitle] $msg"
}

function Get-Hash($file) {
    try { (Get-FileHash $file -Algorithm SHA256).Hash }
    catch { $null }
}

function Hash-Valid($file, $expected) {
    $hash = Get-Hash $file
    return ($hash -and $hash -eq $expected)
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
    checksumType = "sha256"
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

