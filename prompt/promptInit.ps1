<#
.SYNOPSIS
Starts a developer prompt centered on a repo.

.PARAMETER repoPath
Full path of the repo.

.PARAMETER repoName
Friendly name to refer to the repo as.

.PARAMETER relaunchMeExitCode
Exit code to use if this script wants to be relaunched.

.PARAMETER stage2Script
Full path to an optional second stage script to run after all other init complete.
#>

param (
    [Parameter(Mandatory = $true)][string]$repoPath, 
    [Parameter(Mandatory = $true)][string]$repoName,
    [Parameter(Mandatory = $false)][int]$relaunchMeExitCode = 0,
    [Parameter(Mandatory = $false)][string]$stage2Script)

$ErrorActionPreference = 'Stop'

# Set this immeidately with the builtin syntax incase we have any errors
# We'll override with our style if we make it that far in init
function RelaunchMe { exit $relaunchMeExitCode }
Set-Alias -Name 're' -Value 'RelaunchMe'

$vsWherePath = 'C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe'

. $PSScriptRoot\customTypes.ps1
. $PSScriptRoot\functions.ps1
$global:PromptSettings = [PromptSettings]::new()

if (Test-Path -Path $vsWherePath) {
    Write-Host 'Getting VS install path...' -NoNewline
    . TimeCommand { 
        [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', 'I am')]
        $vsInstallPath = & $vsWherePath -prerelease -latest -all -property installationPath 
    }
    if ($null -eq $vsInstallPath) {
        Write-Host 'VSWhere is screwed up again'
    }
    else {
        Write-Host 'Getting VS display name...' -NoNewline
        . TimeCommand { 
            [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', 'I am')]
            $vsToolsDisplayName = & $vsWherePath -prerelease -latest -all -property catalog_productDisplayVersion 
        }

        Write-Host 'Find VS module...' -NoNewline
        . TimeCommand {
            [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', 'I am')]
            $vsModule = (Get-ChildItem $vsInstallPath -Recurse -File -Filter Microsoft.VisualStudio.DevShell.dll).FullName
        }

        if ($null -eq $vsModule) {
            Write-Host 'VS module not found'
        }
        else {
            Write-Host 'Loading it...' -NoNewline
            . TimeCommand { Import-Module $vsModule }
            Write-Host 'Loading dev shell...' -NoNewline
            . TimeCommand { Enter-VsDevShell -VsInstallPath $vsInstallPath -DevCmdArguments '-arch=x64' | Out-Null }
            Write-Host "Tools version: $vsToolsDisplayName"
        }
    }
}
else {
    Write-Warning "VS was not found so you're not gonna have (m)any build tools"
}

# Stop PowerShell from camping on exes we care about
Remove-Alias -Name kill -Force -ErrorAction Ignore
Remove-Alias -Name where -Force -ErrorAction Ignore

# Some scoping thing that I don't undertand that forces me to clear out here instead of automatically like all other CreateDynamicAlias calls...
Remove-Alias -Name dir -Force -ErrorAction Ignore

Set-Alias -Name alias -Value 'Get-AliasEx' -Scope Global

CreateDynamicAlias -name '..' -action 'Set-Location -Path ..'
CreateDynamicAlias -name '...' -action 'Set-Location -Path ..\..'
CreateDynamicAlias -name '....' -action 'Set-Location -Path ..\..\..'
CreateDynamicAlias -name '.....' -action 'Set-Location -Path ..\..\..\..'
CreateDynamicAlias -name 'cr' -action 'cargo run'
CreateDynamicAlias -name 'dir' -action 'cmd /c dir' -allowArgs
CreateDynamicAlias -name 'fm' -action 'Invoke-FetchPull -fetchOnly $true -targetBranch Default'
CreateDynamicAlias -name 'fu' -action 'Invoke-FetchPull -fetchOnly $true -targetBranch Upstream'
CreateDynamicAlias -name 'gs' -action 'git status'
CreateDynamicAlias -name 'mp' -action "$PSScriptRoot\generatePrompt.ps1"
CreateDynamicAlias -name 'n' -action "notepad.exe `$args"
CreateDynamicAlias -name 'nt' -action "Set-Location -Path '$repoPath'"
CreateDynamicAlias -name 'nt2' -action "Set-Location -Path '$PSScriptRoot'"
CreateDynamicAlias -name 'pm' -action 'Invoke-FetchPull -fetchOnly $false -targetBranch Default'
CreateDynamicAlias -name 'pu' -action 'Invoke-FetchPull -fetchOnly $false -targetBranch Upstream'
CreateDynamicAlias -name 'push' -action "Invoke-GitPush `$args[0]"
CreateDynamicAlias -name 're' -action "exit $relaunchMeExitCode"
# We made it this far so clean up our temp function
Remove-Item -Path Function:\RelaunchMe
CreateDynamicAlias -name 'rs' -action "code $($PromptSettings.SettingsFile)"
CreateDynamicAlias -name 'spy64' -action 'spyxx_amd64.exe'
CreateDynamicAlias -name 'title' -action "`$Host.UI.RawUI.WindowTitle = `$args"

Set-Location -Path $repoPath
$Host.UI.RawUI.WindowTitle = $repoName

Import-ModuleEx -name 'posh-git' -version '1.0.0'

$env:RUST_BACKTRACE = 1

# BUGBUG: Figure out how to detect if we're actually currently rendering with this, not just installed
Test-Font -name 'Caskaydia Cove Nerd Font Complete Windows Compatible (TrueType)' -remediationInfo "Download 'Caskaydia Cove Nerd Font' from: https://www.nerdfonts.com/font-downloads and install 'Caskaydia Cove Nerd Font Complete Windows Compatible.ttf' and set terminal font face to 'CaskaydiaCove NF.'"

if (![string]::IsNullOrWhiteSpace($stage2Script)) {
    if (Test-Path -Path $stage2Script) {
        Write-Host "Chaining to $stage2Script..."
        . $stage2Script
    }
    else {
        Write-Error "Stage2 script $stage2Script doesn't exist"
    }
}

if (!(Test-SearchPath -search "kill")) {
    Write-Warning "Kill command not found; update your path"
}

Invoke-CheckPowerShell
