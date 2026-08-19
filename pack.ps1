<#
.SYNOPSIS
Sincroniza a helper compartilhada e gera (pack) os pacotes Chocolatey do repositorio.

.DESCRIPTION
1. Copia _shared\helpers.ps1 para <pacote>\tools\helpers.ps1 de cada pacote que usa a helper.
2. Executa choco pack em cada pacote (exceto template, que e modelo).

Use -SyncOnly para apenas sincronizar a helper, sem gerar/regenerar .nupkg.

.PARAMETER SyncOnly
Apenas atualiza as copias de tools\helpers.ps1, sem gerar .nupkg.

.PARAMETER Target
Subconjunto de pacotes a processar, separado por virgula (ex.: "flowax,petrel").
Aceita nome de pasta ou de subpasta de versao (ex.: "alfasim\2025.2.1").
Sem o parametro, processa todos.

.PARAMETER Quiet
Suprime o log durante o pack.

.EXAMPLE
.\pack.ps1 -SyncOnly
.\pack.ps1 -Target flowax,petrel
.\pack.ps1
#>
[CmdletBinding()]
param(
    [switch]$SyncOnly,
    [string[]]$Target = @(),
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'

$root        = Split-Path -Parent $MyInvocation.MyCommand.Definition
$shared      = Join-Path $root '_shared\helpers.ps1'
$packExclude = @('template')        # modelo, nao e pacote real
$syncExclude = @('autocad-ptbr')    # helper especifica propria, nao sobrescrever

if (-not (Test-Path $shared)) {
    Write-Error "Helper canonica nao encontrada: $shared"
    exit 1
}

function Write-Log2($msg) {
    if (-not $Quiet) { Write-Host $msg }
}

# Descobre as raizes de pacote: pastas que contem ao menos um .nuspec
$pkgRoots = @(Get-ChildItem -Path $root -Recurse -Filter '*.nuspec' |
    ForEach-Object { $_.DirectoryName } |
    Sort-Object -Unique)

# Filtro por -Target (nome de pasta ou subpasta de versao)
if ($Target) {
    $targets = @()
    foreach ($t0 in $Target) {
        foreach ($t in ($t0 -split ',')) {
            $t = $t.Trim()
            if ($t) { $targets += $t }
        }
    }
    $pkgRoots = $pkgRoots | Where-Object {
        $p = $_
        $segments = $p -split '\\'
        $res = $false
        foreach ($t in $targets) {
            if (($segments -contains $t) -or ($p -like "*\$t\*") -or ($p -like "*\$t")) { $res = $true }
        }
        $res
    }
}

foreach ($pkg in $pkgRoots) {
    $leaf  = Split-Path $pkg -Leaf
    $tools = Join-Path $pkg 'tools'

    # 1) Sincroniza a helper nos pacotes que realmente a usam (dot-source helpers.ps1)
    $isSyncTarget = ($syncExclude -notcontains $leaf) -and (Test-Path $tools)
    if ($isSyncTarget) {
        $usesHelper = @(Get-ChildItem -Path $tools -Filter '*.ps1' -ErrorAction SilentlyContinue |
            Where-Object { (Get-Content $_.FullName -Raw) -match '\$toolsDir[\\/]*helpers' })
        if ($usesHelper.Count -gt 0) {
            Copy-Item -Path $shared -Destination (Join-Path $tools 'helpers.ps1') -Force
            Write-Log2 "Sync  : $pkg\tools\helpers.ps1"
        }
        else {
            Write-Log2 "Skip  : $pkg (nao usa helper)"
        }
    }

    # 2) Empacota (pula template = modelo)
    if (-not $SyncOnly -and ($packExclude -notcontains $leaf)) {
        Write-Log2 "Pack  : $pkg"
        Push-Location $pkg
        try {
            choco pack *> $null
            if ($LASTEXITCODE -ne 0) { throw "choco pack falhou em $pkg (exit $LASTEXITCODE)" }
        }
        finally {
            Pop-Location
        }
        Write-Log2 "  ok  : $pkg"
    }
}

Write-Log2 'Concluido.'
