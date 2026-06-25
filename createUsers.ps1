# =============================================================================
# CONFIGURACIÓN DE CREDENCIALES ADMINISTRATIVAS PARA AUTO-ELEVACIÓN
# =============================================================================
# Set-ExecutionPolicy Bypass -Scope LocalMachine -Force

# Forzar a la consola de PowerShell a usar codificación UTF-8 para la salida de texto
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$AdminUser = "Profesor"
$AdminPass = "Prof-A21"

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdmin)) {
    Write-Output "Elevando privilegios con la cuenta de $AdminUser..."
    
    $SecurePass = ConvertTo-SecureString $AdminPass -AsPlainText -Force
    $Credenciales = New-Object System.Management.Automation.PSCredential($AdminUser, $SecurePass)
    
    $ScriptPath = $MyInvocation.MyCommand.Path
    $PSEngine = if ($PSVersionTable.PSVersion.Major -ge 6) { "pwsh.exe" } else { "powershell.exe" }
    
    try {
        Start-Process $PSEngine -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`"" -Credential $Credenciales -Verb RunAs
        exit
    }
    catch {
        Write-Error "Error al intentar elevar privilegios: $_"
        exit
    }
}

# =============================================================================
# COMIENZO DEL SCRIPT (Universal y limpio de Write-Host)
# =============================================================================

$NuevaDescripcion = "MAÑANA"

# Traducción universal del SID (S-1-5-32-545) para obtener el nombre del grupo "Usuarios"
$SidUsuarios = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-32-545")
$GrupoUsuariosSistema = $SidUsuarios.Translate([System.Security.Principal.NTAccount]).Value.Split("\")[1]

$UsuariosYContrasenas = @(
    @{ Nombre = "1ESO"; Password = "ESOalumno1" },
    @{ Nombre = "2ESO"; Password = "ESOalumno2" },
    @{ Nombre = "3ESO"; Password = "ESOalumno3" },
    @{ Nombre = "4ESO"; Password = "ESOalumno4" },
    @{ Nombre = "1BACHA"; Password = "BalumnoA1" },
    @{ Nombre = "1BACHB"; Password = "Balumno1B" },
    @{ Nombre = "2BACHTIC"; Password = "2BalumnoT" },
    @{ Nombre = "2BACHTPYC"; Password = "alumno2BP" }
)

Write-Output "=== Iniciando configuración del sistema ==="
Write-Output "Motor: $($PSVersionTable.PSEdition) v$($PSVersionTable.PSVersion)"
Write-Output "Ejecutando como: $env:USERNAME"

# =============================================================================
# PASO 2: Modificar la descripción de la partición actual en el BCD
# =============================================================================
Write-Output ""
Write-Output "[1/2] Modificando la descripción en bcdedit..."
try {
    bcdedit /set `{current`} description "$NuevaDescripcion"
    Write-Output "CONSEGUIDO: Descripción de {current} cambiada a '$NuevaDescripcion'."
}
catch {
    Write-Error "Error al ejecutar bcdedit: $_"
}

# =============================================================================
# PASO 3: Gestión de usuarios mediante [ADSI]
# =============================================================================
Write-Output ""
Write-Output "[2/2] Procesando la lista de usuarios y contraseñas..."

$ComputerContext = [ADSI]"WinNT://$env:COMPUTERNAME"
$GroupContext = [ADSI]"WinNT://$env:COMPUTERNAME/$GrupoUsuariosSistema,group"

foreach ($Item in $UsuariosYContrasenas) {
    $Usuario = $Item.Nombre
    $PasswordTexto = $Item.Password

    $UserExists = $ComputerContext.Children | Where-Object { $_.SchemaClassName -eq "user" -and $_.Name -eq $Usuario }

    if (-not $UserExists) {
        try {
            $NewUser = $ComputerContext.Create("user", $Usuario)
            $NewUser.SetPassword($PasswordTexto)
            $NewUser.Put("Description", "Usuario para el aula: $Usuario")
            $NewUser.Put("FullName", "Alumno $Usuario")
            $NewUser.SetInfo()

            # Forzar flag 66048 (Cuenta Normal + Contraseña Nunca Expira)
            $NewUser.Put("userFlags", 66048)
            $NewUser.SetInfo()

            Write-Output "  -> Usuario '$Usuario' creado con éxito."

            # Añadir al grupo de Usuarios estándar
            $GroupContext.Add($NewUser.Path)
            Write-Output "  -> '$Usuario' añadido al grupo local '$GrupoUsuariosSistema'."

        }
        catch {
            Write-Error "Error al procesar el usuario '$Usuario': $_"
        }
    }
    else {
        Write-Output "  INFO: El usuario '$Usuario' ya existe en este equipo. Saltando."
    }
}

Write-Output ""
Write-Output "=== Proceso finalizado correctamente ==="
Read-Host "Presiona Intro para salir"