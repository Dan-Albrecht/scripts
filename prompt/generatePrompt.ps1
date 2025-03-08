<#
.SYNOPSIS
Prints a command line to start everything.
#>
$runningExe = (Get-Process -Id $PID).Path
$repoName = (New-Object System.IO.DirectoryInfo($PWD)).Name
$gitOutput = git rev-parse --show-toplevel 2>$null
$currentRepo = $PWD

if (![string]::IsNullOrWhiteSpace($gitOutput)) {
    $currentRepo = [System.IO.Path]::GetFullPath($gitOutput)
}

$startPromptPath = Join-Path -Path $PSScriptRoot -ChildPath 'startPrompt.ps1'
$result = "$runningExe -Interactive -NoLogo -Command $startPromptPath -repoPath $currentRepo -repoName $repoName"

Write-Host "Basic version:"
Write-Host $result

Write-Host "With 2nd stage:"
$result += ' -stage2Script someOtherScript.ps1'
Write-Host $result

if ($currentRepo -ne $PWD) {
    Write-Host "With alternate root:"
    $result += " -rootPath $PWD"
    Write-Host $result
}
