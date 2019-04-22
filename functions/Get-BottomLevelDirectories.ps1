function Get-BottomLevelDirectories () {
  <#
  .SYNOPSIS
  Gets only the bottom-level directories from a directory tree.
  .PARAMETER path
  Path to the root directory.
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true, Position=1)]
    [string]
    $path
  )

  Set-StrictMode -Version 'Latest'
  Use-CallerPreference -Cmdlet $PSCmdlet -Session $ExecutionContext.SessionState

  return (Get-ChildItem -Path $path -Recurse -Directory) | ?{ @($_.EnumerateDirectories()).Count -eq 0 }
}
