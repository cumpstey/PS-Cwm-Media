function Assert-PropertyExists() {
  <#
  .SYNOPSIS
  Asserts whether the given object has a property of the given name.
  .PARAMETER object
  Object
  .PARAMETER propertyName
  Name of the property which should be checked for existence
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true, Position=1)]
    [string]
    $object,

    [Parameter(Mandatory=$true, Position=2)]
    [string]
    $propertyName
  )

  Set-StrictMode -Version 'Latest'
  Use-CallerPreference -Cmdlet $PSCmdlet -Session $ExecutionContext.SessionState

  return Get-Member -InputObject $object -Name $propertyName -Membertype Properties
}
