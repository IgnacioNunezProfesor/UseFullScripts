param(
    [string]$NombreUsuario,
    [string]$Contrasena,
    [bool]$Administrador,
    [switch]$Volatil
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

function Test-EsAdministrador {
    $Identidad = [Security.Principal.WindowsIdentity]::GetCurrent()
    $Principal = New-Object Security.Principal.WindowsPrincipal($Identidad)
    return $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-NombreGrupoLocal {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Sid
    )

    $Identificador = New-Object System.Security.Principal.SecurityIdentifier($Sid)
    return $Identificador.Translate([System.Security.Principal.NTAccount]).Value.Split("\")[-1]
}

function ConvertTo-PlainText {
    param(
        [Parameter(Mandatory = $true)]
        [System.Security.SecureString]$Valor
    )

    $Puntero = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Valor)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($Puntero)
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($Puntero)
    }
}

function Register-VolatileProfileCleanup {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SidUsuario
    )

    $NombreTarea = "CreateUsers-Volatil-$SidUsuario"
    if (Get-ScheduledTask -TaskName $NombreTarea -ErrorAction SilentlyContinue) {
        throw "Ya existe la tarea '$NombreTarea'; no se reemplazará."
    }

    $AuditPol = Join-Path $env:SystemRoot "System32\auditpol.exe"
    & $AuditPol /set /subcategory:"{0CCE9216-69AE-11D9-BED3-505054503030}" /success:enable | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "No se pudo habilitar la auditoría de cierres de sesión necesaria para la limpieza del perfil."
    }

    $Directorio = Join-Path $env:ProgramData "CreateUsers"
    if (-not (Test-Path -LiteralPath $Directorio)) {
        New-Item -Path $Directorio -ItemType Directory -Force | Out-Null
    }
    elseif (-not (Get-Item -LiteralPath $Directorio).PSIsContainer) {
        throw "La ruta '$Directorio' existe y no es una carpeta."
    }

    $SidSistema = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-18")
    $SidAdministradores = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-32-544")
    $SidUsuarios = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-32-545")
    $SeguridadDirectorio = New-Object System.Security.AccessControl.DirectorySecurity
    $SeguridadDirectorio.SetAccessRuleProtection($true, $false)
    $HerenciaDirectorio = [System.Security.AccessControl.InheritanceFlags]::ContainerInherit -bor
        [System.Security.AccessControl.InheritanceFlags]::ObjectInherit
    $SeguridadDirectorio.SetOwner($SidAdministradores)
    $SeguridadDirectorio.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($SidSistema, [System.Security.AccessControl.FileSystemRights]::FullControl, $HerenciaDirectorio, [System.Security.AccessControl.PropagationFlags]::None, [System.Security.AccessControl.AccessControlType]::Allow)))
    $SeguridadDirectorio.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($SidAdministradores, [System.Security.AccessControl.FileSystemRights]::FullControl, $HerenciaDirectorio, [System.Security.AccessControl.PropagationFlags]::None, [System.Security.AccessControl.AccessControlType]::Allow)))
    $SeguridadDirectorio.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($SidUsuarios, [System.Security.AccessControl.FileSystemRights]::ReadAndExecute, $HerenciaDirectorio, [System.Security.AccessControl.PropagationFlags]::None, [System.Security.AccessControl.AccessControlType]::Allow)))
    Set-Acl -LiteralPath $Directorio -AclObject $SeguridadDirectorio

    $RutaScriptLimpieza = Join-Path $Directorio "RemoveVolatileProfile-$SidUsuario.ps1"
    if (Test-Path -LiteralPath $RutaScriptLimpieza) {
        throw "El archivo de limpieza '$RutaScriptLimpieza' ya existe; no se reemplazará."
    }
    $ScriptLimpieza = @'
param(
    [Parameter(Mandatory = $true)]
    [string]$Sid
)

$ErrorActionPreference = "Stop"
if ($Sid -notmatch '^S-\d(-\d+)+$') {
    throw "El SID recibido no tiene un formato válido."
}

$RutaRegistro = Join-Path $env:ProgramData "CreateUsers\volatile-profile.log"
Add-Content -LiteralPath $RutaRegistro -Value "$(Get-Date -Format o) Limpieza iniciada para $Sid."
$Limite = (Get-Date).AddMinutes(10)
do {
    $Perfil = Get-CimInstance -ClassName Win32_UserProfile -Filter "SID='$Sid'"
    if (-not $Perfil) {
        Add-Content -LiteralPath $RutaRegistro -Value "$(Get-Date -Format o) El perfil de $Sid ya no existe."
        return
    }

    if (-not $Perfil.Loaded) {
        Remove-CimInstance -InputObject $Perfil
        Add-Content -LiteralPath $RutaRegistro -Value "$(Get-Date -Format o) Perfil de $Sid eliminado."
        return
    }

    Start-Sleep -Seconds 5
} while ((Get-Date) -lt $Limite)

throw "El perfil de $Sid sigue cargado después de 10 minutos; no se eliminó."
'@
    Set-Content -LiteralPath $RutaScriptLimpieza -Value $ScriptLimpieza -Encoding UTF8

    $ConsultaEvento = "<QueryList><Query Id=`"0`" Path=`"Security`"><Select Path=`"Security`">*[System[Provider[@Name='Microsoft-Windows-Security-Auditing'] and EventID=4634] and EventData[Data[@Name='TargetUserSid']='$SidUsuario']]</Select></Query></QueryList>"
    $Argumentos = '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "{0}" -Sid "{1}"' -f $RutaScriptLimpieza, $SidUsuario
    $EscaparXml = { param([string]$Valor) [System.Security.SecurityElement]::Escape($Valor) }
    $SuscripcionXml = & $EscaparXml $ConsultaEvento
    $EjecutableXml = & $EscaparXml (Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe")
    $ArgumentosXml = & $EscaparXml $Argumentos
    $TareaXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Description>Elimina el perfil local de $SidUsuario al cerrar sesión.</Description>
  </RegistrationInfo>
  <Triggers>
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>$SuscripcionXml</Subscription>
      <Delay>PT1M</Delay>
    </EventTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>S-1-5-18</UserId>
      <LogonType>ServiceAccount</LogonType>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>Queue</MultipleInstancesPolicy>
    <StartWhenAvailable>true</StartWhenAvailable>
    <Enabled>true</Enabled>
    <ExecutionTimeLimit>PT15M</ExecutionTimeLimit>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>$EjecutableXml</Command>
      <Arguments>$ArgumentosXml</Arguments>
    </Exec>
  </Actions>
</Task>
"@

    Register-ScheduledTask -TaskName $NombreTarea -Xml $TareaXml | Out-Null

    Write-Output "Tarea '$NombreTarea' configurada para eliminar el perfil al cerrar sesión."
}

function New-UsuarioLocal {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Nombre,
        [Parameter(Mandatory = $true)]
        [System.Security.SecureString]$ContrasenaSegura,
        [Parameter(Mandatory = $true)]
        [bool]$EsAdministrador,
        [Parameter(Mandatory = $true)]
        [bool]$PerfilVolatil
    )

    $ContextoEquipo = [ADSI]"WinNT://$env:COMPUTERNAME"
    $UsuarioExistente = $ContextoEquipo.Children |
    Where-Object { $_.SchemaClassName -eq "user" -and $_.Name -eq $Nombre }

    if ($UsuarioExistente) {
        throw "El usuario local '$Nombre' ya existe en este equipo."
    }

    $ContrasenaTexto = ConvertTo-PlainText -Valor $ContrasenaSegura
    try {
        $NuevoUsuario = $ContextoEquipo.Create("user", $Nombre)
        $NuevoUsuario.SetPassword($ContrasenaTexto)
        $NuevoUsuario.Put("Description", "Usuario local: $Nombre")
        $NuevoUsuario.Put("FullName", $Nombre)
        $NuevoUsuario.SetInfo()

        $NuevoUsuario.Put("userFlags", 66048)
        $NuevoUsuario.SetInfo()

        $SidGrupo = if ($EsAdministrador) { "S-1-5-32-544" } else { "S-1-5-32-545" }
        $NombreGrupo = Get-NombreGrupoLocal -Sid $SidGrupo
        $GrupoLocal = [ADSI]"WinNT://$env:COMPUTERNAME/$NombreGrupo,group"
        $GrupoLocal.Add($NuevoUsuario.Path)

        Write-Output "Usuario local '$Nombre' creado correctamente."
        Write-Output "Añadido al grupo local '$NombreGrupo'."

        if ($PerfilVolatil) {
            try {
                $SidBytes = $NuevoUsuario.Get("objectSid")
                $SidUsuario = (New-Object System.Security.Principal.SecurityIdentifier($SidBytes, 0)).Value
                Register-VolatileProfileCleanup -SidUsuario $SidUsuario
            }
            catch {
                throw "La cuenta '$Nombre' fue creada, pero no se pudo completar la configuración de su perfil volátil: $_"
            }
        }
    }
    finally {
        $ContrasenaTexto = $null
    }
}

if (-not (Test-EsAdministrador)) {
    throw "Ejecuta este script en una consola de PowerShell abierta como administrador."
}

if ([string]::IsNullOrWhiteSpace($NombreUsuario)) {
    $NombreUsuario = Read-Host "Nombre del nuevo usuario local"
}

if ([string]::IsNullOrWhiteSpace($NombreUsuario)) {
    throw "El nombre de usuario no puede estar vacío."
}

if ($PSBoundParameters.ContainsKey("Contrasena")) {
    if ([string]::IsNullOrEmpty($Contrasena)) {
        throw "La contraseña no puede estar vacía."
    }

    Write-Warning "Al pasar la contraseña como parámetro, puede quedar guardada en el historial o visible en la línea de comandos."
    $ContrasenaSegura = ConvertTo-SecureString $Contrasena -AsPlainText -Force
}
else {
    $ContrasenaSegura = Read-Host "Contraseña del nuevo usuario" -AsSecureString
}

if ($ContrasenaSegura.Length -eq 0) {
    throw "La contraseña no puede estar vacía."
}

if ($PSBoundParameters.ContainsKey("Administrador")) {
    $EsAdministrador = $Administrador
}
else {
    do {
        $Respuesta = (Read-Host "¿Será administrador? (S/N)").Trim().ToUpperInvariant()
    } while ($Respuesta -notin @("S", "N"))

    $EsAdministrador = $Respuesta -eq "S"
}

try {
    New-UsuarioLocal -Nombre $NombreUsuario -ContrasenaSegura $ContrasenaSegura -EsAdministrador $EsAdministrador -PerfilVolatil ([bool]$Volatil)
}
catch {
    Write-Error "Error al crear o configurar el usuario '$NombreUsuario': $_"
    exit 1
}
finally {
    if ($ContrasenaSegura) {
        $ContrasenaSegura.Dispose()
    }
}
