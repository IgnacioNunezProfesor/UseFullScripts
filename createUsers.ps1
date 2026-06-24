# =============================================================================
# CONFIGURACIÓN DE CREDENCIALES ADMINISTRATIVAS PARA AUTO-ELEVACIÓN
# =============================================================================
$AdminUser = "Profesor"
$AdminPass = "Prof-A21"

# Función para comprobar si la sesión actual ya es Administrador
function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Si NO es administrador, se relanza a sí mismo usando la versión de PowerShell activa
if (-not (Test-IsAdmin)) {
    Write-Host "Elevando privilegios con la cuenta de $AdminUser..." -ForegroundColor Yellow
    
    $SecurePass = ConvertTo-SecureString $AdminPass -AsPlainText -Force
    $Credenciales = New-Object System.Management.Automation.PSCredential($AdminUser, $SecurePass)
    
    $ScriptPath = $MyInvocation.MyCommand.Path
    
    # Detecta dinámicamente si estamos en PowerShell Core (pwsh) o Windows PowerShell (powershell)
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
# COMIENZO DEL SCRIPT (Universal: Windows PowerShell 5.1 & PowerShell 7+)
# =============================================================================

$NuevaDescripcion = "MAÑANA"

# Traducción universal del SID (S-1-5-32-545) para obtener el nombre del grupo "Usuarios" en cualquier idioma
$SidUsuarios = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-32-545")
$GrupoUsuariosSistema = $SidUsuarios.Translate([System.Security.Principal.NTAccount]).Value.Split("\")[1]

# Lista de alumnos y contraseñas
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

Write-Host "=== Iniciando configuración del sistema ===" -ForegroundColor Cyan
Write-Host "Motor: $($PSVersionTable.PSEdition) v$($PSVersionTable.PSVersion)" -ForegroundColor Cyan
Write-Host "Ejecutando como: $env:USERNAME" -ForegroundColor Cyan

# =============================================================================
# PASO 2: Modificar la descripción de la partición actual en el BCD
# =============================================================================
Write-Host "`n[1/2] Modificando la descripción en bcdedit..." -ForegroundColor Yellow
try {
    bcdedit /set `{current`} description "$NuevaDescripcion"
    Write-Host "✓ Descripción de {current} cambiada a '$NuevaDescripcion' con éxito." -ForegroundColor Green
}
catch {
    Write-Error "Error al ejecutar bcdedit: $_"
}

# =============================================================================
# PASO 3: Gestión de usuarios mediante [ADSI] (Máxima compatibilidad multiplataforma)
# =============================================================================
Write-Host "`n[2/2] Procesando la lista de usuarios y contraseñas..." -ForegroundColor Yellow

$ComputerContext = [ADSI]"WinNT://$env:COMPUTERNAME"
$GroupContext = [ADSI]"WinNT://$env:COMPUTERNAME/$GrupoUsuariosSistema,group"

foreach ($Item in $UsuariosYContrasenas) {
    $Usuario = $Item.Nombre
    $PasswordTexto = $Item.Password

    # Comprobación compatible de existencia de usuario
    $UserExists = $ComputerContext.Children | Where-Object { $_.SchemaClassName -eq "user" -and $_.Name -eq $Usuario }

    if (-not $UserExists) {
        try {
            # Crear usuario
            $NewUser = $ComputerContext.Create("user", $Usuario)
            $NewUser.SetPassword($PasswordTexto)
            $NewUser.Put("Description", "Usuario para el aula: $Usuario")
            $NewUser.Put("FullName", "Alumno $Usuario")
            $NewUser.SetInfo()

            # Forzar flag 66048 (Cuenta Normal + Contraseña Nunca Expira)
            $NewUser.Put("userFlags", 66048)
            $NewUser.SetInfo()

            Write-Host "  ✓ Usuario '$Usuario' creado con éxito." -ForegroundColor Green

            # Añadir al grupo de Usuarios estándar
            $GroupContext.Add($NewUser.Path)
            Write-Host "  ✓ '$Usuario' añadido al grupo local '$GrupoUsuariosSistema'." -ForegroundColor Green

        }
        catch {
            Write-Error "Error al procesar el usuario '$Usuario': $_"
        }
    }
    else {
        Write-Host "El usuario '$Usuario' ya existe en este equipo. Saltando." -ForegroundColor Cyan
    }
}

Write-Host "`n=== Proceso finalizado correctamente ===" -ForegroundColor Green
Read-Host "`nPresiona Intro para salir"