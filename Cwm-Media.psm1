# Dot source all the functions files, so they can be imported.

$doNotImport = @{ }

$functionRoot = Join-Path -Path $PSScriptRoot -ChildPath 'functions' -Resolve

Get-ChildItem -Path $functionRoot -Filter '*.ps1' | 
  Where-Object { -not $doNotImport.Contains($_.Name) } |
  ForEach-Object {
    Write-Verbose ("Importing function {0}." -f $_.FullName)
    . $_.FullName | Out-Null
  }

