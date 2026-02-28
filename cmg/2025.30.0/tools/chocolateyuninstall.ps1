$ErrorActionPreference = 'Stop'

# =====================================================
# CONFIGURAÇÕES PERSONALIZADAS DO PACOTE
# EXTENSÃO DO ARQUIVO (msi, exe, zip, etc)
# ARGS DO UNINSTALL
# =====================================================
$fileType = "MSI"
$productCode = "{B8A6B738-2C29-429E-9075-B23A24598B12}"
$silentArgs = "$($productCode) /qn /norestart"

# =====================================================
# VARIÁVEIS DO NUSPEC (id, title, version)
# =====================================================
$packageId      = $env:ChocolateyPackageName
$packageTitle   = $env:ChocolateyPackageTitle
$packageVersion = $env:ChocolateyPackageVersion

$packageArgs = @{
  packageName = $env:ChocolateyPackageName
  fileType = $fileType
  silentArgs = $silentArgs
}

Uninstall-ChocolateyPackage @packageArgs