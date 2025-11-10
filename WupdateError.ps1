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

# Ejecutar como administrador
Write-Host "Deteniendo servicios de Windows Update..."
Stop-Service wuauserv -Force
Stop-Service cryptSvc -Force
Stop-Service bits -Force
Stop-Service msiserver -Force

Write-Host "Renombrando carpetas de caché..."
Rename-Item -Path "C:\Windows\SoftwareDistribution" -NewName "SoftwareDistribution.old" -ErrorAction SilentlyContinue
Rename-Item -Path "C:\Windows\System32\catroot2" -NewName "catroot2.old" -ErrorAction SilentlyContinue

Write-Host "Reiniciando servicios..."
Start-Service wuauserv
Start-Service cryptSvc
Start-Service bits
Start-Service msiserver

Write-Host "Ejecutando escaneo DISM..."
DISM /Online /Cleanup-Image /RestoreHealth

Write-Host "Ejecutando escaneo SFC..."
sfc /scannow

Write-Host "Proceso completado. Reinicia el sistema e intenta actualizar nuevamente."
