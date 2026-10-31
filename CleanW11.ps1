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

$freeSpaceBefore = @{}
$spaceMeasurementIncomplete = $false
try {
    foreach ($drive in [System.IO.DriveInfo]::GetDrives()) {
        if ($drive.DriveType -eq [System.IO.DriveType]::Fixed) {
            try {
                if ($drive.IsReady) {
                    $freeSpaceBefore[$drive.Name] = $drive.AvailableFreeSpace
                }
                else {
                    $spaceMeasurementIncomplete = $true
                }
            }
            catch {
                $spaceMeasurementIncomplete = $true
                Write-Warning "No se pudo medir el espacio libre inicial en '$($drive.Name)': $($_.Exception.Message)"
            }
        }
    }
}
catch {
    $spaceMeasurementIncomplete = $true
    Write-Warning "No se pudieron enumerar las unidades para medir el espacio libre inicial: $($_.Exception.Message)"
}

# Detiene servicio de Windows Update para limpiar su caché
Write-Host "Deteniendo servicio wuauserv..." -ForegroundColor Cyan
Stop-Service -Name wuauserv -ErrorAction SilentlyContinue

# Rutas a limpiar
$paths = @(
    "$env:Temp\*",
    "C:\Windows\Temp\*",
    "C:\Windows\SoftwareDistribution\Download\*",
    "C:\Windows\Prefetch\*"
)

# Eliminación recursiva y forzada
foreach ($path in $paths) {
    if (Test-Path $path) {
        try {
            Write-Host "Limpiando $path" -ForegroundColor Yellow
            Remove-Item -Path $path -Recurse -Force -ErrorAction Stop
        }
        catch {
            $errMsg = if ($_.Exception) { $_.Exception.Message } else { $_.ToString() }
            Write-Warning "Error al limpiar ${path}: ${errMsg}"
        }
    }
}

# Vacía la Papelera de reciclaje
Write-Host "Vaciando Papelera de reciclaje..." -ForegroundColor Cyan
try {
    if (Get-Command -Name Clear-RecycleBin -ErrorAction SilentlyContinue) {
        # Clear-RecycleBin está disponible en PowerShell; usarla directamente
        Clear-RecycleBin -Force -ErrorAction SilentlyContinue -Confirm:$false
    }
    else {
        # Fallback para entornos donde Clear-RecycleBin no exista: usar Shell.Application COM
        $shell = New-Object -ComObject Shell.Application
        $recycle = $shell.Namespace(0xA)
        if ($recycle) {
            # Invocar el verbo "empty" en la Papelera
            $null = $recycle.Items() | ForEach-Object { $recycle.InvokeVerb("empty") }
        }
        else {
            throw "No se pudo acceder a la Papelera de reciclaje mediante COM."
        }
    }
    Write-Host "Papelera vaciada." -ForegroundColor Yellow
}
catch {
    Write-Warning "No se pudo vaciar la Papelera de reciclaje: $($_.Exception.Message)"
}

# Elimina caché de miniaturas
Write-Host "Eliminando caché de miniaturas..." -ForegroundColor Cyan
$thumbCache = "$env:LocalAppData\Microsoft\Windows\Explorer\thumbcache_*.db"
if (Test-Path $env:LocalAppData\Microsoft\Windows\Explorer) {
    Remove-Item -Path $thumbCache -Force -ErrorAction SilentlyContinue
}


# Reinicia servicio de Windows Update
Write-Host "Reiniciando servicio wuauserv..." -ForegroundColor Cyan
Start-Service -Name wuauserv -ErrorAction SilentlyContinue

# Limpieza de registros de eventos
Write-Host "Limpiando registros de eventos..." -ForegroundColor Cyan
$cleanedLogs = @()
$failedLogs = @()
try {
    $eventLogs = @(& wevtutil.exe el)
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "No se pudo obtener la lista de registros de eventos: wevtutil devolvió código de salida $LASTEXITCODE."
    }
    else {
        foreach ($logEntry in $eventLogs) {
            $log = $logEntry.Trim()
            if ($log) {
                try {
                    & wevtutil.exe cl "$log"
                    if ($LASTEXITCODE -ne 0) {
                        throw "wevtutil devolvió código de salida $LASTEXITCODE."
                    }
                    $cleanedLogs += $log
                }
                catch {
                    $errorMessage = if ($_.Exception) { $_.Exception.Message } else { $_.ToString() }
                    Write-Warning "Error al limpiar registro '${log}': $errorMessage. Se continuará con los demás registros."
                    $failedLogs += $log
                }
            }
        }
    }
}
catch {
    $errorMessage = if ($_.Exception) { $_.Exception.Message } else { $_.ToString() }
    Write-Warning "No se pudieron procesar los registros de eventos: $errorMessage. Se continuará con el resto de la limpieza."
}

if ($cleanedLogs.Count -gt 0) {
    Write-Host ("Registros limpiados ({0}): {1}" -f $cleanedLogs.Count, ($cleanedLogs -join ', ')) -ForegroundColor Yellow
}
if ($failedLogs.Count -gt 0) {
    Write-Warning ("No se pudieron limpiar {0} registro(s): {1}" -f $failedLogs.Count, ($failedLogs -join ', '))
}

# Ejecuta Liberador de espacio en disco (cleanmgr)
Write-Host "Reduciendo el almacén de componentes con DISM..." -ForegroundColor Cyan
try {
    & dism.exe /online /Cleanup-Image /StartComponentCleanup /ResetBase
    Write-Host "Almacén de componentes reducido." -ForegroundColor Yellow
}
catch {
    Write-Warning "No se pudo ejecutar DISM: $($_.Exception.Message)"
}

Write-Host "Ejecutando Liberador de espacio en disco..." -ForegroundColor Cyan
Start-Process -FilePath "cleanmgr.exe" -ArgumentList "/sagerun:1" -Wait

Write-Host "Limpieza completada con éxito." -ForegroundColor Green

# Limpieza del caché de parches de MSI
Write-Host "Limpiando caché de parches de MSI..." -ForegroundColor Cyan
try {
    Stop-Service -Name msiserver -Force -ErrorAction Stop
    $installerPolicyPath = "HKLM:\Software\Policies\Microsoft\Windows\Installer"
    New-Item -Path $installerPolicyPath -Force -ErrorAction Stop | Out-Null
    New-ItemProperty -Path $installerPolicyPath -Name "MaxPatchCacheSize" -Value 0 -PropertyType DWord -Force -ErrorAction Stop
    $patchCachePath = Join-Path $env:WINDIR 'Installer\$PatchCache$'
    if (Test-Path $patchCachePath) {
        Remove-Item -Path $patchCachePath -Recurse -Force -ErrorAction Stop
    }
    Start-Service -Name msiserver -ErrorAction Stop
    Stop-Service -Name msiserver -Force -ErrorAction Stop
    New-ItemProperty -Path $installerPolicyPath -Name "MaxPatchCacheSize" -Value 10 -PropertyType DWord -Force -ErrorAction Stop
    Start-Service -Name msiserver -ErrorAction Stop
    Write-Host "Caché de parches de MSI limpiado." -ForegroundColor Yellow
}
catch {
    Write-Warning "Error al limpiar caché de parches de MSI: $($_.Exception.Message)"
}


# Informa sobre carpetas vacías en Program Files sin modificarlas
Write-Host "Buscando carpetas vacías en Program Files..." -ForegroundColor Cyan
$programFiles = @("$env:ProgramFiles", "${env:ProgramFiles(x86)}")
$emptyFolders = @()
$failedFolders = @()

foreach ($folder in $programFiles) {
    if (Test-Path -LiteralPath $folder -PathType Container) {
        try {
            $childFolders = @(Get-ChildItem -LiteralPath $folder -Directory -ErrorAction Stop)
        }
        catch {
            $errorMessage = if ($_.Exception) { $_.Exception.Message } else { $_.ToString() }
            Write-Warning "Error al enumerar las carpetas de '$folder': $errorMessage. Se continuará con las demás rutas."
            $failedFolders += $folder
            continue
        }

        foreach ($childFolder in $childFolders) {
            try {
                $folderContents = @(Get-ChildItem -LiteralPath $childFolder.FullName -Force -ErrorAction Stop)
                if ($folderContents.Count -eq 0) {
                    $emptyFolders += $childFolder.FullName
                }
            }
            catch {
                $errorMessage = if ($_.Exception) { $_.Exception.Message } else { $_.ToString() }
                Write-Warning "Error al procesar la carpeta '$($childFolder.FullName)': $errorMessage. Se continuará con las demás carpetas."
                $failedFolders += $childFolder.FullName
            }
        }
    }
}

Write-Host "Informe de carpetas vacías:" -ForegroundColor Cyan
Write-Host ("  Carpetas vacías encontradas: {0}" -f $emptyFolders.Count)
if ($emptyFolders.Count -gt 0) {
    $emptyFolders | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
}
Write-Host "  No se ha borrado ninguna carpeta durante este análisis."
Write-Host ("  Carpetas que no se pudieron analizar: {0}" -f $failedFolders.Count)
if ($failedFolders.Count -gt 0) {
    Write-Host ("  Carpetas con error: {0}" -f ($failedFolders -join '; ')) -ForegroundColor Yellow
}

# Analiza carpetas que comienzan por punto en la raíz del perfil y las compara con aplicaciones instaladas
Write-Host "Analizando carpetas que comienzan por punto en el perfil..." -ForegroundColor Cyan
$profilePath = $env:USERPROFILE
$programInstallRoots = @(
    $env:ProgramFiles,
    ${env:ProgramFiles(x86)},
    $env:ProgramW6432,
    (Join-Path $env:LOCALAPPDATA 'Programs')
) |
    Where-Object { $_ } |
    Select-Object -Unique
$uninstallRegistryPaths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKCU:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
)
$hiddenProfileFolders = @()
$profileScanErrors = @()
$installedPrograms = @()
$installedProgramsScanErrors = @()

if (Test-Path -LiteralPath $profilePath -PathType Container) {
    try {
        $hiddenProfileFolders = @(Get-ChildItem -LiteralPath $profilePath -Directory -Force -ErrorAction Stop |
            Where-Object { $_.Name.StartsWith('.') })
    }
    catch {
        $profileScanErrors += "No se pudo analizar '$profilePath': $($_.Exception.Message)"
    }
}
else {
    $profileScanErrors += "No existe la ruta del perfil '$profilePath'."
}

foreach ($installRoot in $programInstallRoots) {
    if (-not (Test-Path -LiteralPath $installRoot -PathType Container)) {
        continue
    }

    try {
        $installedPrograms += @(Get-ChildItem -LiteralPath $installRoot -Directory -ErrorAction Stop |
            ForEach-Object {
                [PSCustomObject]@{
                    Name = $_.Name
                    Path = $_.FullName
                }
            })
    }
    catch {
        $installedProgramsScanErrors += "No se pudo analizar '$installRoot': $($_.Exception.Message)"
    }
}

foreach ($registryPath in $uninstallRegistryPaths) {
    if (-not (Test-Path -LiteralPath $registryPath)) {
        continue
    }

    try {
        $appKeys = @(Get-ChildItem -LiteralPath $registryPath -ErrorAction Stop)
    }
    catch {
        $installedProgramsScanErrors += "No se pudo consultar '$registryPath': $($_.Exception.Message)"
        continue
    }

    foreach ($appKey in $appKeys) {
        try {
            $app = Get-ItemProperty -LiteralPath $appKey.PSPath -ErrorAction Stop
            if ($app.DisplayName) {
                $installedPrograms += [PSCustomObject]@{
                    Name = $app.DisplayName
                    Path = $app.InstallLocation
                }
            }
        }
        catch {
            $installedProgramsScanErrors += "No se pudo leer una aplicación de '$($appKey.PSPath)': $($_.Exception.Message)"
        }
    }
}

try {
    if (Get-Command -Name Get-AppxPackage -ErrorAction SilentlyContinue) {
        $installedPrograms += @(Get-AppxPackage -ErrorAction Stop | ForEach-Object {
            [PSCustomObject]@{
                Name = $_.Name
                Path = $_.InstallLocation
            }
        })
    }
    else {
        $installedProgramsScanErrors += "No está disponible Get-AppxPackage para consultar aplicaciones de Microsoft Store."
    }
}
catch {
    $installedProgramsScanErrors += "No se pudieron consultar las aplicaciones de Microsoft Store: $($_.Exception.Message)"
}

$folderAnalysis = @()
foreach ($hiddenFolder in $hiddenProfileFolders) {
    $normalizedFolderName = [regex]::Replace($hiddenFolder.Name.TrimStart('.'), '[^a-zA-Z0-9]', '').ToLowerInvariant()
    $matchingProgram = $installedPrograms | Where-Object {
        $normalizedName = [regex]::Replace($_.Name, '[^a-zA-Z0-9]', '').ToLowerInvariant()
        $normalizedPathName = if ($_.Path) {
            $installLocation = [Environment]::ExpandEnvironmentVariables($_.Path.Trim('"'))
            [regex]::Replace((Split-Path $installLocation.TrimEnd('\', '/') -Leaf), '[^a-zA-Z0-9]', '').ToLowerInvariant()
        }
        $normalizedName -eq $normalizedFolderName -or $normalizedPathName -eq $normalizedFolderName
    } | Select-Object -First 1

    try {
        $files = @(Get-ChildItem -LiteralPath $hiddenFolder.FullName -File -Force -Recurse -ErrorAction Stop)
        [long]$folderSize = ($files | Measure-Object -Property Length -Sum).Sum
        $folderAnalysis += [PSCustomObject]@{
            Path = $hiddenFolder.FullName
            Size = $folderSize
            SizeComplete = $true
            MatchingProgram = $matchingProgram
        }
    }
    catch {
        Write-Warning "No se pudo calcular el tamaño completo de '$($hiddenFolder.FullName)': $($_.Exception.Message)"
        $folderAnalysis += [PSCustomObject]@{
            Path = $hiddenFolder.FullName
            Size = $null
            SizeComplete = $false
            MatchingProgram = $matchingProgram
        }
    }
}

$potentialFolders = @($folderAnalysis | Where-Object { -not $_.MatchingProgram })
$topLevelPotentialFolders = @($potentialFolders | Where-Object {
    $candidatePath = $_.Path
    -not ($potentialFolders | Where-Object {
        $_.Path -ne $candidatePath -and $candidatePath.StartsWith($_.Path.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)
    })
})
[long]$potentialSpace = 0
$potentialSpaceComplete = $profileScanErrors.Count -eq 0 -and $installedProgramsScanErrors.Count -eq 0

Write-Host "Informe de carpetas ocultas y aplicaciones instaladas:" -ForegroundColor Cyan
Write-Host ("  Carpetas encontradas en el perfil: {0}" -f $hiddenProfileFolders.Count)
foreach ($analysis in $folderAnalysis) {
    $sizeDescription = if ($analysis.SizeComplete) {
        "{0:N2} MB" -f ($analysis.Size / 1MB)
    }
    else {
        "Tamaño no disponible (análisis incompleto)"
    }
    $appDescription = if ($analysis.MatchingProgram) {
        if ($analysis.MatchingProgram.Path) {
            "Coincidencia con aplicación instalada: $($analysis.MatchingProgram.Name) ($($analysis.MatchingProgram.Path))"
        }
        else {
            "Coincidencia con aplicación registrada: $($analysis.MatchingProgram.Name)"
        }
    }
    else {
        "Sin coincidencia en las ubicaciones consultadas ni en el Registro; revisar antes de considerar huérfana"
    }
    Write-Host ("  {0} | {1} | {2}" -f $analysis.Path, $sizeDescription, $appDescription)
}

foreach ($candidate in $topLevelPotentialFolders) {
    if ($candidate.SizeComplete) {
        $potentialSpace += [long]$candidate.Size
    }
    else {
        $potentialSpaceComplete = $false
    }
}
$potentialSpaceDescription = if ($potentialSpaceComplete) {
    "{0:N2} MB" -f ($potentialSpace / 1MB)
}
else {
    "al menos {0:N2} MB; hay carpetas cuyo tamaño no se pudo calcular" -f ($potentialSpace / 1MB)
}
Write-Host ("  Espacio potencialmente recuperable, sin duplicar carpetas anidadas: {0}" -f $potentialSpaceDescription)
Write-Host "  La falta de coincidencia por nombre no confirma que el programa esté desinstalado. No se ha borrado ninguna carpeta."
if ($profileScanErrors.Count -gt 0) {
    $profileScanErrors | ForEach-Object { Write-Warning $_ }
}
if ($installedProgramsScanErrors.Count -gt 0) {
    $installedProgramsScanErrors | ForEach-Object { Write-Warning $_ }
}

try {
    [long]$netSpaceChange = 0
    [long]$freeSpaceAfterTotal = 0
    $measuredDriveCount = 0
    foreach ($drive in [System.IO.DriveInfo]::GetDrives()) {
        if ($drive.DriveType -eq [System.IO.DriveType]::Fixed) {
            try {
                if (-not $drive.IsReady) {
                    $spaceMeasurementIncomplete = $true
                    continue
                }

                $freeSpaceAfter = $drive.AvailableFreeSpace
                $freeSpaceAfterTotal += $freeSpaceAfter
                if ($freeSpaceBefore.ContainsKey($drive.Name)) {
                    $netSpaceChange += $freeSpaceAfter - [long]$freeSpaceBefore[$drive.Name]
                    $measuredDriveCount++
                }
                else {
                    $spaceMeasurementIncomplete = $true
                }
            }
            catch {
                $spaceMeasurementIncomplete = $true
                Write-Warning "No se pudo medir el espacio libre final en '$($drive.Name)': $($_.Exception.Message)"
            }
        }
    }

    if ($measuredDriveCount -gt 0) {
        $absoluteChange = [math]::Abs([double]$netSpaceChange)
        $changeDescription = "{0:N0} bytes ({1:N2} GB)" -f $absoluteChange, ($absoluteChange / 1GB)
        if ($netSpaceChange -gt 0) {
            Write-Host "  Espacio liberado total neto: $changeDescription"
        }
        elseif ($netSpaceChange -lt 0) {
            Write-Host "  Disminución neta del espacio libre: $changeDescription" -ForegroundColor Yellow
        }
        else {
            Write-Host "  Espacio liberado total neto: 0 bytes (0 GB)"
        }
        Write-Host ("  Espacio libre actual en las unidades medidas: {0:N0} bytes ({1:N2} GB)" -f $freeSpaceAfterTotal, ($freeSpaceAfterTotal / 1GB))
        if ($spaceMeasurementIncomplete -or $measuredDriveCount -ne $freeSpaceBefore.Count) {
            Write-Warning "La medición puede estar incompleta porque no se pudieron comparar todas las unidades fijas."
        }
        Write-Host "  Nota: el cambio es neto y puede incluir actividad simultánea del sistema."
    }
    else {
        Write-Warning "No se pudo calcular el espacio liberado: no hay unidades fijas con mediciones inicial y final."
    }
}
catch {
    Write-Warning "No se pudo calcular el espacio liberado total: $($_.Exception.Message)"
}

Write-Host "Limpieza y verificación completadas." -ForegroundColor Green