$ErrorActionPreference = 'Stop'

# =====================================================
# CONFIGURAÇÕES PERSONALIZADAS DO PACOTE
# EXTENSÃO DO ARQUIVO (msi, exe, zip, etc)
# HASH SHA256 DO ARQUIVO
# =====================================================
$fileType = 'zip'
$expectedHash = "98118094C74AEB70B1CF475134F0B920BC3DC49E6AD36FF608631E01062DCA98"

# =====================================================
# VARIÁVEIS DO NUSPEC (id, title, version)
# =====================================================
$packageId      = $env:ChocolateyPackageName
$packageTitle   = $env:ChocolateyPackageTitle
$packageVersion = $env:ChocolateyPackageVersion

# =====================================================
# Caminhos de rede e local do instalador
# =====================================================
$zipFileName    = 'office-2024.zip'
$xmlFileName    = 'office-2024.xml'
$networkDir     = "\\179.97.96.73\repositorio$\installers\office2024"
$networkZipPath = Join-Path $networkDir $zipFileName
$networkXmlPath = Join-Path $networkDir $xmlFileName
$toolsDir       = Split-Path -Parent $MyInvocation.MyCommand.Definition
$extractPath    = Join-Path $toolsDir 'extracted'
$localZipPath   = Join-Path $toolsDir $zipFileName
$localXmlPath   = Join-Path $toolsDir $xmlFileName
. "$toolsDir\helpers.ps1"

# =====================================================
# REMOÇÃO DE LEGADOS (SE NECESSARIO)
# =====================================================
$legacyDisplayName = "*Microsoft Office LTSC 2024*"
$legacyApp = Get-LegacyInstall $legacyDisplayName

if ($legacyApp) {
    Log "Instalação existente do Office LTSC 2024 detectada. Removendo..."
    Uninstall-Legacy $legacyApp
}
else {
    Log "Nenhuma instalação existente do Office LTSC 2024 detectada."
}

# =====================================================
# VERIFICAR ORIGEM (REPOSITÓRIO DE INSTALADORES)
# =====================================================
if (-not (Test-Path $networkDir)) {
    Throw "Não foi possível acessar o repositório de instaladores: $networkDir"
}

if (-not (Test-Path $networkZipPath)) {
    Throw "Arquivo office-2024.zip não encontrado no repositório de instaladores."
}

if (-not (Test-Path $networkXmlPath)) {
    Throw "Arquivo office-2024.xml não encontrado no repositório de instaladores."
}

Log "Origem do instalador verificada."

# =====================================================
# COPIAR PAYLOAD SE NECESSÁRIO
# =====================================================
$needCopy = $true

if (Test-Path $localZipPath) {
    Log "ZIP já presente localmente. Validando hash..."

    if (Hash-Valid $localZipPath $expectedHash) {
        Log "Hash válido. Reutilizando ZIP local."
        $needCopy = $false
    }
    else {
        Log "Hash incorreto. Será necessário copiar novamente."
    }
}

if ($needCopy) {
    Log "Copiando payload da rede para o armazenamento local..."
    Copy-Item $networkZipPath $localZipPath -Force

    Log "Validando integridade do payload..."
    if (-not (Hash-Valid $localZipPath $expectedHash)) {
        Throw "ERRO: O hash do payload copiado está incorreto. Abortando."
    }

    Log "Hash validado com sucesso."
}

# =====================================================
# EXTRAÇÃO
# =====================================================

# Remove extração antiga de execuções anteriores (evita arquivos em uso)
Remove-PathTolerant $extractPath

Log "Extraindo payload..."
Get-ChocolateyUnzip `
    -FileFullPath $localZipPath `
    -Destination $extractPath

$setupExe = Get-ChildItem -Path $extractPath -Recurse -Filter 'setup.exe' -ErrorAction SilentlyContinue | Select-Object -First 1

if (-not $setupExe) {
    Throw "setup.exe não encontrado após a extração."
}

$setupExe = $setupExe.FullName
Log "setup.exe localizado."

# =====================================================
# OBTER XML DE CONFIGURAÇÃO (cópia local temporária)
# O conteúdo do XML é sensível e NUNCA é impresso/logado.
# =====================================================
Log "Obtendo arquivo de configuração do repositório..."
Copy-Item $networkXmlPath $localXmlPath -Force
Log "Arquivo de configuração obtido."

# =====================================================
# INSTALAÇÃO
# =====================================================
$packageArgs = @{
    packageName    = $packageId
    fileType       = 'exe'
    file           = $setupExe
    silentArgs     = "/configure `"$localXmlPath`""
    validExitCodes = @(0, 3010, 1641)
}

Log "Iniciando instalação do Office 2024..."
Install-ChocolateyInstallPackage @packageArgs

# =====================================================
# AGUARDAR INSTALAÇÃO EM SEGUNDO PLANO (CLICK-TO-RUN)
# O setup.exe /configure do Office retorna antes do fim;
# o processo OfficeClickToRun.exe instala em segundo plano
# usando a pasta extraída. Só limpamos depois de terminar.
# =====================================================
Log "Aguardando a instalação do Office em segundo plano (timeout: 30 min)..."
$waitTimeoutMinutes = 30
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$done = $false

while ($sw.Elapsed.TotalMinutes -lt $waitTimeoutMinutes) {
    $bgProcs = @(Get-Process -Name 'OfficeClickToRun','OfficeC2RClient' -ErrorAction SilentlyContinue)
    if ($bgProcs.Count -eq 0) { $done = $true; break }
    Start-Sleep -Seconds 10
}

if ($done) {
    Log "Instalação em segundo plano concluída."
}
else {
    Log "AVISO: tempo limite de $waitTimeoutMinutes min atingido; prosseguindo mesmo assim."
}

Log "Instalação concluída com sucesso!"

# =====================================================
# LIMPEZA (após sucesso; em erro preserva para diagnóstico)
# =====================================================
Log "Removendo arquivos temporários..."
$tempPaths = @($localZipPath, $extractPath, $localXmlPath)

foreach ($path in $tempPaths) {
    Remove-PathTolerant $path
}

Log "Limpeza concluída."