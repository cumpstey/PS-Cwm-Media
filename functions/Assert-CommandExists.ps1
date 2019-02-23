function Assert-CommandExists() {
  <#
  .SYNOPSIS
  Asserts whether the given string exists as a command
  .PARAMETER command
  Command to verify
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true, Position = 1)]
    [string]
    $command
  )

  Set-StrictMode -Version 'Latest'
  Use-CallerPreference -Cmdlet $PSCmdlet -Session $ExecutionContext.SessionState

  $exists = !!(Get-Command $command -errorAction SilentlyContinue)
  if ($exists) {
    Write-Debug "Command $command exists"
  } else {
    Write-Debug "Command $command doesn't exist"
  } 
  
  return $exists
}
