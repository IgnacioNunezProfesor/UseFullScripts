# 1. Busca los dispositivos cuya clase sea USB y que utilicen el driver de almacenamiento (USBSTOR)
$USBDevices = Get-PnpDevice -Class "USB" -ErrorAction SilentlyContinue | Where-Object { $_.Service -eq "USBSTOR" }

if ($USBDevices) {
    # Tomamos el estado del primer dispositivo encontrado para decidir si activar o desactivar
    $CurrentStatus = $USBDevices[0].Status

    if ($CurrentStatus -eq "OK") {
        # Si está activo (OK), lo deshabilitamos
        ForEach ($Device in $USBDevices) {
            Disable-PnpDevice -InstanceId $Device.InstanceId -Confirm:$false
        }
        Write-Host "------------------------------------------------" -ForegroundColor Yellow
        Write-Host "🔒 HARDWARE USB DESACTIVADO. Bloqueo inmediato." -ForegroundColor Red
        Write-Host "------------------------------------------------" -ForegroundColor Yellow
    } 
    else {
        # Si no está en "OK" (suele mostrar "Error" o "Unknown" al estar deshabilitado), lo activamos
        ForEach ($Device in $USBDevices) {
            Enable-PnpDevice -InstanceId $Device.InstanceId -Confirm:$false
        }
        Write-Host "------------------------------------------------" -ForegroundColor Yellow
        Write-Host "🔓 HARDWARE USB ACTIVADO. Pendrives listos." -ForegroundColor Green
        Write-Host "------------------------------------------------" -ForegroundColor Yellow
    }
}
else {
    Write-Host "------------------------------------------------" -ForegroundColor Convert
    Write-Host "No se detectó ningún pendrive conectado actualmente." -ForegroundColor Cyan
    Write-Host "Por favor, conecta un pendrive una primera vez para que" -ForegroundColor Cyan
    Write-Host "el script pueda identificar el hardware y desactivarlo." -ForegroundColor Cyan
    Write-Host "------------------------------------------------" -ForegroundColor Convert
}