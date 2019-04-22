function Import-AudiobookMetadata() {
  <#
  .SYNOPSIS
  Applies metadata and artwork defined in external files to an m4b audiobook.
  .PARAMETER bookFile
  File path of the m4b audiobook.
  .PARAMETER metadataDir
  Directory in which the metadata files are stored.
  .PARAMETER cleanup
  Remove temporary files created during the process.
  These are the resized image file.
  .PARAMETER magick
  Path to the magick binary.
  If not specified, assume magick is available on the path.
  .PARAMETER mp4box
  Path to the mp4box binary.
  If not specified, assume mp4box is available on the path.
  .EXAMPLE
  Import-AudiobookMetadata 'C:\MyBooks\The Book.m4b' 'C:\Metadata'
  Applies metadata found in C:\Metadata\...\The Book.yaml and image
  found at C:\Metadata\...\The Book.jpg to the audiobook file.
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true, Position=1)]
    [string]
    $bookFile,
    
    [Parameter(Mandatory=$true, Position=2)]
    [string]
    $metadataDir,
    
    [Parameter()]
    [switch]
    $cleanup = $true,

    [Parameter()]
    [string]
    $magick = 'magick',

    [Parameter()]
    [string]
    $mp4box = 'mp4box'
  )

  Set-StrictMode -Version 'Latest'
  Use-CallerPreference -Cmdlet $PSCmdlet -Session $ExecutionContext.SessionState

  if (!(Assert-CommandExists $magick)) {
    Write-Error "magick not found. This is required to resize artwork."
    return
  }

  if (!(Assert-CommandExists $mp4box)) {
    Write-Error "mp4box not found. This is required to apply the metadata to the m4b file."
    return
  }

  # Names for temporary files
  $artworkFile = 'artwork.jpg'

  # Assume the name of the book file will be used to identify
  # the book, for the metadata filename.
  $bookId = [IO.Path]::GetFileNameWithoutExtension($bookFile)

  Push-Location

  try {
    cd (Split-Path $bookFile -Parent)
    
    # Get metadata
    $metadata = Get-AudiobookMetadata $metadataDir $bookId
    if (-not($metadata)) {
      Write-Warning "No metadata found for $bookId"
      return
    }

    # Format metadata property with series number, if in series, and book title
    if ($metadata.Contains('series') -and $metadata.Contains('seriesNumber')) {
      $metadata.bookInSeries = "{0} {1}: {2}" -f $metadata.series, $metadata.seriesNumber, $metadata.title
    } else {
      $metadata.bookInSeries = $metadata.title
    }

    # Format description to include narrator
    $descriptionParts = New-Object System.Collections.Generic.List[System.String]

    if ($metadata.Contains('narrator')) {
      $descriptionParts.Add("Read by $($metadata.narrator).")
    }

    if ($metadata.Contains('description')) {
      $descriptionParts.Add($metadata.description)
    }

    $metadata.fullDescription = $descriptionParts -join "`r`n`r`n"

    Write-Debug "Metadata:`r`n$($metadata | Format-Table -AutoSize -Wrap | Out-String)"

    # Write the combined audio file with chapter information to a new mp4 file.
    & $mp4box $bookFile -lang $metadata.language -itags album="$($metadata.bookInSeries)":name="$($metadata.title)":artist="$($metadata.author)":created="$($metadata.year)":genre=Audiobook:comment="$($metadata.fullDescription)"

    # Set artwork if it was found.
    if ($metadata.Contains('image')) {
      & $magick convert -resize 1000x1000> -quality 80 $metadata.image $artworkFile
      & $mp4box $bookFile -itags cover="$artworkFile"
    }

    # Tidy up by removing temporary files.
    if ($cleanup) {
      Write-Debug "Removing temporary files: $artworkFile"
      
      if (Test-Path $artworkFile) {
        Remove-Item $artworkFile
      }
    }
  } finally {
    Pop-Location
  }
}
