$ErrorActionPreference = 'Stop'

# =====================================================
# CONFIGURACOES PERSONALIZADAS DO PACOTE
# EXTENSO DO ARQUIVO (msi, exe, zip, etc)
# HASH SHA256 DO ARQUIVO
# =====================================================
$fileType = 'zip'
$url = 'https://github.com/OPM/ResInsight/releases/download/v2026.06.1/ResInsight-2026.06.1_win64.zip'
$expectedHash = 'D555F8315F8ED52E8516101AA33C05890BBA97370AF50DC5F68423E44F1E8D61'
$silentArgs = ''

# =====================================================
# VARIAVEIS DO NUSPEC (id, title, version)
# =====================================================
$packageId = $env:ChocolateyPackageName
$packageTitle = $env:ChocolateyPackageTitle
$packageVersion = $env:ChocolateyPackageVersion

# =====================================================
# Caminhos
# =====================================================
$toolsDir   = Split-Path -Parent $MyInvocation.MyCommand.Definition
$tempDir    = Join-Path $env:TEMP (Join-Path $packageId $packageVersion)
$installRoot = 'C:\resinsight'

# =====================================================
# FUNCOES AUXILIARES (helper compartilhada: tools\helpers.ps1)
# =====================================================
. "$toolsDir\helpers.ps1"

# =====================================================
# DOWNLOAD E EXTRACAO (direto da URL)
# =====================================================
Log "Baixando e extraindo da URL... $url"

$packageArgs = @{
    packageName    = $packageId
    url            = $url
    checksum       = $expectedHash
    checksumType   = 'sha256'
    unzipLocation  = $tempDir
}

Install-ChocolateyZipPackage @packageArgs

Log "Download e extração concluídos em $tempDir."

# =====================================================
# LOCALIZA O CONTEUDO EXTRAIDO (procura bin\ResInsight.exe)
# =====================================================
$contentSource = $tempDir

if (-not (Test-Path (Join-Path $tempDir 'bin\ResInsight.exe'))) {
    $candidate = Get-ChildItem -Path $tempDir -Directory -Recurse -ErrorAction SilentlyContinue |
        Where-Object { Test-Path (Join-Path $_.FullName 'bin\ResInsight.exe') } |
        Select-Object -First 1

    if ($candidate) {
        $contentSource = $candidate.FullName
    }
    else {
        Throw "Conteudo do ResInsight (bin\ResInsight.exe) nao encontrado na extracao: $tempDir"
    }
}

Log "Conteúdo extraído localizado: $contentSource"

# =====================================================
# INSTALACAO EM C:\resinsight
# =====================================================
if (-not (Test-Path $installRoot)) {
    New-Item -ItemType Directory -Path $installRoot -Force | Out-Null
    Log "Criado: $installRoot"
}

# Remove instalacao anterior para evitar arquivos obsoletos
Remove-PathTolerant -Path $installRoot
New-Item -ItemType Directory -Path $installRoot -Force | Out-Null

# Copia o conteudo extraido para C:\resinsight
Get-ChildItem -Path $contentSource -Force |
    Copy-Item -Destination $installRoot -Recurse -Force
Log "Arquivos instalados em $installRoot."

# =====================================================
# PERMISSOES DE SEGURANCA (Administradores/SYSTEM FullControl; Users leitura/execucao)
# =====================================================
Log "Aplicando permissoes em $installRoot..."

function New-ResInsightAce {
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

# SIDs padrao do Windows
$adm = New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-544')
$system = New-Object System.Security.Principal.SecurityIdentifier('S-1-5-18')
$users = New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-545')

$acl = Get-Acl -Path $installRoot

# Remove heranca de C:\
$acl.SetAccessRuleProtection($true, $false)

# Administradores
$acl.SetAccessRule(
    (New-ResInsightAce -Identity $adm -Rights ([System.Security.AccessControl.FileSystemRights]::FullControl))
)

# SYSTEM
$acl.SetAccessRule(
    (New-ResInsightAce -Identity $system -Rights ([System.Security.AccessControl.FileSystemRights]::FullControl))
)

# Usuarios comuns
$acl.SetAccessRule(
    (New-ResInsightAce -Identity $users -Rights ([System.Security.AccessControl.FileSystemRights]::ReadAndExecute))
)

Set-Acl -Path $installRoot -AclObject $acl

Log "Permissoes aplicadas em $installRoot."

# =====================================================
# ATALHO NO DESKTOP PUBLICO (todos os usuarios)
# =====================================================
$shortcutPath = Join-Path $env:PUBLIC 'Desktop\ResInsight.lnk'
$targetExe = Join-Path $installRoot 'bin\ResInsight.exe'

if (Test-Path $targetExe) {
    $ws = New-Object -ComObject WScript.Shell
    $shortcut = $ws.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $targetExe
    $shortcut.WorkingDirectory = Split-Path $targetExe -Parent
    $shortcut.IconLocation = "$targetExe,0"
    $shortcut.Description = 'ResInsight'
    $shortcut.Save()
    Log "Atalho criado para todos os usuarios: $shortcutPath"
}
else {
    Log "AVISO: executavel $targetExe nao encontrado; atalho nao criado."
}

# =====================================================
# LIMPEZA DE TEMPORARIOS
# =====================================================
Log "Removendo arquivos de extracao temporarios..."
Remove-PathTolerant -Path $tempDir

Log "Instalacao concluida com sucesso!"