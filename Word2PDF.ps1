[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
    [string]$FilePath,

    [Parameter(Mandatory = $true)]
    [string[]]$PageRanges
)

begin {
    # Cargamos la librería para el portapapeles
    Add-Type -AssemblyName System.Windows.Forms
}

process {
    # Forzar ruta como cadena de texto limpia
    $ResolvedPath = Resolve-Path $FilePath
    [string]$FullFilePath = $ResolvedPath.ProviderPath

    if (-not (Test-Path $FullFilePath)) {
        Write-Error "El archivo no existe: $FullFilePath"
        return
    }

    $Directory = Split-Path $FullFilePath
    $BaseName = [System.IO.Path]::GetFileNameWithoutExtension($FullFilePath)

    Write-Host "Abriendo Word..." -ForegroundColor Cyan
    $Word = New-Object -ComObject Word.Application
    $Word.Visible = $false

    try {
        $Doc = $Word.Documents.Open($FullFilePath)
        
        $wdGoToPage = 1
        $wdGoToAbsolute = 1
        # Constante para exportar a PDF nativo de Word
        $wdExportFormatPDF = 17 

        foreach ($Range in $PageRanges) {
            if ($Range -match '^(\d+)-(\d+)$') {
                $StartPage = [int]$Matches[1]
                $EndPage = [int]$Matches[2]
                $Suffix = "${StartPage}-${EndPage}"
            }
            elseif ($Range -match '^(\d+)$') {
                $StartPage = [int]$Matches[1]
                $EndPage = $StartPage
                $Suffix = "$StartPage"
            }
            else { continue }

            Write-Host "Procesando rango en PDF: $Suffix..." -ForegroundColor Yellow

            # Seleccionar inicio y fin del rango
            $StartRange = $Word.Selection.GoTo($wdGoToPage, $wdGoToAbsolute, $StartPage)
            $EndRange = $Word.Selection.GoTo($wdGoToPage, $wdGoToAbsolute, ($EndPage))
            
            if ($EndRange.Start -eq $StartRange.Start -and $StartPage -ne ($EndPage)) {
                $Word.Selection.EndKey(6) | Out-Null
                $EndPosition = $Word.Selection.Start
            }
            else {
                $EndPosition = $EndRange.Start
            }

            # Copiar el fragmento seleccionado
            $NewDocRange = $Doc.Range($StartRange.Start, $EndPosition)
            $NewDocRange.Copy()

            # Crear el documento temporal en Word y pegar el contenido
            $NewDoc = $Word.Documents.Add()
            $NewDoc.Content.Paste()

            # Construir la ruta de salida con extensión .pdf
            [string]$SavePathPDF = Join-Path $Directory "${BaseName}_[Pags_${Suffix}].pdf"
            
            # Exportar directamente a PDF (Método nativo y limpio)
            $NewDoc.ExportAsFixedFormat($SavePathPDF, $wdExportFormatPDF)
            
            # Cerrar el documento temporal sin guardar el .docx intermedio
            $NewDoc.Close($false)

            Write-Host "Guardado correctamente en PDF: $SavePathPDF" -ForegroundColor Green
        }
    }
    catch {
        Write-Error "Error de procesamiento: $($_.Exception.Message)"
    }
    finally {
        # Limpieza total de procesos COM
        if ($Doc) { $Doc.Close($false) }
        if ($Word) {
            $Word.Quit()
            [System.Runtime.InteropServices.Marshal]::ReleaseComObject($Word) | Out-Null
        }
        try { [System.Windows.Forms.Clipboard]::Clear() } catch {}
        
        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()
    }
}