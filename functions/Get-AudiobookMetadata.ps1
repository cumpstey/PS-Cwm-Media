function Get-AudiobookMetadata () {
  <#
  .SYNOPSIS
  Reads metadata for an audiobook from an external file.
  .PARAMETER dir
  Path to directory containing metadata.
  .PARAMETER book
  Name of the book.
  .EXAMPLE
  Get-Metadata 'C:\Metadata' 'The Book'
  Returns: System.Collections.Specialized.OrderedDictionary {
    title: 'The Book'
    author: 'The Author'
    series: 'The Series'
    seriesNumber: 1
    year: 2019
    description: 'The long, possibly multiline, description.'
    language: 'en'
    image: C:\Images\The Book.jpg
  }
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true, Position=1)]
    [string]
    $dir,

    [Parameter(Mandatory=$true, Position=2)]
    [string]
    $bookName
  )

  Set-StrictMode -Version 'Latest'
  Use-CallerPreference -Cmdlet $PSCmdlet -Session $ExecutionContext.SessionState

  Import-Module PSYaml

  # Find metadata file. Allow finding a match when the series id isn't known.
  $metadataFiles = Get-ChildItem -Path $dir -File -Filter "*$bookName.yaml" -Recurse
  Write-Debug "Metadata files found in $dir for ${bookName}:`n$metadataFiles"

  # Warn if metadata file not found or if multiple matches.
  $metadataCount = ($metadataFiles | Measure-Object).Count
  if ($metadataCount -eq 0) {
    Write-Warning "No metadata file found for $bookName"
    return
  } elseif ($metadataCount -gt 1) {   
    $fileNames = ($metadataFiles | %{ $_.BaseName }) -join '; '
    Write-Warning "Multiple metadata file matches found for ${bookName}: $fileNames"
    return
  }

  # Image name will match metadata file name.
  $bookId = $metadataFiles.BaseName

  # Parse file content.
  $yaml = [IO.File]::ReadAllText($metadataFiles.FullName)
  $data = ConvertFrom-YAML($yaml)

  # Replace linebreaks, as the yaml library doesn't seem to use the right ones.
  if ($data.Contains('description')) {
    $data.description = $data.description -replace "`r?`n", "`r`n"
  }

  # Default to English if no language specified.
  if (-not($data.Contains('language'))) {
    $data.language = 'en'
  }

  # Find image file.
  $imageFiles = Get-ChildItem -Path $dir -File -Filter "$bookId.jpg" -Recurse
  Write-Debug "Image files found in $dir for ${bookId}:`n$imageFiles"

  # Warn if image file not found or if multiple matches.
  # Otherwise add file path to data.
  $imageCount = ($imageFiles | Measure-Object).Count
  if ($imageCount -eq 0) {
    Write-Warning "No image file found for $bookId"
  } elseif ($imageCount -gt 1) {
    $fileNames = ($imageFiles | %{ $_.BaseName }) -join '; '
    Write-Warning "Multiple image file matches found for ${bookId}: $fileNames"
  } else {
    $data.image = $imageFiles.FullName
  }

  return $data
}
