$ErrorActionPreference = 'Stop'

$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$networkPath  = "\\179.97.96.73\repositorio$\installers\alfasim\alfasim-$env:ChocolateyPackageVersion.exe"
$localExePath = Join-Path $toolsDir "alfasim-$env:ChocolateyPackageVersion.exe"

# Copiar o instalador da rede para local
Write-Output "Copiando instalador da rede para $localExePath ..."
Copy-Item $networkPath $localExePath -Force

$packageArgs = @{
  packageName    = $env:ChocolateyPackageName
  fileType       = 'exe'
  file           = $localExePath
  silentArgs     = '/silent /forcecloseapplications /nocancel /norestart'
}

Install-ChocolateyInstallPackage @packageArgs

# ------------------------------------------------------
# Copiar pasta de plugins 
# ------------------------------------------------------

$sourcePlugins = "\\179.97.96.73\repositorio$\installers\alfasim\alfasim_plugins\"
$destPlugins   = "C:\Users\Public\alfasim_plugins\"

Write-Output "Copiando plugins de $sourcePlugins para $destPlugins ..."
Copy-Item -Path $sourcePlugins -Destination $destPlugins -Recurse -Force

# ------------------------------------------------------
# Definir variáveis de ambiente
# ------------------------------------------------------

[Environment]::SetEnvironmentVariable("ALFASIM_PLUGINS_DIR", $destPlugins, "Machine")
[Environment]::SetEnvironmentVariable("ESSS_LICENSE_FILE", "1515@10.80.16.4", "Machine")

Write-Output "Variáveis de ambiente configuradas com sucesso."