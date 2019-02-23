function ConvertTo-M4b() {
  <#
  .SYNOPSIS
  Converts a set of mp3 files into an m4b audiobook file.
  The mp3 files should be sortable by filename - the track ID3 tags are not read.
  .PARAMETER sourceDir
  Directory containing the mp3 files.
  .PARAMETER outDir
  Directory in which to create the m4b file.
  If not specified it will be created in the source directory.
  .PARAMETER metadataDir
  Directory in which the metadata files are stored.
  .PARAMETER cleanup
  Remove temporary files created during the conversion process.
  These are the concatenated audio .aac file, and a text file containing chapter information.
  .PARAMETER ffmpeg
  Path to the ffmpeg binary.
  If not specified, assumed ffmpeg is available on the path.
  .PARAMETER mp4box
  Path to the mp4box binary.
  If not specified, assumed mp4box is available on the path.
  .EXAMPLE
  ConvertTo-M4b 'C:\MyMp3Books\The Book' 'C:\MyM4bBooks'
  Will create file C:\MyM4bBooks\The Book.m4b
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true, Position = 1)]
    [string]
    $sourceDir,
    
    [Parameter()]
    [string]
    $outDir = $sourceDir,
  
    [Parameter()]
    [string]
    $metadataDir,
    
    [Parameter()]
    [switch]
    $cleanup = $true,

    [Parameter()]
    [string]
    $ffmpeg = 'ffmpeg',
    #$ffmpeg = 'D:\Software\ffmpeg\bin\ffmpeg.exe'

    [Parameter()]
    [string]
    $mp4box = 'mp4box'
  )

  Set-StrictMode -Version 'Latest'
  Use-CallerPreference -Cmdlet $PSCmdlet -Session $ExecutionContext.SessionState

  if (!(Assert-CommandExists $ffmpeg)) {
    Write-Error "ffmpeg not found - can't convert audio files."
    return
  }

  if (!(Assert-CommandExists $mp4box)) {
    Write-Error "mp4box not found - can't create m4b file."
    return
  }

  # Names for temporary files
  $concatenatedFile = 'concatenated.aac'
  $chapterFile = 'chapters.txt'

  # Ensure output directory exists
  if (!(Test-Path $outDir)) {
    New-Item -ItemType directory -Path $outDir
  }

  # Assume the name of the book directory will be used to identify
  # the book, for the output filename, metadata etc.
  $bookId = Split-Path $sourceDir -Leaf

  Push-Location

  try {
    cd $sourceDir

    # Get list of mp3 files  
    $files = Get-ChildItem -Path ./ -File -Filter '*.mp3'
    
    # Get metadata
    $metadata = Get-AudiobookMetadata $metadataDir $bookId
    if (-not($metadata)) {
      # If no metadata found, get from first source file
      $track1Info = Get-MediaFileInfo $files[1].FullName
      $metadata = @{
        'author' = $track1Info.artist;
        'book' = $track1Info.album;
        'year' = $track1Info.year;
      }
    }

    if ($metadata.series -and $metadata.seriesNumber) {
      $metadata.bookInSeries = "{0} {1}: {2}" -f $metadata.series, $metadata.seriesNumber, $metadata.title
    }

    Write-Debug "Title: $($metadata.title)"
    Write-Debug "Author: $($metadata.author)"
    Write-Debug "Book in series: $($metadata.bookInSeries)"
    Write-Debug "Year: $($metadata.year)"

    # Build list of files to concatenate in ffmpeg
    $filelist = ($files | %{ $_.Name }) -Join '|'

    # Build up chapter file content  
    $position = [timespan]0
    $chapters = ($files | % { $i = 0 }{
      $i++;
      $chapterName = "CHAPTER{0:00}" -f $i
      $chapter = "${chapterName}={0:c}`r`n${chapterName}NAME=Chapter $i" -f $position
      $info = Get-Info $_.FullName
      $position += [timespan]$info.duration
      return $chapter
    }) -join "`r`n"

    Write-Debug $filelist
    Write-Debug $chapters
    
    # Write chapter information to file.
    # Have to specify encoding, as PowerShell's default encoding makes it unreadable.
    [IO.File]::WriteAllText((Join-Path $sourceDir $chapterFile), $chapters, (New-Object System.Text.UTF8Encoding $false))
    
    # Combine all individual chapter tracks into one file.
    # TODO: Consider checking for availability of libfdk_aac and using that if available.
    & $ffmpeg -i "concat:$filelist" -c:a aac -b:a 64k $concatenatedFile

    $outFilename = "{0}.m4b" -f $bookId
    $outFile = Join-Path $outDir $outFilename
    
    # Remove any existing mp4 file.
    # TODO: Request confirmation.
    if (Test-Path $outFile) {
      Write-Information "Removing existing file: $outFile"
      Remove-Item $outFile
    }

    # Write the combined audio file with chapter information to a new mp4 file.
    & $mp4box -add $concatenatedFile $outFile -lang en -itags album="$($metadata.bookInSeries)":name="$($metadata.title)":artist="$($metadata.author)":created="$($metadata.year)":genre=Audiobook -chap $chapterFile

    if ($cleanup) {
      Write-Debug "Removing temporary files: $concatenatedFile; $chapterFile"
      Remove-Item $concatenatedFile
      Remove-Item $chapterFile
    }
  } finally {
    Pop-Location
  }
}
