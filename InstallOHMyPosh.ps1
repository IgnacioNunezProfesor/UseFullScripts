# Script para instalar Oh My Posh en Windows 11 y configurar un tema aleatorio.
# Este script actualiza el perfil de PowerShell para usar el tema seleccionado.

function EnsureOhMyPosh {
    if (-not (Get-Command oh-my-posh -ErrorAction SilentlyContinue)) {
        Write-Host "Instalando Oh My Posh..." -ForegroundColor Green
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            winget install --id JanDeDobbeleer.OhMyPosh -e --accept-source-agreements --accept-package-agreements | Out-Null
            # Forzar la recarga de la ruta para que el comando esté disponible de inmediato
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        }
        else {
            Install-Module oh-my-posh -Scope CurrentUser -Force -AllowClobber | Out-Null
        }
    }

    # Asegurar que los temas estén descargados y la variable de entorno configurada
    if (-not $env:POSH_THEMES_PATH) {
        $env:POSH_THEMES_PATH = Join-Path $env:LOCALAPPDATA "oh-my-posh\themes"
    }
    
    if (-not (Test-Path $env:POSH_THEMES_PATH)) {
        Write-Host "Descargando temas de Oh My Posh..." -ForegroundColor Cyan
        New-Item -ItemType Directory -Path $env:POSH_THEMES_PATH -Force | Out-Null
    }

    # Comprobar si hay archivos de temas, si no, descargarlos
    if (-not (Get-ChildItem -Path $env:POSH_THEMES_PATH -Filter "*.omp.json" -ErrorAction SilentlyContinue)) {
        Invoke-WebRequest -Uri "https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/themes.zip" -OutFile "$env:TEMP\themes.zip"
        Expand-Archive -Path "$env:TEMP\themes.zip" -DestinationPath $env:POSH_THEMES_PATH -Force
        Remove-Item "$env:TEMP\themes.zip"
    }
}

function Get-RandomOhMyPoshTheme {
    # Intenta obtener los temas buscando archivos .omp.json en la ruta de temas
    $themes = Get-ChildItem -Path $env:POSH_THEMES_PATH -Filter "*.omp.json" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty BaseName
    
    # Fallback: si no hay archivos, intenta usar el comando oficial
    if (-not $themes) {
        $themes = oh-my-posh theme get --list | ConvertFrom-Json | Select-Object -ExpandProperty name -ErrorAction SilentlyContinue
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

    # Intenta obtener la ruta local del tema
    $themePath = Join-Path $env:POSH_THEMES_PATH "$ThemeName.omp.json"
    if (Test-Path $themePath) { return $themePath }
    return $ThemeName # Retorna el nombre si no encuentra la ruta física
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
        $profileContent = [regex]::Replace($profileContent, "(?s)${markerStart}.*?${markerEnd}", "$markerStart`r`noh-my-posh init pwsh --config `"$ThemePath`" | Invoke-Expression`r`n$markerEnd")
    }
    else {
        $profileContent += "`r`n$markerStart`r`noh-my-posh init pwsh --config `"$ThemePath`" | Invoke-Expression`r`n$markerEnd`r`n"
    }

    Set-Content -Path $profileFile -Value $profileContent -Force
    Write-Host "Perfil actualizado en $profileFile" -ForegroundColor Cyan
}

# --- Ejecución Principal ---
if ($IsWindows -and -not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Algunas instalaciones de Winget pueden requerir permisos de administrador."
}

EnsureOhMyPosh
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
Write-Host "¡Listo! Oh My Posh configurado con el tema: $themeName" -ForegroundColor Green
