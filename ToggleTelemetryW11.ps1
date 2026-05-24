param(
    [ValidateSet("Enable","Disable")]
    [string]$State
)

# --- FUNCIÓN: Autoelevar privilegios ---
function Assert-Admin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)

    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host "Elevando privilegios..."
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "powershell.exe"
        $psi.Arguments = "-ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`" $args"
        $psi.Verb = "runas"
        try {
            [System.Diagnostics.Process]::Start($psi) | Out-Null
        } catch {
            Write-Error "No se pudo obtener privilegios de administrador."
        }
        exit
    }
}

Assert-Admin

# --- CONFIGURACIÓN ---
$diagKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
$diagValueName = "AllowTelemetry"

$telemetryServices = @(
    "DiagTrack",
    "dmwappushsvc",
    "diagnosticshub.standardcollector.service"
)

# --- FUNCIONES ---
function Set-TelemetryLevel {
    param([int]$Level)

    if (-not (Test-Path $diagKey)) {
        New-Item -Path $diagKey -Force | Out-Null
    }

    New-ItemProperty -Path $diagKey -Name $diagValueName -Value $Level -PropertyType DWord -Force | Out-Null
}

function Disable-Telemetry {
    Set-TelemetryLevel -Level 0
    foreach ($svc in $telemetryServices) {
        $service = Get-Service -Name $svc -ErrorAction SilentlyContinue
        if ($service) {
            Stop-Service $svc -Force -ErrorAction SilentlyContinue
            Set-Service $svc -StartupType Disabled
        }
    }
    Write-Host "Telemetría DESACTIVADA."
}

function Enable-Telemetry {
    Set-TelemetryLevel -Level 3
    foreach ($svc in $telemetryServices) {
        $service = Get-Service -Name $svc -ErrorAction SilentlyContinue
        if ($service) {
            Set-Service $svc -StartupType Manual
            Start-Service $svc -ErrorAction SilentlyContinue
        }
    }
    Write-Host "Telemetría ACTIVADA."
}

function Get-TelemetryState {
    if (Test-Path $diagKey) {
        $val = (Get-ItemProperty -Path $diagKey -Name $diagValueName -ErrorAction SilentlyContinue).$diagValueName
        if ($null -ne $val) { return $val }
    }
    return 3  # Por defecto Windows usa telemetría completa
}

function Switch-Telemetry {
    $current = Get-TelemetryState
    if ($current -eq 0) {
        Enable-Telemetry
    } else {
        Disable-Telemetry
    }
}

# --- LÓGICA PRINCIPAL ---
if ($State -eq "Enable") {
    Enable-Telemetry
}
elseif ($State -eq "Disable") {
    Disable-Telemetry
}
else {
    Switch-Telemetry
}
