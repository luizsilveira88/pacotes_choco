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

function Remove-PublicDesktopShortcuts {
    param(
        [string]$AppName
    )

    $publicDesktop = "$env:PUBLIC\Desktop"

    if (-not (Test-Path $publicDesktop)) {
        Log "Área de trabalho pública não encontrada."
        return
    }

    $shortcuts = Get-ChildItem $publicDesktop -Filter "*.lnk" -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like "*$AppName*" }

    if (-not $shortcuts) {
        Log "Nenhum atalho antigo encontrado na área de trabalho pública."
        return
    }

    foreach ($shortcut in $shortcuts) {
        try {
            Remove-Item $shortcut.FullName -Force -ErrorAction Stop
            Log "Atalho removido: $($shortcut.Name)"
        }
        catch {
            Log "Erro ao remover atalho: $($shortcut.Name)"
        }
    }
}

function Uninstall-Legacy {
    param($app)

    if (-not $app.UninstallString) {
        Log "Legado encontrado, mas sem UninstallString. Pulando."
        return
    }

    Log "Desinstalando versão antiga: $($app.DisplayName)"

    if ($app.UninstallString -match "msiexec") {
        $guid = ($app.UninstallString -replace '.*\{','{' -replace '\}.*','}')
        Start-Process "msiexec.exe" -ArgumentList "/x $guid /qn /norestart" -Wait
    }
    else {
        Start-Process "cmd.exe" -ArgumentList "/c $($app.UninstallString)" -Wait
    }

    Log "Legado removido com sucesso."

    # Remover atalhos antigos
    Remove-PublicDesktopShortcuts -AppName $app.DisplayName
}