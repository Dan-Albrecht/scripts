$globalAliases = New-Object Collections.Generic.List[String]

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
