<#
.SYNOPSIS
Prints a command line to start everything.
#>
$runningExe = (Get-Process -Id $PID).Path
$repoName = (New-Object System.IO.DirectoryInfo($PWD)).Name
$result = "$runningExe -Interactive -NoLogo -Command $PSScriptRoot\startPrompt.ps1 -repoPath $PWD -repoName $repoName"
$result = $result.Replace("\", "\\")
Write-Host $result
