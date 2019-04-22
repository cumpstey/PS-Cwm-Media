# Dot source all the functions files, so they can be imported.

$doNotImport = @{ }

$functionRoot = Join-Path -Path $PSScriptRoot -ChildPath 'functions' -Resolve

Get-ChildItem -Path $functionRoot -Filter '*.ps1' | 
  Where-Object { -not $doNotImport.Contains($_.Name) } |
  ForEach-Object {
    Write-Verbose ("Importing function {0}." -f $_.FullName)
    . $_.FullName | Out-Null
  }

if (!(Assert-CommandExists 'ffmpeg')) {
  Write-Warning 'Some functions require ffmpeg, but this was not found on the path. The path to the executable can be manually specified as a parameter on any function which requires it.'
}

if (!(Assert-CommandExists 'magick')) {
  Write-Warning 'Some functions require magick, but this was not found on the path. The path to the executable can be manually specified as a parameter on any function which requires it.'
}

if (!(Assert-CommandExists 'mp4box')) {
  Write-Warning 'Some functions require mp4box, but this was not found on the path. The path to the executable can be manually specified as a parameter on any function which requires it.'
}
