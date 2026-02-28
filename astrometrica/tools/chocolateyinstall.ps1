$ErrorActionPreference = 'Stop'

$packageName = 'astrometrica'
$url = 'https://iasc.cosmosearch.org/Content/Distributables/IASC-Astrometrica-Installer-v1.0.zip'

$toolsDir = "$(Split-Path -Parent $MyInvocation.MyCommand.Definition)"
$zipPath = Join-Path $toolsDir 'astrometrica.zip'
$extractPath = Join-Path $toolsDir 'extracted'

# Download do ZIP
Get-ChocolateyWebFile `
    -PackageName $packageName `
    -FileFullPath $zipPath `
    -Url $url

# Extrair ZIP
Get-ChocolateyUnzip `
    -FileFullPath $zipPath `
    -Destination $extractPath

# Localizar o MSI
$msi = Get-ChildItem -Path $extractPath -Recurse -Filter *.msi | Select-Object -First 1

if (-not $msi) {
    throw "Arquivo MSI não encontrado dentro do ZIP."
}

# Instalar MSI em modo silencioso
Install-ChocolateyInstallPackage `
    -PackageName $packageName `
    -FileType 'msi' `
    -File $msi.FullName `
    -SilentArgs 'ALLUSERS=1 /quiet /norestart' `
    -ValidExitCodes @(0, 3010)
