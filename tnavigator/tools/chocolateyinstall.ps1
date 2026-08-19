$ErrorActionPreference = 'Stop'

# =====================================================
# CONFIGURAÇÕES PERSONALIZADAS DO PACOTE
# EXTENSÃO DO ARQUIVO (msi, exe, zip, etc)
# HASH SHA256 DO ARQUIVO 
# =====================================================
$fileType = 'zip' 
$expectedHash = "78FEB518BFD24AB272C27A63AB63548420E5269E58B45BED512A0D8E03CAB8E5"
$silentArgs = ''

# Nome da pasta extraída e destino em C:\Program Files
$extractedFolderName = 'tNavigator-Win-64'
$installDir = "C:\Program Files\$extractedFolderName"

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
. "$toolsDir\helpers.ps1"

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

Log "Extraindo arquivo..."
Get-ChocolateyUnzip `
    -FileFullPath $localZipPath `
    -Destination $extractPath

# =====================================================
# INSTALAÇÃO NÃO CONVENCIONAL
# O tNavigator não possui um instalador convencional.
# Após a extração, a pasta do programa é copiada para
# C:\Program Files e o atalho (.lnk) embutido dentro da
# pasta extraída é copiado para a área de trabalho de
# todos os usuários.
# =====================================================

# Localiza a pasta extraída (na raiz da extração ou em subpasta)
$sourceDir = Join-Path $extractPath $extractedFolderName

if (-not (Test-Path $sourceDir)) {
    $foundDir = Get-ChildItem -Path $extractPath -Directory -Recurse -Filter $extractedFolderName -ErrorAction SilentlyContinue | Select-Object -First 1

    if ($foundDir) {
        $sourceDir = $foundDir.FullName
    }
}

if (-not (Test-Path $sourceDir)) {
    Throw "Pasta extraída '$extractedFolderName' não encontrada em $extractPath"
}

Log "Pasta extraída localizada: $sourceDir"

# Remove uma instalação anterior para garantir cópia limpa
if (Test-Path $installDir) {
    Log "Removendo instalação anterior em: $installDir"
    Remove-Item $installDir -Recurse -Force
}

Log "Copiando $extractedFolderName para $installDir..."
Copy-Item $sourceDir $installDir -Recurse -Force
Log "tNavigator copiado com sucesso."

# Atalho (.lnk) fornecido dentro da própria pasta extraída
$shortcut = Get-ChildItem -Path $installDir -Recurse -Filter *.lnk -ErrorAction SilentlyContinue | Select-Object -First 1

if ($shortcut) {
    Copy-Item $shortcut.FullName "$env:PUBLIC\Desktop\" -Force
    Log "Atalho copiado para a área de trabalho de todos os usuários: $($shortcut.Name)"
}
else {
    Log "Atalho não encontrado dentro da pasta extraída."
}

Log "Instalação concluída com sucesso!"