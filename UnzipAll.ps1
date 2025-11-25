<#
.SYNOPSIS
    Recursively extracts .zip and .rar archives found under a root folder into their containing folder.

.PARAMETER Root
    Root path to search for archives.

.EXAMPLE
    .\UnzipAll.ps1 -Root "C:\Data"
#>

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Root
)

if (-not (Test-Path -LiteralPath $Root)) {
    Write-Error "Root path not found: $Root"
    exit 1
}

# Try find 7-Zip (used for RAR and as fallback for ZIP)
$sevenZipCmd = (Get-Command '7z.exe' -ErrorAction SilentlyContinue).Source
if (-not $sevenZipCmd) {
    $candidates = @(
        "$env:ProgramFiles\7-Zip\7z.exe",
        "$env:ProgramFiles(x86)\7-Zip\7z.exe"
    )
    foreach ($c in $candidates) { if (Test-Path $c) { $sevenZipCmd = $c; break } }
}

$archives = Get-ChildItem -LiteralPath $Root -Recurse -File -Include *.zip, *.rar -ErrorAction SilentlyContinue

if (-not $archives) {
    Write-Output "No archives found under: $Root"
    exit 0
}

foreach ($a in $archives) {
    $full = $a.FullName
    $dest = $a.DirectoryName
    Write-Output "Extracting '$full' -> '$dest'"

    switch ($a.Extension.ToLower()) {
        '.zip' {
            try {
                Expand-Archive -LiteralPath $full -DestinationPath $dest -Force -ErrorAction Stop
            }
            catch {
                if ($sevenZipCmd) {
                    # fallback to 7z for problematic zip files
                    & $sevenZipCmd x -y "-o$dest" -- $full 2>&1 | Write-Verbose
                    if ($LASTEXITCODE -ne 0) { Write-Warning "7z failed for $full" }
                }
                else {
                    Write-Warning "Failed to extract ZIP and 7-Zip not available: $full"
                }
            }
        }
        '.rar' {
            if (-not $sevenZipCmd) {
                Write-Warning "Skipping RAR (7-Zip not found): $full"
            }
            else {
                & $sevenZipCmd x -y "-o$dest" -- $full 2>&1 | Write-Verbose
                if ($LASTEXITCODE -ne 0) { Write-Warning "7z failed for $full" }
            }
        }
        default {
            Write-Verbose "Unsupported extension for file: $full"
        }
    }
}