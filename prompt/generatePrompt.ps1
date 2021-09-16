<#
.SYNOPSIS
Prints a command line to start everything.
#>
$runningExe = (Get-Process -Id $PID).Path
$repoName = (New-Object System.IO.DirectoryInfo($PWD)).Name
$result = "$runningExe -Interactive -NoLogo -Command $PSScriptRoot\startPrompt.ps1 -repoPath $PWD -repoName $repoName"
$result = $result.Replace('\', '\\')

Write-Host "Basic version:"
Write-Host $result

Write-Host "With 2nd stage:"
$result += ' -stage2Script someOtherScript.ps1'
Write-Host $result
