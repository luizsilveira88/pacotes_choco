$ErrorActionPreference = 'Stop'

# =====================================================
# CONFIGURAÇÕES PERSONALIZADAS DO PACOTE
# EXTENSÃO DO ARQUIVO (msi, exe, zip, etc)
# HASH SHA256 DO ARQUIVO
# =====================================================
$fileType = 'zip' 
$expectedHash = "418B3DD2D7FB202F99F6FA46B3C16E06507C43CF4EE52DB779FF7D2AD407FC8B"
$silentArgs = ''

# =====================================================
# VARIÁVEIS DO NUSPEC (id, title, version)
# =====================================================
$packageId = $env:ChocolateyPackageName
$packageTitle = $env:ChocolateyPackageTitle
$packageVersion = $env:ChocolateyPackageVersion

# =====================================================
# Caminhos de rede e local do instalador
# Obs.: no share o arquivo é installers\opm\opm-<versao>.zip
# =====================================================
# Atenção: o arquivo no share mantém "04" no nome (opm-2026.04.1.zip).
# O $packageVersion enviado pelo Chocolatey vem da forma normalizada (2026.4.1),
# portanto o nome do instalador é fixo aqui.
$installerName = "opm-2026.04.1.zip"
$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$networkPath = "\\179.97.96.73\repositorio$\installers\opm\$installerName"
$localZipPath = Join-Path $toolsDir $installerName
$extractPath = Join-Path $toolsDir 'extracted'

# =====================================================
# DESTINO DA INSTALAÇÃO (C:\OPM)
# =====================================================
$installRoot = 'C:\OPM'
$binPath = Join-Path $installRoot 'bin'

# =====================================================
# FUNCOES AUXILIARES (helper compartilhada: tools\helpers.ps1)
# =====================================================
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
# LOCALIZA O CONTEÚDO EXTRAÍDO (zip tem pasta 'OPM' na raiz)
# =====================================================
$contentSource = $extractPath

if (-not (Test-Path (Join-Path $extractPath 'bin\opm-flow.cmd'))) {
    $candidate = Get-ChildItem -Path $extractPath -Directory -Recurse -ErrorAction SilentlyContinue |
    Where-Object { Test-Path (Join-Path $_.FullName 'bin\opm-flow.cmd') } |
    Select-Object -First 1

    if ($candidate) {
        $contentSource = $candidate.FullName
    }
    else {
        Throw "Conteúdo do OPM Flow (bin\opm-flow.cmd) não encontrado na extração: $extractPath"
    }
}

Log "Conteúdo extraído localizado: $contentSource"

# =====================================================
# INSTALAÇÃO EM C:\OPM
# =====================================================
if (-not (Test-Path $installRoot)) {
    New-Item -ItemType Directory -Path $installRoot -Force | Out-Null
    Log "Criado: $installRoot"
}

# Pastas de dados do usuário: preservadas em reinstalação
foreach ($d in @('cases', 'results', 'logs')) {
    $target = Join-Path $installRoot $d
    if (-not (Test-Path $target)) {
        New-Item -ItemType Directory -Path $target -Force | Out-Null
        Log "Criada pasta de dados do usuário: $target"
    }
}

# bin/runtime vêm do pacote: remove versões antigas para evitar arquivos obsoletos
foreach ($d in @('bin', 'runtime')) {
    $target = Join-Path $installRoot $d
    if (Test-Path $target) {
        Log "Removendo instalação anterior em: $target"
        Remove-PathTolerant -Path $target
    }
}

# Copia o conteúdo extraído para C:\OPM
Get-ChildItem -Path $contentSource -Force |
Copy-Item -Destination $installRoot -Recurse -Force
Log "Arquivos instalados em $installRoot."
# C:\OPM\scripts: previsto na estrutura de referência do pacote.
# (O runtime atual manda o script em runtime\scripts; mantemos a pasta
#  prevista para compatibilidade com a estrutura documentada.)
$scriptsDir = Join-Path $installRoot 'scripts'
if (-not (Test-Path $scriptsDir)) {
    New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null
}

# =====================================================
# PERMISSÕES DE SEGURANÇA
# =====================================================

Log "Aplicando permissões em $installRoot..."

function New-OpmAce {
    param(
        [System.Security.Principal.SecurityIdentifier]$Identity,

        [System.Security.AccessControl.FileSystemRights]$Rights,

        [System.Security.AccessControl.InheritanceFlags]$Inheritance =
        ([System.Security.AccessControl.InheritanceFlags]::ContainerInherit -bor
        [System.Security.AccessControl.InheritanceFlags]::ObjectInherit)
    )

    return New-Object System.Security.AccessControl.FileSystemAccessRule(
        $Identity,
        $Rights,
        $Inheritance,
        [System.Security.AccessControl.PropagationFlags]::None,
        [System.Security.AccessControl.AccessControlType]::Allow
    )
}

# SIDs padrão do Windows
$adm = New-Object System.Security.Principal.SecurityIdentifier(
    'S-1-5-32-544'
)

$system = New-Object System.Security.Principal.SecurityIdentifier(
    'S-1-5-18'
)

$users = New-Object System.Security.Principal.SecurityIdentifier(
    'S-1-5-32-545'
)

# -----------------------------------------------------
# RAIZ
# -----------------------------------------------------

$acl = Get-Acl -Path $installRoot

# Remove herança de C:\
$acl.SetAccessRuleProtection($true, $false)

# Administradores
$acl.SetAccessRule(
    (New-OpmAce `
        -Identity $adm `
        -Rights ([System.Security.AccessControl.FileSystemRights]::FullControl)
    )
)

# SYSTEM
$acl.SetAccessRule(
    (New-OpmAce `
        -Identity $system `
        -Rights ([System.Security.AccessControl.FileSystemRights]::FullControl)
    )
)

# Usuários comuns
$acl.SetAccessRule(
    (New-OpmAce `
        -Identity $users `
        -Rights ([System.Security.AccessControl.FileSystemRights]::ReadAndExecute)
    )
)

Set-Acl -Path $installRoot -AclObject $acl

Log "Raiz $installRoot configurada."

# -----------------------------------------------------
# BIN / RUNTIME / SCRIPTS
# -----------------------------------------------------

foreach ($d in @('bin', 'runtime', 'scripts')) {

    $target = Join-Path $installRoot $d

    if (-not (Test-Path $target)) {
        continue
    }

    $dacl = Get-Acl -Path $target

    $dacl.SetAccessRule(
        (New-OpmAce `
            -Identity $users `
            -Rights ([System.Security.AccessControl.FileSystemRights]::ReadAndExecute)
        )
    )

    Set-Acl -Path $target -AclObject $dacl

    Log "Somente leitura/execução: $target"
}

# -----------------------------------------------------
# CASES / RESULTS / LOGS
# -----------------------------------------------------

foreach ($d in @('cases', 'results', 'logs')) {

    $target = Join-Path $installRoot $d

    if (-not (Test-Path $target)) {
        continue
    }

    $dacl = Get-Acl -Path $target

    $dacl.SetAccessRule(
        (New-OpmAce `
            -Identity $users `
            -Rights ([System.Security.AccessControl.FileSystemRights]::Modify)
        )
    )

    Set-Acl -Path $target -AclObject $dacl

    Log "Leitura e escrita: $target"
}

# =====================================================
# PATH DE MÁQUINA (adiciona C:\OPM\bin; não duplica; preserva as demais)
# =====================================================
$machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
$pathEntries = @($machinePath -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })

if ($pathEntries -contains $binPath) {
    Log "C:\OPM\bin já está presente no PATH de máquina. Nada a fazer."
}
else {
    if ($pathEntries.Count -eq 0) {
        [Environment]::SetEnvironmentVariable('Path', $binPath, 'Machine')
    }
    else {
        $newMachinePath = (($pathEntries -join ';') + ';' + $binPath)
        [Environment]::SetEnvironmentVariable('Path', $newMachinePath, 'Machine')
    }
    Log "C:\OPM\bin adicionado ao PATH de máquina."
}

# =====================================================
# LIMPEZA DE TEMPORÁRIOS (mantém o zip em tools\ para reuso com hash)
# =====================================================
Log "Removendo arquivos de extração temporários..."
Remove-PathTolerant -Path $extractPath

Log "Instalação concluída com sucesso!"
Log "Abra um novo terminal para o novo PATH (opm-flow)."