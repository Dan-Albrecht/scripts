function prompt {
    $rightFlame = [char]::ConvertFromUtf32(0xe0c0)
    $triangleRight = [char]::ConvertFromUtf32(0xe0b0)
    $exitGlyph = [char]::ConvertFromUtf32(0xf705)
    $noGit = [char]::ConvertFromUtf32(0xf663)
    $highVoltage = [char]::ConvertFromUtf32(0x26a1)
    $origLastExitCode = $LASTEXITCODE

    # Could also names from https://www.w3schools.com/Colors/colors_names.asp
    $gitStatusBackgroundColor = "#663399"
    $timeBackgroundColor = "#00CF00"
    $date = Get-Date -Format "[HH:mm]"
    $prompt = ""

    if (Test-Administrator) {
        $prompt += $highVoltage
    }

    $prompt += Write-Prompt -ForegroundColor Black -BackgroundColor $timeBackgroundColor -Object $triangleRight
    $prompt += Write-Prompt -ForegroundColor White -BackgroundColor $timeBackgroundColor -Object $date
    $prompt += Write-Prompt -ForegroundColor $timeBackgroundColor -BackgroundColor Blue -Object $triangleRight
    $prompt += Write-Prompt -ForegroundColor White -BackgroundColor Blue -Object "$($ExecutionContext.SessionState.Path.CurrentLocation)"
    $prompt += Write-Prompt -ForegroundColor Blue -BackgroundColor $gitStatusBackgroundColor -Object $triangleRight

    if ($status = Get-GitStatus -Force) {
        $temp = $GitPromptSettings.PathStatusSeparator.Text
        $GitPromptSettings.PathStatusSeparator.Text = ""
        $status = Write-GitStatus -Status $status
        $GitPromptSettings.PathStatusSeparator.Text = $temp
        $prompt += Write-Prompt -BackgroundColor $gitStatusBackgroundColor -Object $status
    }
    else {
        $prompt += Write-Prompt -ForegroundColor White -BackgroundColor $gitStatusBackgroundColor -Object ($noGit + " ")
    }

    $prompt += Write-Prompt -ForegroundColor $gitStatusBackgroundColor -BackgroundColor Yellow -Object $triangleRight
    $prompt += Write-Prompt -ForegroundColor Black -BackgroundColor Yellow -Object "$exitGlyph $origLastExitCode "
    $prompt += Write-Prompt -ForegroundColor Red -BackgroundColor Red -Object " "
    $prompt += Write-Prompt -ForegroundColor Red -BackgroundColor Black -Object $rightFlame
    $prompt += "`n"

    $LASTEXITCODE = $origLastExitCode
    $prompt
}

function CreateDynamicAlias() {
    param(
        [Parameter(Mandatory = $true)][string]$name,
        [Parameter(Mandatory = $true)][string]$action,
        [Parameter(Mandatory = $false)][Switch]$allowArgs
    )

    $functionName = [guid]::NewGuid().ToString("N")
    
    if ($allowArgs) {
        $dynamicFunction = "function global:$functionName { param([Parameter(Mandatory = " + '$false, ValueFromRemainingArguments = $true)][string[]]$args)' + $action + ' $args }'
    }
    else {
        $dynamicFunction = "function global:$functionName() {$action}"
    }

    Invoke-Expression $dynamicFunction

    # Get rid of anything that might have been here before us. Usually this is annoying PowerShell builtins.
    Remove-Alias -Name $name -Force -ErrorAction Ignore
    Set-Alias -Name $name -Value $functionName -Scope Global
    $PromptSettings.Aliases.Add("$name -> $action")
}

function Invoke-FetchPull {
    param (
        [Parameter(Mandatory = $true)][bool]$fetchOnly,
        [Parameter(Mandatory = $true)][TargetBranch]$targetBranch
    )

    if ($status = Get-GitStatus -Force) {
        $upstreamParts = $status.Upstream.Split("/", 2)

        if ($null -eq $upstreamParts -or 2 -ne $upstreamParts.Count) {
            throw "Couldn't figure out upstream"
        }

        $remote = $upstreamParts[0]
        $upstream = $upstreamParts[1]
        $currentSettings = [RepoSettings]::GetCurrentSettings($PromptSettings.SettingsFile)
        $defaultBranch = $currentSettings.DefaultBranch
        $action = ""
        $branchName = ""

        if ($fetchOnly) {
            $action = "fetch"
        }
        else {
            $action = "pull"
        }

        switch ($targetBranch) {
            ([TargetBranch]::Default) { $branchName = $defaultBranch }
            ([TargetBranch]::Upstream) { $branchName = $upstream }
            Default { throw "Dunno what to do with $targetBranch" }
        }

        git.exe $action $remote $branchName
    }
    else {
        Write-NonTerminatingError "This isn't a git repo..."
    }
    
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
    foreach ($alias in $PromptSettings.Aliases) {
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

function TimeCommand {
    param (
        [Parameter(Mandatory = $true)][ScriptBlock]$scriptBlock
    )

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    . $scriptBlock
    $sw.Stop()

    $sw = $sw.ElapsedMilliseconds.ToString("N0")
    $sw = "Completed in $sw" + "ms"
    Write-Host $sw
}