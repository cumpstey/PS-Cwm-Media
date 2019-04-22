function Get-TagValue($data, $tag) {
  $found = $data -match "\s${tag}: (.*?)(\r\n|$)"
  if ($found) {
    return $matches[1].Trim()
  }
}

function Get-MultilineTagValue($data, $tag) {
  $found = $data -match "(?s)\s${tag}: (.*?)(\s[a-z\s]+: |$)"
  if ($found) {
    return $matches[1].Trim() -replace "(\r?\n){2}", "`r`n"
  }
}

function Get-Info($mp4box, $path) {
  # Use mp4box to print the metadata, and trim the output to the part containing the metadata.
  $data = (cmd.exe /c "$mp4box -info `"$path`" 2>&1") -join "`r`n"
  if (-not($data -match '(?s)iTunes Info:\r\n(.*)\d UDTA')) {
    Write-Warning "Output of mp4box -info isn't as expected for $path"
    Write-Debug $data
    return
  }

  $tags = $matches[1].TrimEnd()
  
  # Extract the various metadata values.
  return @{
    author = Get-TagValue $tags 'Artist';
    bookInSeries = Get-TagValue $tags 'Album';
    title = Get-TagValue $tags 'Name';
    year = Get-TagValue $tags 'Created';
    description = Get-MultilineTagValue $tags 'Comment';
  }
}

function Export-AudiobookMetadata() {
  <#
  .SYNOPSIS
  Applies metadata defined in external files to an m4b audiobook.
  .PARAMETER bookFile
  File path of the m4b audiobook.
  .PARAMETER metadataDir
  Directory in which the metadata files are stored.
  .PARAMETER mp4box
  Path to the mp4box binary.
  If not specified, assume mp4box is available on the path.
  .EXAMPLE
  Export-AudiobookMetadata 'C:\MyBooks\The Book.m4b' 'C:\Metadata'
  Writes metadata to C:\Metadata\The Book.yaml
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
    [string]
    $mp4box = 'mp4box'
  )

  Set-StrictMode -Version 'Latest'
  Use-CallerPreference -Cmdlet $PSCmdlet -Session $ExecutionContext.SessionState

  if (!(Assert-CommandExists $mp4box)) {
    Write-Error "mp4box not found. This is required to apply the metadata to the m4b file."
    return
  }

  # Assume the name of the book file will be used to identify
  # the book, for the metadata filename.
  $bookId = [IO.Path]::GetFileNameWithoutExtension($bookFile)

  # Ensure output directory exists.
  if (-not(Test-Path $metadataDir)) {
    New-Item -ItemType Directory -Path $metadataDir
  }

  # Extract the raw metadata from the file.
  $info = Get-Info $mp4box $bookFile
  Write-Debug "Raw info:`r`n$($info | Format-Table -AutoSize -Wrap | Out-String)"

  # Start building up the data for the output file.
  $metadata = @{
    'title' = $info.title;
    'author' = $info.author;
    'description' = $info.description;
    'year' = $info.year;
  }

  # Extract narrator from description if present.
  if ($info.description -match '(?m)^Read by (?<narrator>.*)$') {
    $metadata.description = ($info.description -replace $matches[0]).Trim()
    $metadata.narrator = $matches['narrator']
  }

  # Look for a series in a string of format "Discworld 1: The Colour of Magic" and extract series information.
  if ($info.bookInSeries -match '^(?<series>[\w ]+) (?<number>\d+): (?<name>[\w ]+)$') {
    $series = $matches['series']
    $number = [int]$matches['number']
    Write-Debug "Series found: $number of $series"
    
    $metadata.series = $series
    $metadata.seriesNumber = $number
  }

  Write-Debug "Metadata:`r`n$($metadata | Format-Table -AutoSize -Wrap | Out-String)"

  # Serializing doesn't produce quite such human-friendly yaml as writing it manually.
  #$yaml = ConvertTo-YAML $metadata

  # Define field order.
  $keys = @('title', 'author', 'series', 'seriesNumber', 'year', 'narrator', 'description')

  # Write the data to a yaml-formatted string.
  $yaml = (($keys | %{
    $value = $metadata.Item($_) -split "`n" | %{ $_.Trim() }
    if (-not $value) { return }
    
    if (($value | Measure-Object).Count -gt 1) {
      $value = "|`r`n  {0}" -f ($value -join "`r`n  ")
    }
    
    "${_}: $value"
  }) -join "`r`n") + "`r`n"

  # Write yaml to file.
  [IO.File]::WriteAllText((Join-Path $metadataDir "$bookId.yaml"), $yaml, (New-Object System.Text.UTF8Encoding $false))
  Write-Information "Extracted metadata for $($info.title)"
}
