Function CreateDynamicAlias() {
    param(
        [Parameter(Mandatory = $true)][string]$name,
        [Parameter(Mandatory = $true)][string]$action
    )

    $functionName = [guid]::NewGuid().ToString("N")
    $dynamicFunction = "function global:$functionName() {$action}"
    Invoke-Expression $dynamicFunction
    Set-Alias -Name $name -Value $functionName -Scope Global
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
