$globalAliases = New-Object Collections.Generic.List[String]
$settingsFile = [System.IO.Path]::GetFullPath("$PSScriptRoot\..\..\..\repoSettings.json")

Function CreateDynamicAlias() {
    param(
        [Parameter(Mandatory = $true)][string]$name,
        [Parameter(Mandatory = $true)][string]$action
    )

    $functionName = [guid]::NewGuid().ToString("N")
    $dynamicFunction = "function global:$functionName() {$action}"
    Invoke-Expression $dynamicFunction
    Set-Alias -Name $name -Value $functionName -Scope Global
    $globalAliases.Add("$name -> $action")
}

function Import-RepoSettings {   
    param(
        [Parameter(Mandatory = $true)][string]$repoPath,
        [Parameter(Mandatory = $false)][bool]$isFatal = $false
    )

    if (!(Test-Path -Path $settingsFile)) {
        $message = "Settings file '$settingsFile' does not exist"

        if($isFatal){
            Write-NonTerminatingError $message
        }
        else{
            Write-Warning $message
        }        

        $example = New-SampleRepoSettingsJson -repoPath $repoPath
        $message = "An example one for the current repo would look like:`n$example"

        if($isFatal){
            Write-NonTerminatingError $message
            Write-Error '💩'
        }
        else{
            Write-Warning $message
        }
        
    }
    else {
        [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'It is a global for use interactively...')]
        $global:repoSettings = Get-Content -Path $settingsFile | ConvertFrom-Json
    }
}

function New-SampleRepoSettingsJson {   
    param(
        [Parameter(Mandatory = $true)][string]$repoPath
    )

    $example = @{
        $repoPath = [PSCustomObject]@{
            DefaultBranch = "main"
        }
    }

    $example = ConvertTo-Json $example

    return $example
}

function Invoke-PullDefaultBranch {

    $output = Invoke-WithErrorHandling "git" @('rev-parse', '--show-toplevel')

    # Output array should only have one line that is the repo, anything else and some assumption is wrong
    if ($output.Count -ne 1) {
        $output = $output | Out-String
        Write-Error "Expected to get a single line of output, but got:`n$output"
    }

    # Aparently a string array of 1 item is/can be directly directed as just a plain string...
    $currentRepo = [System.IO.Path]::GetFullPath($output)
    Write-Host "Current repo is rooted at $currentRepo"

    Import-RepoSettings -repoPath $currentRepo -isFatal $true

    $currentRepoSettings = $repoSettings.$currentRepo

    if ($null -eq $currentRepoSettings) {
        $example = New-SampleRepoSettingsJson -repoPath $currentRepo
        Write-NonTerminatingError "Current repo doesn't exist in repo settings file at $settingsFile"
        Write-NonTerminatingError "Add an entry like the following to it:`n$example"
        Write-Error '💩'
    }

    $pullBranch = $currentRepoSettings.DefaultBranch

    if ($null -eq $pullBranch) {
        Write-Error 'Repo settings don''t contain a DefaultBranch property'
    }

    # Progress seems to be going to stderr and screwing this up...
    # Invoke-WithErrorHandling "git" @('pull', 'origin', $pullBranch)
    git pull origin $pullBranch
}

function Invoke-WithErrorHandling {
    param (
        [Parameter(Mandatory = $true)][string]$execString,
        [Parameter(Mandatory = $false)][string[]]$args
    )

    $output = & $execString $args 2>&1
    $lastExit = $LASTEXITCODE

    if ($lastExit -ne 0) {
        Write-Error "Command $execString $args exited with code $lastExit and output of $output"
    }

    return $output
}

function Get-AliasEx {
    Get-Alias
    Write-Host
    Write-Host "Cool aliases"
    Write-Host "============"
    foreach ($alias in $globalAliases) {
        Write-Host $alias
    }
}

function Write-NonTerminatingError {
    param (
        [Parameter(Mandatory = $true)][string]$message
    )

    Write-Host -ForegroundColor Red -Object $message
}

function Write-TerminatingError {
    param (
        [Parameter(Mandatory = $true)][string]$message
    )

    # Don't want all the crap powershell would normally print out
    # $ErrorView = 'ConciseView' doesn't apply to scripts so
    # create a simple good enough one
    Write-Host -ForegroundColor Red -Object $message
    exit
}

function Import-ModuleEx {
    param (
        [Parameter(Mandatory = $true)][string]$name,
        [Parameter(Mandatory = $true)][string]$version
    )

    $modules = Get-Module -Name $name -ListAvailable   
    
    if ($null -eq $modules) {
        Write-TerminatingError "Module missing, run: Install-Module -Name $name -RequiredVersion $version"
    }

    if ($null -eq ($modules.Version | Where-Object { $_ -eq $version })) {
        $foundVersions = $modules.Version
        $foundVersions = [string]::Join(", ", $foundVersions)
        Write-NonTerminatingError "While loading $name expected to find version $version, but found $foundVersions."
        Write-TerminatingError "Update prompt settings or install via: Install-Module -Name $name -RequiredVersion $version"
    }

    Import-Module -Name $name -RequiredVersion $version
}

function Test-Font {
    param (
        [Parameter(Mandatory = $true)][string]$name,
        [Parameter(Mandatory = $true)][string]$remediationInfo
    )

    $font = Get-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts' -Name $name -ErrorAction SilentlyContinue
    if ($null -ne $font) {
        return;
    }

    $font = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts' -Name $name -ErrorAction SilentlyContinue
    if ($null -ne $font) {
        return;
    }

    Write-Warning "Font '$name' was not found, you may have some rendering errors. To remediate: $remediationInfo"
}
