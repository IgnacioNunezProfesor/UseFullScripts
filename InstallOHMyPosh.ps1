# Instala Oh My Posh y configura un tema aleatorio cada vez que se ejecute.
# Guarda este script como .ps1 y ejecútalo en PowerShell.

function Ensure-OhMyPosh {
    if (-not (Get-Command oh-my-posh -ErrorAction SilentlyContinue)) {
        Write-Host "Instalando Oh My Posh..." -ForegroundColor Green
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            winget install --id JanDeDobbeleer.OhMyPosh -e --accept-source-agreements --accept-package-agreements | Out-Null
        }
        else {
            Install-Module oh-my-posh -Scope CurrentUser -Force -AllowClobber | Out-Null
        }
    }
    Import-Module oh-my-posh -ErrorAction SilentlyContinue | Out-Null
}

function Get-RandomOhMyPoshTheme {
    $themes = @()

    if (Get-Command Get-PoshThemes -ErrorAction SilentlyContinue) {
        $themes = Get-PoshThemes | Select-Object -ExpandProperty Name
    }
    else {
        $themes = oh-my-posh --list 2>$null | ForEach-Object { $_.Trim() } | Where-Object { $_ -and $_ -ne 'Themes:' }
    }

    if (-not $themes) {
        Write-Error "No se encontraron temas de Oh My Posh."
        return $null
    }

    return Get-Random -InputObject $themes
}

function Get-ThemePath {
    param (
        [string]$ThemeName
    )

    if (Get-Command Get-PoshThemes -ErrorAction SilentlyContinue) {
        return (Get-PoshThemes | Where-Object { $_.Name -eq $ThemeName } | Select-Object -ExpandProperty Path)
    }

    $config = oh-my-posh --init --shell pwsh --config $ThemeName 2>$null
    if ($config) {
        return $ThemeName
    }

    return $null
}

function Update-ProfileWithTheme {
    param (
        [string]$ThemePath
    )

    $profileFile = $PROFILE.CurrentUserAllHosts
    if (-not (Test-Path $profileFile)) {
        New-Item -ItemType File -Path $profileFile -Force | Out-Null
    }

    $markerStart = '# <OhMyPoshRandomThemeStart>'
    $markerEnd = '# <OhMyPoshRandomThemeEnd>'
    $profileContent = Get-Content -Path $profileFile -Raw -ErrorAction SilentlyContinue

    if ($profileContent -match [regex]::Escape($markerStart) -and $profileContent -match [regex]::Escape($markerEnd)) {
        $profileContent = [regex]::Replace($profileContent, "(?s)${markerStart}.*?${markerEnd}", "$markerStart`r`noh-my-posh init pwsh --config \"$ThemePath\" | Invoke-Expression`r`n$markerEnd")
    }
    else {
        $profileContent += "`r`n$markerStart`r`noh-my-posh init pwsh --config \"$ThemePath\" | Invoke-Expression`r`n$markerEnd`r`n"
    }

    Set-Content -Path $profileFile -Value $profileContent -Force
    Write-Host "Perfil actualizado en $profileFile" -ForegroundColor Cyan
}

Ensure-OhMyPosh
$themeName = Get-RandomOhMyPoshTheme
if (-not $themeName) { exit 1 }

Write-Host "Tema seleccionado: $themeName" -ForegroundColor Yellow
$themePath = Get-ThemePath -ThemeName $themeName
if (-not $themePath) {
    Write-Error "No se pudo obtener la ruta del tema $themeName."
    exit 1
}

oh-my-posh init pwsh --config "$themePath" | Invoke-Expression
Update-ProfileWithTheme -ThemePath $themePath
Write-Host "Oh My Posh configurado con el tema aleatorio: $themeName" -ForegroundColor Green
