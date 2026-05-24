param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('Enable', 'Disable', 'Reduced', 'Full')]
    [string]$Mode
)

# If no Mode parameter provided, toggle hibernation based on current state
if (-not $PSBoundParameters.ContainsKey('Mode')) {
    $hibernationStatus = (powercfg /a | Select-String "Hibernation").Line
    if ($hibernationStatus -match "not available") {
        $Mode = 'Enable'
    } else {
        $Mode = 'Disable'
    }
}

# Require admin privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Este script requiere permisos de administrador."
    Start-Process powershell -ArgumentList "-File `"$PSCommandPath`" -Mode $Mode" -Verb RunAs
    exit
}

switch ($Mode) {
    'Enable' {
        Write-Host "Activando hibernación..."
        powercfg /h /type full
        powercfg /h on
    }
    'Disable' {
        Write-Host "Desactivando hibernación..."
        powercfg /h off
    }
    'Reduced' {
        Write-Host "Activando hibernación reducida..."
        powercfg /h /type reduced
        powercfg /h on
    }
    'Full' {
        Write-Host "Activando hibernación completa..."
        powercfg /h /type full
        powercfg /h on
    }
}

Write-Host "Operación completada."