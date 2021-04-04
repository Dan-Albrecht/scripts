<#
.SYNOPSIS
Prints a command line to start everything.
#>
$runningExe = (Get-Process -Id $PID).Path
$result = "$runningExe -Interactive -NoLogo -Command $PSScriptRoot\startPrompt.ps1 -repoPath __REPLACE_ME__"
$result = $result.Replace("\", "\\")
Write-Host $result
