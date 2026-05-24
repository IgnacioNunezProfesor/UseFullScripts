# Solicitar elevación si no se ejecuta como administrador
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Se requieren permisos de administrador. Reiniciando con elevación y ejecutando ActualizarTodo..."
    $scriptPath = $MyInvocation.MyCommand.Definition
    $pwsh = (Get-Command pwsh -ErrorAction SilentlyContinue).Path
    $powershell = if ($pwsh) { $pwsh } else { (Get-Command powershell -ErrorAction SilentlyContinue).Path }
    $command = "& { . '$scriptPath'; ActualizarTodo }"
    Start-Process -FilePath $powershell -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", $command -Verb RunAs
    exit
}

function ActualizarTodo {
    # Actualizar Windows
    Write-Host "`n🔄 Buscando e instalando actualizaciones de Windows..."
    if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
        Install-Module PSWindowsUpdate -Force -Scope CurrentUser
    }
    Import-Module PSWindowsUpdate
    Get-WindowsUpdate -AcceptAll -Install -AutoReboot

    # Actualizar aplicaciones de Microsoft Store
    Write-Host "`n🛍️ Actualizando aplicaciones de Microsoft Store..."
    $msStoreApp = Get-AppxPackage -Name "Microsoft.WindowsStore"
    if ($msStoreApp) {
        Add-AppxPackage -Path $msStoreApp.InstallLocation -ErrorAction SilentlyContinue
    }
    else {
        Write-Warning "Microsoft Store no está instalado."
    }

    # Actualizar software instalado con Winget
    Write-Host "`n📦 Actualizando software instalado con Winget..."
    winget upgrade --all --silent

    # Actualizar Office 365
    Write-Host "`n📄 Actualizando Office 365..."
    $officeUpdater = "C:\Program Files\Common Files\Microsoft Shared\ClickToRun\OfficeC2RClient.exe"
    if (Test-Path $officeUpdater) {
        Start-Process -FilePath $officeUpdater -ArgumentList "/update user forceappshutdown=false displaylevel=True" 
    }
    else {
        Write-Warning "No se encontró el actualizador de Office en la ruta esperada."
    }

    Write-Host "`n✅ Actualización completa. El sistema y las aplicaciones están al día."
}

# Ejecutar función de actualización
ActualizarTodo
