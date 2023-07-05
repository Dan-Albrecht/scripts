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
    [Parameter(Mandatory = $true)][string]$repoPath 
    , [Parameter(Mandatory = $true)][string]$repoName
    , [Parameter(Mandatory = $false)][int]$relaunchMeExitCode = 0
    , [Parameter(Mandatory = $false)][string]$stage2Script
    , [Parameter(Mandatory = $false)][string]$rootPath
)

$ErrorActionPreference = 'Stop'

# Set this immeidately with the builtin syntax incase we have any errors
# We'll override with our style if we make it that far in init
function RelaunchMe { exit $relaunchMeExitCode }
Set-Alias -Name 're' -Value 'RelaunchMe'

if ([string]::IsNullOrWhiteSpace($rootPath)) {
    $rootPath = $repoPath
}

$vsWherePath = 'C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe'

. $PSScriptRoot\customTypes.ps1
. $PSScriptRoot\functions.ps1
$global:PromptSettings = [PromptSettings]::new("$repoPath\..\repoSettings.json")

# https://github.com/PowerShell/PowerShell/issues/1908#issuecomment-1577142452
# https://github.com/PowerShell/PowerShell/pull/17857
# https://github.com/PowerShell/PowerShell/commit/2424ad83aa4d44fe9e8f507485744e00c66cde58
if ($null -eq (Get-ExperimentalFeature -Name PSNativeCommandPreserveBytePipe).Enabled) {
    Write-WarningEx -message 'PSNativeCommandPreserveBytePipe feature does not appear to exist. Update to the latest preview to get proper pipelines.' -showStack $false
}
elseif ($false -eq (Get-ExperimentalFeature -Name PSNativeCommandPreserveBytePipe).Enabled) {
    Write-WarningEx -message 'PSNativeCommandPreserveBytePipe is set to false...' -showStack $false
}

# Don't want all the crap PowerShell would normally print out
# $ErrorView = 'ConciseView' doesn't apply to scripts so have to do a customer formatter
Update-FormatData -PrependPath $PSScriptRoot\betterErrors.Format.ps1xml

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
CreateDynamicAlias -name 'db' -action "dotnet build `$args[0] --no-restore --configuration Debug -p:Platform=x64"
CreateDynamicAlias -name 'dr' -action "dotnet restore `$args[0] --interactive"
CreateDynamicAlias -name 'dir' -action 'cmd /c dir' -allowArgs
CreateDynamicAlias -name 'fm' -action 'Invoke-FetchPull -fetchOnly $true -targetBranch Default'
CreateDynamicAlias -name 'fu' -action 'Invoke-FetchPull -fetchOnly $true -targetBranch Upstream'
CreateDynamicAlias -name 'gs' -action 'git status'
CreateDynamicAlias -name 'kill' -action 'Stop-ProcessExWrapper' -allowArgs
CreateDynamicAlias -name 'mp' -action "$PSScriptRoot\generatePrompt.ps1"
CreateDynamicAlias -name 'n' -action "notepad.exe `$args"
CreateDynamicAlias -name 'nt' -action "Set-Location -Path '$rootPath'"
CreateDynamicAlias -name 'nt2' -action "Set-Location -Path '$PSScriptRoot'"
CreateDynamicAlias -name 'pm' -action 'Invoke-FetchPull -fetchOnly $false -targetBranch Default'
CreateDynamicAlias -name 'pu' -action 'Invoke-FetchPull -fetchOnly $false -targetBranch Upstream'
CreateDynamicAlias -name 'push' -action "Invoke-GitPush `$args[0]"
CreateDynamicAlias -name 'rb' -action "Invoke-Rebase"
CreateDynamicAlias -name 're' -action "exit $relaunchMeExitCode"
CreateDynamicAlias -name 're2' -action ". $PSScriptRoot\customTypes.ps1; . $PSScriptRoot\functions.ps1"
# We made it this far so clean up our temp function
Remove-Item -Path Function:\RelaunchMe
CreateDynamicAlias -name 'rs' -action "code $($PromptSettings.SettingsFile)"
CreateDynamicAlias -name 'sq' -action "Invoke-Squash"
CreateDynamicAlias -name 'spy64' -action 'spyxx_amd64.exe'
CreateDynamicAlias -name 'title' -action "`$Host.UI.RawUI.WindowTitle = `$args"

if ($IsLinux) {
    CreateDynamicAlias -name 'where' -action "which `$args"
}

Set-Location -Path $rootPath
$Host.UI.RawUI.WindowTitle = $repoName

Import-ModuleEx -name 'posh-git' -version '1.1.0'
Import-ModuleEx -name 'PSReadLine' -version '2.2.6'

$env:RUST_BACKTRACE = 1

if ($IsWindows) {
    # BUGBUG: We want to check the terminal, not the OS we're actually running on
    # BUGBUG: Figure out how to detect if we're actually currently rendering with this, not just installed
    Test-Font -name 'CaskaydiaCove NF Regular (TrueType)' -remediationInfo "Download 'Caskaydia Cove Nerd Font' from: https://www.nerdfonts.com/font-downloads and install 'CaskaydiaCoveNerdFont-Regular.ttf' and set terminal font face to 'CaskaydiaCove Nerd Font.'"
}

if ($IsLinux) {
    # $env:GIT_TRACE = 1

    # This is needed to get GPG to properly prompt for signing passphrase
    $env:GPG_TTY = tty

    $ExecutionContext.InvokeCommand.CommandNotFoundAction =
    {
        param(
            [string]
            $commandName,
    
            [System.Management.Automation.CommandLookupEventArgs]
            $commandArgs
        )

        # For a reason I haven't bothered to lookup yet, PowerShell seems to search twice for commands:
        # the first time is with a "get-" prefix and the second time is just the actual command.
        # Just hook the first one and if something has changed print a warning.
        if ($commandName -ne $null -and $commandName.StartsWith('get-')) {
            $commandName = $commandName.Substring(4)

            # This seems to have no impact (and most examples say as such too), but if it ever gets fixed one day, be ready...
            $commandArgs.StopSearch = $false
            $commandArgs.CommandScriptBlock = {

                # This is the thing that gives the suggestions about what potential package to install via apt to resolve a missing command
                /usr/lib/command-not-found $commandName
            }.GetNewClosure()
        }
        else {
            Write-Warning "Incoming command $commandName didn't have the expected 'get-' prefix. Error handler may need to be updated."
        }
    } 
}

if (![string]::IsNullOrWhiteSpace($stage2Script)) {
    if (Test-Path -Path $stage2Script) {
        Write-Host "Chaining to $stage2Script..."
        . $stage2Script -rootPath $rootPath
    }
    else {
        Write-Error "Stage2 script $stage2Script doesn't exist"
    }
}

Invoke-CheckPowerShell
