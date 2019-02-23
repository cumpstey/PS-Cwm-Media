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
  }
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true, Position = 1)]
    [string]
    $dir,

    [Parameter(Mandatory=$true, Position = 2)]
    [string]
    $book
  )

  Set-StrictMode -Version 'Latest'
  Use-CallerPreference -Cmdlet $PSCmdlet -Session $ExecutionContext.SessionState

  Import-Module PSYaml

  # Find metadata file.
  $files = Get-ChildItem -Path $dir -File -Filter "$book.yaml" -Recurse
  Write-Debug "Metadata files found in $dir for ${book}:`n$files"

  # Warn if metadata file not found or if multiple matches.
  $fileCount = ($files | Measure-Object).Count
  if ($fileCount = 0) {
    Write-Warning "No metadata file found for $book"
    return
  } elseif ($fileCount > 1) {
    $fileNames = ($files | %{ $_.BaseName }) -join '; '
    Write-Warning "Multiple metadata file matches found for ${book}: $fileNames"
    return
  }

  # Parse file content.
  $yaml = [IO.File]::ReadAllText($files.FullName)
  $data = ConvertFrom-YAML($yaml)

  return $data
}
