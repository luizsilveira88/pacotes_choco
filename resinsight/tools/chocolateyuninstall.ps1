$ErrorActionPreference = 'Stop'

# =====================================================
# VARIAVEIS DO NUSPEC
# =====================================================
$packageTitle = $env:ChocolateyPackageTitle
$toolsDir     = Split-Path -Parent $MyInvocation.MyCommand.Definition
. "$toolsDir\helpers.ps1"

# =====================================================
# Caminhos
# =====================================================
$installRoot = 'C:\resinsight'
$AppName     = 'ResInsight'

# =====================================================
# 1) REMOVER ATALHO DO DESKTOP (publico + usuario)
# =====================================================
Remove-Shortcuts -AppName $AppName

# =====================================================
# 2) REMOVER C:\resinsight (idempotente; fora de C:\resinsight nada e tocado)
# =====================================================
if (Test-Path $installRoot) {
    Log "Removendo $installRoot ..."
    $removed = Remove-PathTolerant -Path $installRoot
    if (-not $removed) {
        Log "AVISO: $installRoot ainda contem arquivos em uso (mantidos para diagnostico)."
    }
}
else {
    Log "C:\resinsight nao existe. Nada a remover."
}

Log "Desinstalacao do ResInsight concluida."