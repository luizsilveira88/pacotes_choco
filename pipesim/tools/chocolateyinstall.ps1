$ErrorActionPreference = 'Stop'

# =====================================================
# CONFIGURAÇÕES PERSONALIZADAS DO PACOTE
# EXTENSÃO DO ARQUIVO (msi, exe, zip, etc)
# HASH SHA256 DO ARQUIVO 
# =====================================================
$fileType = 'zip' 
$fileTypeInstaller = 'msi'
$expectedHash = "A9C24DB560366B7FFB74F957A2AA0AAB13B4100BD3922FE8F79620A21A3F06BF"
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

$zipExtension = ".$fileType"
$zipPath = "$packageId-$packageVersion$zipExtension"
$toolsDir     = Split-Path -Parent $MyInvocation.MyCommand.Definition
$networkPath  = "\\179.97.96.73\repositorio$\installers\$packageId\$zipPath"
$extractPath = Join-Path $toolsDir 'extracted'
$localZipPath = Join-Path $toolsDir $zipPath

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

if (Test-Path $localZipPath) {
    Log "Instalador já presente localmente. Validando hash..."

    if (Hash-Valid $localZipPath $expectedHash) {
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
    Copy-Item $networkPath $localZipPath -Force

    Log "Validando integridade..."
    if (-not (Hash-Valid $localZipPath $expectedHash)) {
        Throw "ERRO: O hash do instalador copiado está incorreto. Abortando."
    }

    Log "Hash validado com sucesso."
}

# =====================================================
# EXTRAÇÃO
# =====================================================

Log "Extraindo instalador..."
Get-ChocolateyUnzip `
    -FileFullPath $localZipPath `
    -Destination $extractPath

$localExePath = Get-ChildItem -Path $extractPath -Recurse -Filter *.$fileTypeInstaller | Select-Object -First 1

if (-not $localExePath) {
    Throw "Nenhum instalador .$fileTypeInstaller encontrado."
}

$localExePath = $localExePath.FullName

# =====================================================
# INSTALAÇÃO
# =====================================================
$packageArgs = @{
    packageName     = $packageId
    fileType        = $fileTypeInstaller
    file            = $localExePath
    silentArgs      = $silentArgs
    validExitCodes  = @(0, 3010, 1641)
}

Log "Executando instalador..."
Install-ChocolateyInstallPackage @packageArgs

Log "Instalação concluída com sucesso!"