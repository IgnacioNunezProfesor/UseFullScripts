# Elevar privilegios en el mismo script
$currentUser = [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
$adminRole = [Security.Principal.WindowsBuiltInRole]::Administrator

if (-not $currentUser.IsInRole($adminRole)) {
    Write-Host "Se requieren permisos de administrador. Solicitando elevación..."
    try {
        Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`"" -Wait
        exit
    }
    catch {
        Write-Warning "No se pudo obtener permisos de administrador."
        exit 1
    }
}

# Detiene servicio de Windows Update para limpiar su caché
Write-Host "Deteniendo servicio wuauserv..." -ForegroundColor Cyan
Stop-Service -Name wuauserv -ErrorAction SilentlyContinue

# Rutas a limpiar
$paths = @(
    "$env:Temp\*",
    "C:\Windows\Temp\*",
    "C:\Windows\SoftwareDistribution\Download\*",
    "C:\Windows\Prefetch\*"
)

# Eliminación recursiva y forzada
foreach ($path in $paths) {
    if (Test-Path $path) {
        try {
            Write-Host "Limpiando $path" -ForegroundColor Yellow
            Remove-Item -Path $path -Recurse -Force -ErrorAction Stop
        }
        catch {
            Write-Warning "Error al limpiar ${path}"
        }
    }
}

# Vacía la Papelera de reciclaje
Write-Host "Vaciando Papelera de reciclaje..." -ForegroundColor Cyan
Get-RecycleBin -ErrorAction SilentlyContinue | Clear-RecycleBin -Force -ErrorAction SilentlyContinue

# Elimina caché de miniaturas
Write-Host "Eliminando caché de miniaturas..." -ForegroundColor Cyan
$thumbCache = "$env:LocalAppData\Microsoft\Windows\Explorer\thumbcache_*.db"
if (Test-Path $env:LocalAppData\Microsoft\Windows\Explorer) {
    Remove-Item -Path $thumbCache -Force -ErrorAction SilentlyContinue
}


# Reinicia servicio de Windows Update
Write-Host "Reiniciando servicio wuauserv..." -ForegroundColor Cyan
Start-Service -Name wuauserv -ErrorAction SilentlyContinue

# Limpieza de registros de eventos
Write-Host "Limpiando registros de eventos..." -ForegroundColor Cyan
wevtutil el | ForEach-Object {
    try {
        wevtutil cl $_ -ErrorAction Stop
        Write-Host "Registro $_ limpiado." -ForegroundColor Yellow
    }
    catch {
        Write-Warning "Error al limpiar registro"
    }
}   

# Ejecuta Liberador de espacio en disco (cleanmgr)
Write-Host "Ejecutando Liberador de espacio en disco..." -ForegroundColor Cyan
Start-Process -FilePath "cleanmgr.exe" -ArgumentList "/sagerun:1" -Wait

Write-Host "Limpieza completada con éxito." -ForegroundColor Green
