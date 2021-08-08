<#
.SYNOPSIS
Starts a developer prompt centered on a repo.

.PARAMETER repoPath
Full path of the repo.

.PARAMETER repoName
Friendly name to refer to the repo as.

.PARAMETER relaunchMeExitCode
Exit code to use if this script wants to be relaunched.
#>

param (
    [Parameter(Mandatory = $true)][string]$repoPath, 
    [Parameter(Mandatory = $true)][string]$repoName,
    [Parameter(Mandatory = $false)][int]$relaunchMeExitCode = 0)

$ErrorActionPreference = "Stop"
$vsWherePath = "C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe"

. $PSScriptRoot\customTypes.ps1
. $PSScriptRoot\functions.ps1
$global:PromptSettings = [PromptSettings]::new()

if (Test-Path -Path $vsWherePath) {
    Write-Host "Getting VS install path..." -NoNewline
    . TimeCommand { $vsInstallPath = & $vsWherePath -prerelease -latest -property installationPath }
    Write-Host "Getting VS display name..." -NoNewline
    . TimeCommand { $vsToolsDisplayName = & $vsWherePath -prerelease -latest -property catalog_productDisplayVersion }
    Write-Host "Loading VS module..." -NoNewline
    . TimeCommand { Import-Module (Get-ChildItem $vsInstallPath -Recurse -File -Filter Microsoft.VisualStudio.DevShell.dll).FullName }
    Write-Host "Loading dev shell..." -NoNewline
    . TimeCommand { Enter-VsDevShell -VsInstallPath $vsInstallPath -DevCmdArguments '-arch=x64' | Out-Null }
    Write-Host "Tools version: $vsToolsDisplayName"
}
else {
    Write-Warning "VS was not found so you're not gonna have (m)any build tools"
}

# Stop PowerShell from camping on exes we care about
Remove-Alias -Name kill -Force -ErrorAction Ignore
Remove-Alias -Name where -Force -ErrorAction Ignore

# Some scoping thing that I don't undertand that forces me to clear out here instead of automatically like all other CreateDynamicAlias calls...
Remove-Alias -Name dir -Force -ErrorAction Ignore

Set-Alias -Name alias -Value "Get-AliasEx" -Scope Global

CreateDynamicAlias -name ".." -action "Set-Location -Path .."
CreateDynamicAlias -name "..." -action "Set-Location -Path ..\.."
CreateDynamicAlias -name "...." -action "Set-Location -Path ..\..\.."
CreateDynamicAlias -name "....." -action "Set-Location -Path ..\..\..\.."
CreateDynamicAlias -name "cr" -action "cargo run"
CreateDynamicAlias -name "dir" -action "cmd /c dir" -allowArgs
CreateDynamicAlias -name "fm" -action 'Invoke-FetchPull -fetchOnly $true -targetBranch Default'
CreateDynamicAlias -name "fu" -action 'Invoke-FetchPull -fetchOnly $true -targetBranch Upstream'
CreateDynamicAlias -name "gs" -action "git status"
CreateDynamicAlias -name "mp" -action "$PSScriptRoot\generatePrompt.ps1"
CreateDynamicAlias -name "n" -action "notepad.exe `$args"
CreateDynamicAlias -name "nt" -action "Set-Location -Path '$repoPath'"
CreateDynamicAlias -name "nt2" -action "Set-Location -Path '$PSScriptRoot'"
CreateDynamicAlias -name "pm" -action 'Invoke-FetchPull -fetchOnly $false -targetBranch Default'
CreateDynamicAlias -name "pu" -action 'Invoke-FetchPull -fetchOnly $false -targetBranch Upstream'
CreateDynamicAlias -name "re" -action "exit $relaunchMeExitCode"
CreateDynamicAlias -name "rs" -action "code $settingsFile"
CreateDynamicAlias -name "spy64" -action "spyxx_amd64.exe"

Set-Location -Path $repoPath
$Host.UI.RawUI.WindowTitle = $repoName

# v3 is painfully slow compared to v2
# Import-ModuleEx -name "oh-my-posh" -version "3.165.0"
# Set-PoshPrompt -Theme $PSScriptRoot\ohMyPosh.json

# We could just use v2, but we don't really even need that fanciness. Just to it by hand.
Import-ModuleEx -name "posh-git" -version "1.0.0"

$env:RUST_BACKTRACE = 1

# BUGBUG: Figure out how to detect if we're actually currently rendering with this, not just installed
Test-Font -name "Caskaydia Cove Nerd Font Complete Windows Compatible (TrueType)" -remediationInfo "Download 'Caskaydia Cove Nerd Font' from: https://www.nerdfonts.com/font-downloads and install 'Caskaydia Cove Nerd Font Complete Windows Compatible.ttf' and set terminal font face to 'CaskaydiaCove NF.'"
