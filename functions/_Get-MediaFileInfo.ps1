function Get-MediaFileInfo () {
  <#
  .SYNOPSIS
  Converts a set of mp3 files into an m4b audiobook file.
  The mp3 files should be sortable by filename - the track ID3 tags are not read.
  .PARAMETER path
  Path to media file.
  .EXAMPLE
  Get-MediaFileInfo 'C:\MyMedia\MyFile.mp3'
  Returns: @{
    artist: 'The Artist'
    album: 'The Album'
    name: 'The First Track'
    year: 2019
    duration: '01:23:45'
  }
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true, Position=1)]
    [string]
    $path
  )

  Set-StrictMode -Version 'Latest'
  Use-CallerPreference -Cmdlet $PSCmdlet -Session $ExecutionContext.SessionState

  $shell = New-Object -COMObject Shell.Application
  $folder = Split-Path $path
  $file = Split-Path $path -Leaf
  $shellfolder = $shell.Namespace($folder)
  $shellfile = $shellfolder.ParseName($file)
  
  0..287 | Foreach-Object {
    $val = $shellfolder.GetDetailsOf($shellfile, $_)
    if ($val) {
      Write-Output ('{0} = {1}' -f $_, $val)
    }
  } | Out-Null

  return @{
    'artist' = $shellfolder.GetDetailsOf($shellfile, 13);
    'album' = $shellfolder.GetDetailsOf($shellfile, 14);
    'year' = $shellfolder.GetDetailsOf($shellfile, 15);
    'name' = $shellfolder.GetDetailsOf($shellfile, 21);
    'comment' = $shellfolder.GetDetailsOf($shellfile, 24);
    'duration' = $shellfolder.GetDetailsOf($shellfile, 27);
  }
}
