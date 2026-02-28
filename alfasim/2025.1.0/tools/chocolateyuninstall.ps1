$ErrorActionPreference = 'Stop'

$uninstallExe = "C:\Program Files\ESSS\ALFAsim 2025.1\unins000.exe"

$packageArgs = @{
    packageName    = $env:ChocolateyPackageName
    fileType       = 'exe'
    file           = $uninstallExe
    silentArgs     = '/SILENT'
}

Uninstall-ChocolateyPackage @packageArgs


# -------------------------------
# Remover pasta de plugins
# -------------------------------
$pluginsPath = "C:\Users\Public\alfasim_plugins\"

if (Test-Path $pluginsPath) {
    Write-Output "Removendo pasta de plugins: $pluginsPath"
    Remove-Item -Path $pluginsPath -Recurse -Force
}

# -------------------------------
# Remover variáveis de ambiente
# -------------------------------
[Environment]::SetEnvironmentVariable("ALFASIM_PLUGINS_DIR", $null, "Machine")
[Environment]::SetEnvironmentVariable("ESSS_LICENSE_FILE", $null, "Machine")

Write-Output "Variáveis de ambiente removidas."
