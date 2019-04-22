function Convert-Mp3FolderToAudiobook() {
  <#
  .SYNOPSIS
  Converts a folder containing mp3 files into an m4b audiobook file.
  The mp3 files should be sortable by filename - the ID3 track tags are not read to define the sort order.
  Retains much of the metadata, read from the ID3 tags in the first file.
  .PARAMETER sourceDir
  Directory containing the mp3 files.
  .PARAMETER outDir
  Directory in which to create the m4b file.
  If not specified it will be created in the source directory.
  .PARAMETER cleanup
  Remove temporary files created during the conversion process.
  These are the concatenated audio .aac file, and a text file containing chapter information.
  .PARAMETER ffmpeg
  Path to the ffmpeg binary.
  If not specified, assume ffmpeg is available on the path.
  .PARAMETER mp4box
  Path to the mp4box binary.
  If not specified, assume mp4box is available on the path.
  .EXAMPLE
  ConvertTo-M4b 'C:\MyMp3Books\The Book' 'C:\MyM4bBooks'
  Will create file C:\MyM4bBooks\The Book.m4b
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true, Position=1)]
    [string]
    $sourceDir,
    
    [Parameter()]
    [string]
    $outDir = $sourceDir,
  
    [Parameter()]
    [switch]
    $cleanup = $true,

    [Parameter()]
    [string]
    $ffmpeg = 'ffmpeg',

    [Parameter()]
    [string]
    $ffprobe = 'ffprobe',

    [Parameter()]
    [string]
    $mp4box = 'mp4box'
  )

  Set-StrictMode -Version 'Latest'
  Use-CallerPreference -Cmdlet $PSCmdlet -Session $ExecutionContext.SessionState

  if (!(Assert-CommandExists $ffmpeg)) {
    Write-Error "ffmpeg not found. This is required to convert audio files."
    return
  }

  if (!(Assert-CommandExists $ffprobe)) {
    Write-Error "ffprobe not found. This is required to read metadata from audio files."
    return
  }

  if (!(Assert-CommandExists $mp4box)) {
    Write-Error "mp4box not found. This is required to create the m4b file."
    return
  }

  # Names for temporary files
  $concatenatedFile = 'concatenated.aac'
  $chapterFile = 'chapters.txt'
  $artworkFile = 'artwork.jpg'

  # Assume the name of the book directory will be used to identify
  # the book, for the output filename, etc.
  $bookId = Split-Path $sourceDir -Leaf

  Push-Location

  try {
    cd $sourceDir

    # Get list of mp3 files  
    $files = Get-ChildItem -Path ./ -File -Filter '*.mp3'
    
    # Get metadata from first source file
    $metadata = Get-AudioMetadata $files[0].FullName -ffprobe $ffprobe
    $metadata.name = $metadata.name -replace " \(\d+ of \d+\)$"

    Write-Debug "Metadata:`r`n$($metadata | Format-Table -AutoSize -Wrap | Out-String)"

    # Define output directory
    $outDirectory = $outDir.Replace('{author}', $metadata.artist).
                            Replace('{bookId}', $bookId).
                            Replace('\\', '\')
    Write-Debug "Output directory: $outDirectory"

    # Ensure the output directory exists.
    if (-not(Test-Path $outDirectory)) {
      Write-Information "Creating directory $outDirectory"
      New-Item -ItemType directory -Path $outDirectory
    }

    # Define output file name
    $outFilename = "$bookId.m4b"
    $outFile = Join-Path $outDirectory $outFilename
    
    # Remove any existing mp4 file.
    # TODO: Request confirmation.
    if (Test-Path $outFile) {
      Write-Information "Removing existing file: $outFile"
      Remove-Item $outFile
    }

    # Extract cover art
    & $ffmpeg -i $files[0].FullName -vcodec copy (Join-Path $outDirectory $artworkFile)
    
    # Build list of files to concatenate in ffmpeg
    $filelist = ($files | %{ $_.Name }) -Join '|'

    # Build up chapter file content  
    $position = [timespan]0
    $chapters = ($files | % { $i = 0 }{
      $i++;
      $chapterName = "CHAPTER{0:00}" -f $i
      $chapter = "${chapterName}={0:c}`r`n${chapterName}NAME=Chapter $i" -f $position
      $info = Get-AudioMetadata $_.FullName
      $position += [timespan]$info.duration
      return $chapter
    }) -join "`r`n"

    Write-Debug $filelist
    Write-Debug $chapters
    
    # Write chapter information to file.
    # Have to specify encoding, as PowerShell's default encoding makes it unreadable.
    [IO.File]::WriteAllText((Join-Path $outDirectory $chapterFile), $chapters, (New-Object System.Text.UTF8Encoding $false))
    
    # Combine all individual chapter tracks into one file.
    # TODO: Consider checking for availability of libfdk_aac and using that if available.
    & $ffmpeg -i "concat:$filelist" -c:a aac -b:a 64k (Join-Path $outDirectory $concatenatedFile)

    # Build up tags to apply to new m4b file.
    $tags = "album=""$($metadata.album)"":name=""$($metadata.name)"":artist=""$($metadata.artist)"":created=""$($metadata.year)"":comment=""$($metadata.comment)"":genre=Audiobook"
    if (Test-Path (Join-Path $outDirectory $artworkFile)) {
      $tags += ":cover=""$(Join-Path $outDirectory $artworkFile)"""
    }

    # Write the combined audio file with chapter information to a new mp4 file.
    & $mp4box $outFile `
              -add (Join-Path $outDirectory $concatenatedFile) `
              -itags $tags `
              -chap (Join-Path $outDirectory $chapterFile)

    # Tidy up by removing temporary files.
    if ($cleanup) {
      Write-Debug "Removing temporary files"
      @(
        (Join-Path $outDirectory $concatenatedFile),
        (Join-Path $outDirectory $chapterFile),
        (Join-Path $outDirectory $artworkFile)
      ) | ?{ Test-Path $_ } | %{ Remove-Item $_ }
    }
  } finally {
    Pop-Location
  }
}
