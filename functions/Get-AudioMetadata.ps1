function Get-TagValue($data, $tag) {
  $found = $data -match "(?m)^\s+${tag}\s*: (?<value>.*?)$"
  if ($found) {
    return $matches['value'].Trim()
  }
}

function Get-MultilineTagValue($data, $tag) {
  $lines = $data -split "\r?\n"
  $found = $false
  $value = New-Object System.Collections.Generic.List[System.String]
  foreach ($line in $lines) {
    if (-not $found) {
      $matching = $line -match "^\s+${tag}\s*:\s(?<value>.*)$"
      if ($matching) {
        $found = $true
        $value.Add($matches['value'].Trim())
      }
    } else {
      $matching = $line -match "^\s+:\s(?<value>.*)$"
      if ($matching) {
        $value.Add($matches['value'].Trim())
      } else {
        break
      }
    }
  }

  return ($value -join "`r`n").Trim()
}

function Get-AudioMetadata() {
  <#
  .SYNOPSIS
  Applies metadata defined in external files to an m4b audiobook.
  .PARAMETER file
  File path of the audio file.
  .PARAMETER ffprobe
  Path to the ffprobe binary.
  If not specified, assume ffprobe is available on the path.
  .EXAMPLE
  Get-AudioMetadata 'C:\MyBooks\The Book.m4b'
  Returns: @{
    artist: The Artist
    album: The Album
    name: The First Track
    track: 1
    year: 2019
    genre: Rock
    comment: This is a comment`r`nwhich can be over multiple lines
    duration: 01:23:45
  }
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true, Position=1)]
    [string]
    $file,

    [Parameter()]
    [string]
    $ffprobe = 'ffprobe'
  )

  Set-StrictMode -Version 'Latest'
  Use-CallerPreference -Cmdlet $PSCmdlet -Session $ExecutionContext.SessionState

  if (!(Assert-CommandExists $ffprobe)) {
    Write-Error "ffprobe not found. This is required to read the metadata from the audio file."
    return
  }

  # Use ffprobe to print the metadata.
  $data = (cmd.exe /c "$ffprobe `"$file`" 2>&1") -join "`r`n"

  # Trim the output to the part containing the metadata.
  if (-not($data -match '(?s)\r\nInput #0, .*?\r\n\s+Metadata:\r\n(?<tags>.*)\r\n\s+Duration: (?<duration>[\d:\.]+),')) {
    Write-Warning "Output of ffprobe -info isn't as expected for $path"
    Write-Debug $data
    return
  }

  $tags = $matches['tags']
  $duration = $matches['duration']

  # Extract the various metadata values.
  return @{
    artist = Get-TagValue $tags 'artist'
    album = Get-TagValue $tags 'album'
    name = Get-TagValue $tags 'title'
    track = Get-TagValue $tags 'track'
    year = Get-TagValue $tags 'date'
    genre = Get-TagValue $tags 'genre'
    comment = Get-MultilineTagValue $tags 'comment'
    duration = $duration
  }
}
