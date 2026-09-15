# =====================================================
# FUNÇÕES AUXILIARES
# =====================================================
function Log($msg) {
    Write-Host "[$packageTitle] $msg"
}

function Get-Hash($file) {
    try { (Get-FileHash $file -Algorithm SHA256).Hash }
    catch { $null }
}

function Hash-Valid($file, $expected) {
    $hash = Get-Hash $file
    return ($hash -and $hash -eq $expected)
}

function Get-LegacyInstall {
    param($displayName)

    $regPaths = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    )

    Get-ChildItem $regPaths -ErrorAction SilentlyContinue |
        ForEach-Object { Get-ItemProperty $_.PsPath -ErrorAction SilentlyContinue } |
        Where-Object { $_.DisplayName -like $displayName } |
        Select-Object -First 1
}

function Remove-Shortcuts {
    param(
        [string]$AppName
    )

    $paths = @(
        "$env:PUBLIC\Desktop",
        "$env:USERPROFILE\Desktop"
    )

    foreach ($path in $paths) {

        if (-not (Test-Path $path)) {
            Log "Área de trabalho não encontrada em: $path"
            continue
        }

        $shortcuts = Get-ChildItem $path -Filter "*.lnk" -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like "*$AppName*" }

        if (-not $shortcuts) {
            Log "Nenhum atalho encontrado em: $path"
            continue
        }

        foreach ($shortcut in $shortcuts) {
            try {
                Remove-Item $shortcut.FullName -Force -ErrorAction Stop
                Log "Atalho removido ($path): $($shortcut.Name)"
            }
            catch {
                Log "Erro ao remover atalho ($path): $($shortcut.Name)"
            }
        }
    }
}

function Uninstall-Legacy {
    param($app)

    # Prioriza QuietUninstallString
    $uninstallCmd = $null

    if ($app.QuietUninstallString) {
        $uninstallCmd = $app.QuietUninstallString
        Log "Usando QuietUninstallString para desinstalação."
    }
    elseif ($app.UninstallString) {
        $uninstallCmd = $app.UninstallString
        Log "QuietUninstallString não encontrada. Usando UninstallString."
    }
    else {
        Log "Legado encontrado, mas sem string de desinstalação. Pulando."
        return
    }

    Log "Desinstalando versão antiga: $($app.DisplayName)"

    try {

        # Caso seja MSI
        if ($uninstallCmd -match "msiexec") {

            # Extrai GUID se existir
            if ($uninstallCmd -match "\{[A-F0-9\-]+\}") {
                $guid = $matches[0]
                Start-Process "msiexec.exe" `
                    -ArgumentList @("/x", $guid, "/qn", "/norestart") `
                    -Wait -ErrorAction Stop
            }
            else {
                Start-Process "cmd.exe" `
                    -ArgumentList "/c $uninstallCmd" `
                    -Wait -ErrorAction Stop
            }
        }
        else {
            Start-Process "cmd.exe" `
                -ArgumentList "/c $uninstallCmd" `
                -Wait -ErrorAction Stop
        }

        Log "Legado removido com sucesso."

        # Remover atalhos antigos
        Remove-Shortcuts -AppName $app.DisplayName
    }
    catch {
        Log "Erro durante desinstalação do legado: $($app.DisplayName)"
    }
}

function Move-ShortcutToPublicDesktop {
    param(
        [string]$AppName
    )

    $userDesktop   = "$env:USERPROFILE\Desktop"
    $publicDesktop = "$env:PUBLIC\Desktop"

    if (-not (Test-Path $userDesktop)) {
        Log "Área de trabalho do usuário não encontrada."
        return
    }

    if (-not (Test-Path $publicDesktop)) {
        Log "Área de trabalho pública não encontrada."
        return
    }

    $shortcuts = Get-ChildItem $userDesktop -Filter "*.lnk" -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like "*$AppName*" }

    if (-not $shortcuts) {
        Log "Nenhum atalho encontrado na área de trabalho do usuário."
        return
    }

    foreach ($shortcut in $shortcuts) {
        $destination = Join-Path $publicDesktop $shortcut.Name

        try {
            Move-Item $shortcut.FullName $destination -Force -ErrorAction Stop
            Log "Atalho movido para área pública: $($shortcut.Name)"
        }
        catch {
            Log "Erro ao mover atalho: $($shortcut.Name)"
        }
    }
}
function Remove-PathTolerant {
    param(
        [string]$Path,
        [int]$Tries = 3,
        [int]$DelaySeconds = 2
    )

    for ($i = 1; $i -le $Tries; $i++) {
        try {
            Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
            Log "Removido: $Path"
            return $true
        }
        catch {
            if ($i -lt $Tries) {
                Start-Sleep -Seconds $DelaySeconds
            }
            else {
                Log "AVISO: nao foi possivel remover '$Path' (mantido para diagnostico). Erro: $($_.Exception.Message). Remova manualmente se necessario."
                return $false
            }
        }
    }

    return $false
}