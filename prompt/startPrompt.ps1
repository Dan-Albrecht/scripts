<#
.SYNOPSIS
Starts a developer prompt as a child process with the ability to reload it clean.

.PARAMETER repoPath
Full path of the repo.

.PARAMETER repoName
Friendly name to refer to the repo as.
#>

param (
    [Parameter(Mandatory = $true)][string]$repoPath, 
    [Parameter(Mandatory = $true)][string]$repoName)

$ErrorActionPreference = 'Stop'

if (!(Test-Path -Path $repoPath)) {
    Write-Error "'$repoPath' does not exist"
}

# Too many versions and paths and names, just reuse whatever we are
$powerShellPath = (Get-Process -Id $PID).Path
Write-Host "We'll be using $powerShellPath for our child shell"

$magicExitCode = 27
$scriptArgs = @('-NoExit', '-NoLogo', '-Interactive', '-File', "$PSScriptRoot\promptInit.ps1", '-repoPath', $repoPath, '-repoName', $repoName, '-relaunchMeExitCode', $magicExitCode)
$loop = $false

do {
    # Kick this off in a child process so if we make any environment changes we want to undo we can just
    # exit with a magic code and get reinvoked clean without have to relaunch the console.
    $process = Start-Process -PassThru -NoNewWindow -FilePath $powerShellPath -ArgumentList $scriptArgs

    # Can't directly use -Wait as that'll wait for all children
    # Can't directly use .WaitForExit() as it doesn't work by default
    # So do some quirky hack
    # https://stackoverflow.com/a/23797762
    $process.Handle | Out-Null    
    $process.WaitForExit()
    $exitCode = $process.ExitCode
    $loop = $exitCode -eq $magicExitCode

    Write-Host "Child process exited with $exitCode. Reinvoke: $loop."

} while ($loop)
