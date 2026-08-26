$ErrorActionPreference = 'Stop'

# =====================================================
# VARIÁVEIS DO NUSPEC
# =====================================================
$packageTitle = $env:ChocolateyPackageTitle
$toolsDir     = Split-Path -Parent $MyInvocation.MyCommand.Definition
. "$toolsDir\helpers.ps1"

# =====================================================
# Caminhos
# =====================================================
$installRoot  = 'C:\OPM'
$binPath      = Join-Path $installRoot 'bin'
$composeFile  = Join-Path (Join-Path $installRoot 'runtime') 'docker-compose.yml'

# =====================================================
# 1) ENCERRAR CONTAINERS DO PROJETO OPM (somente do Runtime OPM)
#    - Só executa se o Docker Engine estiver disponível;
#    - docker compose down: remove containers/rede do projeto, mantém
#      imagens e volumes (não afeta outros projetos);
#    - Não remove o Docker Desktop nem recursos de terceiros.
# =====================================================
$dockerCmd = Get-Command docker -ErrorAction SilentlyContinue

if ((Test-Path $installRoot) -and $dockerCmd) {
    cmd.exe /c "docker info >nul 2>&1"
    if ($LASTEXITCODE -eq 0) {

        if (Test-Path $composeFile) {
            Log "Docker Engine disponível. Encerrando containers do Runtime OPM..."
            try {
                docker compose -f $composeFile down 2>$null | Out-Null
            }
            catch {
                Log "Atenção: falha ao executar 'docker compose down': $($_.Exception.Message)"
            }
        }

        # Container que porventura tenha sobrado do projeto (identificado por label)
        $opmIds = @(docker ps -aq --filter "label=com.docker.compose.project=runtime" 2>$null)
        if ($opmIds) {
            Log "Removendo container(s) remanescente(s) do Runtime OPM..."
            docker rm -f $opmIds 2>$null | Out-Null
        }
    }
    else {
        Log "Docker Engine indisponível no momento. Nenhum container do OPM foi encerrado (evitando remoção incorreta)."
    }
}

# =====================================================
# 2) REMOVER C:\OPM\bin DO MACHINE PATH (só essa entrada)
# =====================================================
$machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')

if (-not [string]::IsNullOrEmpty($machinePath)) {
    $pathEntries = @($machinePath -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
    $keptEntries = @($pathEntries | Where-Object { $_ -ine $binPath })

    if ($keptEntries.Count -ne $pathEntries.Count) {
        [Environment]::SetEnvironmentVariable('Path', ($keptEntries -join ';'), 'Machine')
        Log "C:\OPM\bin removido do PATH de máquina."
    }
    else {
        Log "C:\OPM\bin não estava presente no PATH de máquina. Nada a fazer."
    }
}
else {
    Log "PATH de máquina vazio. Nada a fazer."
}

# =====================================================
# 3) REMOVER C:\OPM (idempotente; fora de C:\OPM nada é tocado)
# =====================================================
if (Test-Path $installRoot) {
    Log "Removendo $installRoot ..."
    $removed = Remove-PathTolerant -Path $installRoot
    if (-not $removed) {
        Log "AVISO: $installRoot ainda contém arquivos em uso (mantidos para diagnóstico)."
    }
}
else {
    Log "C:\OPM não existe. Nada a remover."
}

Log "Desinstalação do OPM Flow concluída."
Log "Docker Desktop e demais recursos que não pertencem ao pacote foram mantidos."