$ErrorActionPreference = 'Stop'

# =====================================================
# VARIÁVEIS DO NUSPEC
# =====================================================
$packageTitle = $env:ChocolateyPackageTitle

# =====================================================
# Caminhos
# =====================================================
$toolsDir    = Split-Path -Parent $MyInvocation.MyCommand.Definition
. "$toolsDir\helpers.ps1"

# =====================================================
# REMOVE A PASTA COPIADA EM PROGRAM FILES
# =====================================================
$installDir = 'C:\Program Files\tNavigator-Win-64'

if (Test-Path $installDir) {
    Remove-Item $installDir -Recurse -Force
    Log "Pasta de instalação removida: $installDir"
}
else {
    Log "Pasta de instalação não encontrada: $installDir"
}

# =====================================================
# REMOVE ATALHOS DO DESKTOP (público e do usuário)
# =====================================================
Remove-Shortcuts -AppName 'tNavigator'

Log "Desinstalação concluída com sucesso!"