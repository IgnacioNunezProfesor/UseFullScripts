# Guardar como: toggle-hypervisor.ps1

# Función para comprobar si se está ejecutando como administrador
function Test-IsAdmin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Si no es administrador, relanzar el script como administrador
if (-not (Test-IsAdmin)) {
    Write-Host "Este script requiere privilegios de administrador. Relanzando..." -ForegroundColor Yellow
    Start-Process powershell "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
}

# Comprobar el estado actual del Hypervisor
$bcdOutput = bcdedit | Select-String "hypervisorlaunchtype"

if ($bcdOutput -match "On") {
    Write-Host "Hypervisor está ACTIVADO. Procediendo a DESACTIVAR..." -ForegroundColor Cyan
    bcdedit /set hypervisorlaunchtype off
    Write-Host "Hypervisor DESACTIVADO. Reinicia el sistema para aplicar los cambios." -ForegroundColor Green
} elseif ($bcdOutput -match "Off") {
    Write-Host "Hypervisor está DESACTIVADO. Procediendo a ACTIVAR..." -ForegroundColor Cyan
    bcdedit /set hypervisorlaunchtype auto
    Write-Host "Hypervisor ACTIVADO. Reinicia el sistema para aplicar los cambios." -ForegroundColor Green
} else {
    Write-Host "No se pudo determinar el estado del Hypervisor." -ForegroundColor Red
}
