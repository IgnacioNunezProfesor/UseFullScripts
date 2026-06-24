# ==============================================================================
# 1. AUTO-ELEVACIÓN A ADMINISTRADOR
# ==============================================================================
$EsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $EsAdmin) {
    Write-Host "[-] El script no se está ejecutando como Administrador." -ForegroundColor Yellow
    Write-Host "[+] Solicitando permisos de Administrador..." -ForegroundColor Cyan
    Start-Sleep -Seconds 1
    
    # Relanza el propio script con privilegios elevados de Administrador
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    Exit
}

# ==============================================================================
# 2. DEFINICIÓN DE LA TABLA DE PROGRAMAS OPEN SOURCE
# ==============================================================================
$TablaProgramas = @(
    [PSCustomObject]@{ Nombre = "Mozilla Firefox"; Id = "Mozilla.Firefox" },
    [PSCustomObject]@{ Nombre = "7-Zip"; Id = "7zip.7zip" },
    [PSCustomObject]@{ Nombre = "VLC Media Player"; Id = "VideoLAN.VLC" },
    [PSCustomObject]@{ Nombre = "LibreOffice"; Id = "TheDocumentFoundation.LibreOffice" },
    [PSCustomObject]@{ Nombre = "Notepad++"; Id = "Notepad++.Notepad++" },
    [PSCustomObject]@{ Nombre = "SumatraPDF"; Id = "SumatraPDF.SumatraPDF" },
    [PSCustomObject]@{ Nombre = "GIMP"; Id = "GIMP.GIMP" }
)

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  Iniciando instalador global (Para todos los usuarios)   " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

# ==============================================================================
# 3. BUCLE DE INSTALACIÓN GLOBAL
# ==============================================================================
foreach ($Programa in $TablaProgramas) {
    Write-Host "--> Instalando a nivel de sistema: $($Programa.Nombre) [$($Programa.Id)]..." -ForegroundColor Yellow
    
    # NUEVO PARÁMETRO CLAVE:
    # --scope machine : Fuerza la instalación para todos los usuarios del equipo.
    
    winget install --id $Programa.Id --scope machine --silent --accept-source-agreements --accept-package-agreements
    
    # Comprobación del resultado
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[✓] ¡$($Programa.Nombre) instalado globalmente!" -ForegroundColor Green
    }
    else {
        Write-Host "[!] Código $LASTEXITCODE para $($Programa.Nombre). (Si ya existía, se omitirá)." -ForegroundColor DarkYellow
    }
    Write-Host "----------------------------------------------------------"
}

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  Proceso global completado. Todos los usuarios listos.  " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Read-Host "Presiona Enter para cerrar esta ventana..."