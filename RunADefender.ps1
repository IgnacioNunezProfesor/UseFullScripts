# Script para actualizar definiciones y hacer escaneo completo con Microsoft Defender

$DefenderPath = "$Env:ProgramFiles\Windows Defender\MpCmdRun.exe"

# Verifica si el ejecutable existe
if (Test-Path $DefenderPath) {
    Write-Host "🟢 Ejecutando actualización de definiciones..."
    & $DefenderPath -SignatureUpdate

    Write-Host "🟢 Iniciando escaneo completo..."
    & $DefenderPath -Scan -ScanType 2
}
else {
    Write-Host "❌ No se encontró MpCmdRun.exe en la ruta esperada. Revisa si tienes Defender instalado correctamente."
}
