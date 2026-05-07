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
            $errMsg = if ($_.Exception) { $_.Exception.Message } else { $_.ToString() }
            Write-Warning "Error al limpiar ${path}: ${errMsg}"
        }
    }
}

# Vacía la Papelera de reciclaje
Write-Host "Vaciando Papelera de reciclaje..." -ForegroundColor Cyan
try {
    if (Get-Command -Name Clear-RecycleBin -ErrorAction SilentlyContinue) {
        # Clear-RecycleBin está disponible en PowerShell; usarla directamente
        Clear-RecycleBin -Force -ErrorAction SilentlyContinue -Confirm:$false
    }
    else {
        # Fallback para entornos donde Clear-RecycleBin no exista: usar Shell.Application COM
        $shell = New-Object -ComObject Shell.Application
        $recycle = $shell.Namespace(0xA)
        if ($recycle) {
            # Invocar el verbo "empty" en la Papelera
            $null = $recycle.Items() | ForEach-Object { $recycle.InvokeVerb("empty") }
        }
        else {
            throw "No se pudo acceder a la Papelera de reciclaje mediante COM."
        }
    }
    Write-Host "Papelera vaciada." -ForegroundColor Yellow
}
catch {
    Write-Warning "No se pudo vaciar la Papelera de reciclaje: $($_.Exception.Message)"
}

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
    $log = $_.Trim()
    if ($log) {
        try {
            & wevtutil.exe cl "$log"
            if ($LASTEXITCODE -ne 0) {
                throw "wevtutil devolvió código de salida $LASTEXITCODE para el registro '$log'."
            }
            Write-Host "Registro $log limpiado." -ForegroundColor Yellow
        }
        catch {
            $errMsg = if ($_.Exception) { $_.Exception.Message } else { $_.ToString() }
            Write-Warning "Error al limpiar registro ${log}: ${errMsg}"
        }
    }
}   

# Ejecuta Liberador de espacio en disco (cleanmgr)
Write-Host "Reduciendo el almacén de componentes con DISM..." -ForegroundColor Cyan
try {
    & dism.exe /online /Cleanup-Image /StartComponentCleanup /ResetBase
    Write-Host "Almacén de componentes reducido." -ForegroundColor Yellow
}
catch {
    Write-Warning "No se pudo ejecutar DISM: $($_.Exception.Message)"
}

Write-Host "Ejecutando Liberador de espacio en disco..." -ForegroundColor Cyan
Start-Process -FilePath "cleanmgr.exe" -ArgumentList "/sagerun:1" -Wait

Write-Host "Limpieza completada con éxito." -ForegroundColor Green

# Limpieza del caché de parches de MSI
Write-Host "Limpiando caché de parches de MSI..." -ForegroundColor Cyan
try {
    Stop-Service -Name msiserver -Force -ErrorAction Stop
    New-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows\Installer" -Name "MaxPatchCacheSize" -Value 0 -PropertyType DWord -Force -ErrorAction Stop
    $patchCachePath = "$env:WINDIR\Installer\$PatchCache$"
    if (Test-Path $patchCachePath) {
        Remove-Item -Path $patchCachePath -Recurse -Force -ErrorAction Stop
    }
    Start-Service -Name msiserver -ErrorAction Stop
    Stop-Service -Name msiserver -Force -ErrorAction Stop
    New-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows\Installer" -Name "MaxPatchCacheSize" -Value 10 -PropertyType DWord -Force -ErrorAction Stop
    Start-Service -Name msiserver -ErrorAction Stop
    Write-Host "Caché de parches de MSI limpiado." -ForegroundColor Yellow
}
catch {
    Write-Warning "Error al limpiar caché de parches de MSI: $($_.Exception.Message)"
}


# Obtiene aplicaciones instaladas
Write-Host "Obteniendo aplicaciones instaladas..." -ForegroundColor Cyan
$installedApps = @()
$registryPaths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
)

foreach ($regPath in $registryPaths) {
    if (Test-Path $regPath) {
        $installedApps += Get-ItemProperty "$regPath\*" -ErrorAction SilentlyContinue | 
            Where-Object { $_.DisplayName } | 
            Select-Object -ExpandProperty DisplayName
    }
}

# Verifica carpetas en Program Files sin aplicaciones instaladas
Write-Host "Verificando carpetas en Program Files..." -ForegroundColor Cyan
$programFiles = @("$env:ProgramFiles", "${env:ProgramFiles(x86)}")

foreach ($folder in $programFiles) {
    if (Test-Path $folder) {
        Get-ChildItem -Path $folder -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $folderName = $_.Name
            $hasExecutables = @(Get-ChildItem -Path $_.FullName -Filter "*.exe" -Recurse -ErrorAction SilentlyContinue).Count -gt 0
            
            if (-not $hasExecutables) {
                if ($installedApps -notcontains $folderName) {
                    $folderSize = (Get-ChildItem -Path $_.FullName -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
                    $folderSizeMB = [math]::Round($folderSize / 1MB, 2)
                    Write-Warning "Carpeta sin ejecutables y no registrada: $($_.FullName) - Tamaño: $folderSizeMB MB"
                }
            }
        }
    }
}

Write-Host "Verificación completada." -ForegroundColor Green