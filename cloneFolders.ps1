param(
    [Parameter(Mandatory = $true)]
    [string]$SourcePath,

    [Parameter(Mandatory = $true)]
    [string]$DestinationPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LogFile,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $timestamp = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fff'
    [System.IO.File]::AppendAllText($LogFile, ("[{0}] {1}`n" -f $timestamp, $Message))
}

if (-not (Test-Path -LiteralPath $SourcePath -PathType Container)) {
    throw "La ruta de origen no existe o no es un directorio: $SourcePath"
}

if (-not (Test-Path -LiteralPath $DestinationPath)) {
    New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
}

$SourceRoot = (Resolve-Path -LiteralPath $SourcePath).Path
$DestinationRoot = (Resolve-Path -LiteralPath $DestinationPath).Path
$SourceParent = Split-Path -Path $SourceRoot -Parent
$LogFile = Join-Path -Path $SourceParent -ChildPath 'cloneFolders.resume.log'

if (-not (Test-Path -LiteralPath $LogFile)) {
    New-Item -ItemType File -Path $LogFile -Force | Out-Null
}

$CompletedFolders = @{}
if (Test-Path -LiteralPath $LogFile) {
    $folderDoneEntries = Select-String -Path $LogFile -Pattern '^\[.*\] FOLDER_DONE\|' -Raw
    foreach ($entry in $folderDoneEntries) {
        $parts = $entry -split '\|'
        if ($parts.Count -ge 2) {
            $folderPath = $parts[1].Trim()
            $CompletedFolders[$folderPath] = $true
        }
    }
}

$order = Get-ChildItem -LiteralPath $SourceRoot -Directory |
    Sort-Object -Property Name |
    Where-Object { -not $CompletedFolders.ContainsKey($_.FullName) }

foreach ($childFolder in $order) {
    $childSourcePath = $childFolder.FullName
    $childDestinationPath = Join-Path -Path $DestinationRoot -ChildPath $childFolder.Name

    $job = Start-ThreadJob -ScriptBlock {
        param(
            [string]$ChildSourcePath,
            [string]$ChildDestinationPath,
            [string]$LogFile
        )

        # Crear estructura de carpetas vacías
        Get-ChildItem -LiteralPath $ChildSourcePath -Directory -Recurse | ForEach-Object {
            $relativePath = $_.FullName.Substring($ChildSourcePath.Length).TrimStart('\', '/')
            $destDir = Join-Path -Path $ChildDestinationPath -ChildPath $relativePath
            if (-not (Test-Path -LiteralPath $destDir)) {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }
        }

        $files = Get-ChildItem -LiteralPath $ChildSourcePath -File -Recurse
        foreach ($file in $files) {
            $relativeFilePath = $file.FullName.Substring($ChildSourcePath.Length).TrimStart('\', '/')
            $destFile = Join-Path -Path $ChildDestinationPath -ChildPath $relativeFilePath
            $destDirectory = Split-Path -Path $destFile -Parent

            if (-not (Test-Path -LiteralPath $destDirectory)) {
                New-Item -ItemType Directory -Path $destDirectory -Force | Out-Null
            }

            $copyNeeded = $true
            if (Test-Path -LiteralPath $destFile -PathType Leaf) {
                $sourceFile = Get-Item -LiteralPath $file.FullName
                $destinationFile = Get-Item -LiteralPath $destFile

                if ($sourceFile.Length -eq $destinationFile.Length -and
                    $sourceFile.LastWriteTimeUtc -eq $destinationFile.LastWriteTimeUtc) {
                    $copyNeeded = $false
                }
            }

            if ($copyNeeded) {
                Copy-Item -LiteralPath $file.FullName -Destination $destFile -Force
                Write-Log -LogFile $LogFile -Message ("FILE_COPIED|{0}" -f $file.FullName)
            }
            else {
                Write-Log -LogFile $LogFile -Message ("FILE_SKIPPED|{0}" -f $file.FullName)
            }
        }

        Write-Log -LogFile $LogFile -Message ("FOLDER_DONE|{0}" -f $ChildSourcePath)
    } -ArgumentList $childSourcePath, $childDestinationPath, $LogFile

    $job
}

if ($jobs) {
    $jobs | Wait-Job | Receive-Job | Out-Null
}

Write-Host "Copia terminada. Log guardado en: $LogFile"
