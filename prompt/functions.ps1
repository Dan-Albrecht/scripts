function prompt {
    try {
        $rightFlame = [char]::ConvertFromUtf32(0xe0c0)
        $triangleRight = [char]::ConvertFromUtf32(0xe0b0)
        $exitGlyph = [char]::ConvertFromUtf32(0xf05fc)
        $noGit = [char]::ConvertFromUtf32(0xf0164)
        $highVoltage = [char]::ConvertFromUtf32(0x26a1)
        $classicWindows = [char]::ConvertFromUtf32(0xF0A21)
        $origLastExitCode = $LASTEXITCODE

        # Could also names from https://www.w3schools.com/Colors/colors_names.asp
        $adminForgeground = 'Yellow'
        $adminBackground = 'Black'
        $timeForeground = 'White'
        $timeBackground = '#00CF00'
        $directoryForeground = 'White'
        $directoryBackground = 'Blue'
        $gitStatusForeground = 'White' # Only used for not git dirs
        $gitStatusBackground = 'Black'
        $exitForeground = 'Black'
        $exitBackground = 'Yellow'
        $flameForeground = 'Red'

        $date = Get-Date -Format '[HH:mm'
        $date += (Get-Date -AsUTC -Format '/HH:mm') + 'z]'
        $prompt = ''

        if ($IsWindows) {
            $prompt += Write-Prompt -Object ($classicWindows + " ")
            $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
            $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

            if ($isAdmin) {
                $prompt += Write-Prompt -ForegroundColor $adminForgeground -BackgroundColor $adminBackground -Object $highVoltage
            }
            else {
                $prompt += Write-Prompt -ForegroundColor $adminForgeground -BackgroundColor $adminBackground -Object '💩'
            }
        }
        else {
            $prompt += Write-Prompt -ForegroundColor $adminForgeground -BackgroundColor $adminBackground -Object '🐧'
        }

        $prompt += Write-Prompt -ForegroundColor $adminBackground -BackgroundColor $timeBackground -Object $triangleRight
        $prompt += Write-Prompt -ForegroundColor $timeForeground -BackgroundColor $timeBackground -Object $date
        $prompt += Write-Prompt -ForegroundColor $timeBackground -BackgroundColor $directoryBackground -Object $triangleRight
        $prompt += Write-Prompt -ForegroundColor $directoryForeground -BackgroundColor $directoryBackground -Object "$($ExecutionContext.SessionState.Path.CurrentLocation)"
        $prompt += Write-Prompt -ForegroundColor $directoryBackground -BackgroundColor $gitStatusBackground -Object $triangleRight

        if ($status = Get-GitStatus -Force) {
            $temp = $GitPromptSettings.PathStatusSeparator.Text
            $GitPromptSettings.PathStatusSeparator.Text = ''
            $status = Write-GitStatus -Status $status
            $GitPromptSettings.PathStatusSeparator.Text = $temp

            # $status is already (multi) colored, so don't set it
            $prompt += Write-Prompt -BackgroundColor $gitStatusBackground -Object $status
        }
        else {
            $prompt += Write-Prompt -ForegroundColor $gitStatusForeground -BackgroundColor $gitStatusBackground -Object ($noGit + ' ')
        }

        $prompt += Write-Prompt -ForegroundColor $gitStatusBackground -BackgroundColor $exitBackground -Object $triangleRight
        $prompt += Write-Prompt -ForegroundColor $exitForeground -BackgroundColor $exitBackground -Object "$exitGlyph $origLastExitCode "
        $prompt += Write-Prompt -ForegroundColor $flameForeground -Object $rightFlame
        $prompt += "`n"

        $LASTEXITCODE = $origLastExitCode
        # "⧸ " + $prompt + "⧹ "
        $prompt = '▕▔ ' + $prompt + '▕▁ '
    }
    catch {
        $prompt = 'Prompt screwed up with: '
        $prompt += $Error[0]
        $prompt += "`n"
        $prompt += 'Busted Prompt> '
    }

    $prompt
}

function SplitIntoArgs {
    param (
        [Parameter(Mandatory = $true)][string]$arguments,
        [Parameter(Mandatory = $true)][bool]$stripQuotes
    )

    # https://stackoverflow.com/a/366532
    $match = "[^\s`"']+|`"([^`"]*)`"|'([^']*)'"
    $regex = [System.Text.RegularExpressions.Regex]::new($match)
    $regexMatches = $regex.Matches($arguments)
    $result = [System.Collections.Generic.List[string]]::new()
    foreach ($regexMatch in $regexMatches) {
        if ($stripQuotes) {
            $item = $regexMatch.Value.Trim([char[]]@('"', "`'"))
        }
        else {
            $item = $regexMatch.Value
        }
        $result.Add($item)
    }
    return $result
}

# PowerShell is annoying about function results. If you run an exe directly in your function
# and that thing outputs to the console, that all becomes part of your function result.
# You usually still want the output displayed on the conosle so pipeing to Out-Null
# isn't an option. Out-Default seems to strip away color. So just delegate to here and run
# through Start-Process.
# https://stackoverflow.com/a/10288256
function RunAndThrowOnNonZero {
    param (
        [Parameter(Mandatory = $true)][string]$arguments,
        [Parameter(Mandatory = $false)][bool]$shouldThrow = $false
    )

    $parsedArgs = SplitIntoArgs -arguments $arguments -stripQuotes $false
    $exeName = $parsedArgs[0]
    $restOfArgs = $parsedArgs[1..$parsedArgs.Length]
    
    $proccess = Start-Process -FilePath $exeName -ArgumentList $restOfArgs -PassThru -NoNewWindow
    $proccess | Wait-Process

    if ($shouldThrow -and $proccess.ExitCode -ne 0) {
        throw "$exeName exited with $($proccess.ExitCode)"
    }
}

function CreateDynamicAlias() {
    param(
        [Parameter(Mandatory = $true)][string]$name,
        [Parameter(Mandatory = $true)][string]$action,
        [Parameter(Mandatory = $false)][Switch]$allowArgs
    )

    $functionName = [guid]::NewGuid().ToString('N')
    
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
    $PromptSettings.Aliases.Add($name, $action)
}

function Test-SearchPath {
    param (
        [Parameter(Mandatory = $true)][string]$search
    )

    if ($IsLinux) {
        which $search | Out-Null
    }
    else {
        where.exe /Q $search | Out-Null
    }

    $whereResult = $LASTEXITCODE
    
    # Where uses exit codes to return what it found. We don't need this to propagate outside of this function.
    $Global:LASTEXITCODE = 0

    if ($whereResult -eq 0) {
        return $true
    }
    else {
        return $false
    }
}

function Invoke-GitPush {
    param (
        [Parameter(Mandatory = $false)][string]$commitMessage
    )

    $aheadBy = (Get-GitStatus -Force).AheadBy

    if ($null -eq $aheadBy) {
        Write-Error "Can't push when you're not in a repo..."
        return
    }

    if ([string]::IsNullOrWhiteSpace($commitMessage)) {
        if ($aheadBy -gt 0) {
            git push
            return
        }

        $commitMessage = Read-Host 'Commit message'
        if ([string]::IsNullOrWhiteSpace($commitMessage)) {
            Write-Host 'Giving up...'
        }
    }

    RunAndThrowOnNonZero -arguments 'git add .' -shouldThrow $true
    RunAndThrowOnNonZero -arguments "git commit -m `"$commitMessage`""
    RunAndThrowOnNonZero -arguments 'git push' -shouldThrow $true
}

function Invoke-CheckPowerShell {
    param ()
    
    $installed = $PSVersionTable.PSVersion

    if (-not [string]::IsNullOrEmpty($installed.BuildLabel)) {
        Write-Warning "You seem to be running a private build of PowerShell. Don't know how to check for updates for that"
        return
    }

    try {
        # https://github.com/PowerShell/PowerShell/blob/master/tools/install-powershell.ps1
        $metadata = Invoke-RestMethod -Uri https://raw.githubusercontent.com/PowerShell/PowerShell/master/tools/metadata.json -TimeoutSec 5
    }
    catch {
        Write-Warning "Couldn't check latest PowerShell. Are you online?"
        return
    }    
    
    if (-not [string]::IsNullOrEmpty($installed.PreReleaseLabel)) {
        $release = $metadata.PreviewReleaseTag -replace '^v'
        $release = [System.Management.Automation.SemanticVersion]::new($release)

        # Mainline may get ahead of preview, so double check
        $mainLineRelease = $metadata.ReleaseTag -replace '^v'
        $mainLineRelease = [System.Management.Automation.SemanticVersion]::new($mainLineRelease)        

        if ($mainLineRelease -gt $release) {
            Write-Warning "You're running preview $release, but mainline is ahead at $mainLineRelease. Consider moving to mainline again or validate preview builds are still shipped the same way as ever."
            $release = $mainLineRelease
        }
    }
    else {
        $release = $metadata.ReleaseTag -replace '^v'
        $release = [System.Management.Automation.SemanticVersion]::new($release)        
    }

    if ($installed -lt $release) {
        $packageName = "PowerShell-${release}-win-x64.msi"
        $downloadURL = "https://github.com/PowerShell/PowerShell/releases/download/v${release}/${packageName}"
        
        Write-Host "PowerShell version $installed is out of date, update to ${release}:"
        Write-Host "Release notes: https://github.com/PowerShell/PowerShell/releases/tag/v${release}"
        Write-Host $downloadURL        
        $answer = Read-Host 'Do you want to install it now (y/n)'
        
        if ($answer -eq 'y' -or $answer -eq 'yes') {
            $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
            $null = New-Item -ItemType Directory -Path $tempDir
            $packagePath = Join-Path -Path $tempDir -ChildPath $packageName
            try {
                Invoke-WebRequest -Uri $downloadURL -OutFile $packagePath -TimeoutSec 5    
            }
            catch {
                Write-Warning 'Failed to start download, did you go offline?'
                return
            }
            
            Start-Process $packagePath
            Write-Warning 'Installer running, you should close all windows so it can update without reboot'
        }
        else {
            Write-Host 'Loser'
        }
    }
    elseif ($installed -gt $release) {
        Write-Warning "You're running ($installed) a future version of PowerShell (latest is $release)?"
    }
}

function Invoke-CheckRust {
    param ()

    if (-not (Test-SearchPath -search "rustup")) {
        Write-Error "rustup not intalled. Install from https://www.rust-lang.org/tools/install"
        return
    }

    if ($IsLinux) {
        rustup check | grep "Update available" | Out-Null
    }
    else {
        rustup check | findstr.exe /sc:"Update available" | Out-Null
    }

    $lastExit = $LASTEXITCODE
    $LASTEXITCODE = 0

    if ($lastExit -eq 0) {
        Write-Host "Rust needs an update:"
        rustup check
        Write-Host "To update: rustup update"
    }
    else {
        Write-Host "Rust is up to date"
    }

    if (-not (Test-SearchPath -search "rg")) {
        Write-Warning "ripgrep is not installed."
        Write-Host "  To install: cargo install ripgrep -F pcre2"
        return
    }
}

function Invoke-FetchPull {
    param (
        [Parameter(Mandatory = $true)][bool]$fetchOnly,
        [Parameter(Mandatory = $true)][TargetBranch]$targetBranch
    )

    if ($status = Get-GitStatus -Force) {
        
        if ($null -eq $status.Upstream) {
            throw 'Current upstream is not set, so cannot figure out remote'
        }

        $upstreamParts = $status.Upstream.Split('/', 2)

        if ($null -eq $upstreamParts -or 2 -ne $upstreamParts.Count) {
            throw "Couldn't figure out upstream"
        }

        $remote = $upstreamParts[0]
        $upstream = $upstreamParts[1]
        $currentSettings = [RepoSettings]::GetCurrentSettings($PromptSettings.SettingsFile)
        $defaultBranch = $currentSettings.DefaultBranch
        $action = ''
        $branchName = ''

        if ($fetchOnly) {
            $action = 'fetch'
        }
        else {
            $action = 'pull'
        }

        switch ($targetBranch) {
            ([TargetBranch]::Default) { $branchName = $defaultBranch }
            ([TargetBranch]::Upstream) { $branchName = $upstream }
            Default { throw "Dunno what to do with $targetBranch" }
        }

        RunAndThrowOnNonZero -arguments "$(Get-Git) $action $remote $branchName" -shouldThrow $true
    }
    else {
        Write-NonTerminatingError "This isn't a git repo..."
    }
    
}

function Invoke-Rebase {
    if ($status = Get-GitStatus -Force) {
        
        if ($null -eq $status.Upstream) {
            throw 'Current upstream is not set, so cannot figure out remote'
        }

        $upstreamParts = $status.Upstream.Split('/', 2)

        if ($null -eq $upstreamParts -or 2 -ne $upstreamParts.Count) {
            throw "Couldn't figure out upstream"
        }

        $remote = $upstreamParts[0]
        $currentSettings = [RepoSettings]::GetCurrentSettings($PromptSettings.SettingsFile)
        $defaultBranch = $currentSettings.DefaultBranch

        RunAndThrowOnNonZero -arguments "$(Get-Git) pull --rebase $remote $defaultBranch" -shouldThrow $true
    }
    else {
        Write-NonTerminatingError "This isn't a git repo..."
    }
}

function Invoke-Squash {
    if ($status = Get-GitStatus -Force) {
        
        if ($null -eq $status.Upstream) {
            throw 'Current upstream is not set, so cannot figure out remote'
        }

        $upstreamParts = $status.Upstream.Split('/', 2)

        if ($null -eq $upstreamParts -or 2 -ne $upstreamParts.Count) {
            throw "Couldn't figure out upstream"
        }

        $remote = $upstreamParts[0]
        $currentSettings = [RepoSettings]::GetCurrentSettings($PromptSettings.SettingsFile)
        $defaultBranch = $currentSettings.DefaultBranch

        RunAndThrowOnNonZero -arguments "$(Get-Git) --soft $remote/$defaultBranch"
        RunAndThrowOnNonZero -arguments "$(Get-Git) add --all"
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
    param (
        [Parameter(Mandatory = $false)][string]$alias
    )

    if ([string]::IsNullOrWhiteSpace($alias)) {

        # We skip of our aliases here because most of them will just say they map to guids
        # When we enumerate our list we'll print what we're actually mapping them to
        [string[]]$ourAliases = $PromptSettings.Aliases.Keys | Out-String -Stream
        Get-Alias -Exclude $ourAliases
        Write-Host
        Write-Host 'Cool aliases'
        Write-Host '============'
        foreach ($item in $PromptSettings.Aliases.GetEnumerator()) {
            Write-Host "$($item.Key) -> $($item.Value)"
        }
    }
    else {
        [string]$foundAlias = $null
        if ($PromptSettings.Aliases.TryGetValue($alias, [ref]$foundAlias)) {
            return "$alias -> $foundAlias"
        }
        else {
            $normalAlias = Get-Alias -Name $alias -ErrorAction Ignore
            if ($null -ne $normalAlias) {
                $normalAlias
            }
            else {
                Write-NonTerminatingError "There is no alias called $alias, you dingus"
            }
        }        
    }    
}

function Write-NonTerminatingError {
    param (
        [Parameter(Mandatory = $true)][string]$message
    )

    Write-Host -ForegroundColor Red -Object $message
}

function Format-ActuallyConcise {
    [CmdletBinding()]
    param(
        [System.Management.Automation.ErrorRecord]$errorRecord
    )

    try {
        $exceptionMessage = $errorRecord.Exception.Message
        $st = $errorRecord.ScriptStackTrace
        $split = $st.Split([System.Environment]::NewLine, [StringSplitOptions]::RemoveEmptyEntries)
        Write-Host -ForegroundColor Red -Object $exceptionMessage

        foreach ($line in $split) {
            if ($line -eq 'at <ScriptBlock>, <No file>: line 1') {
                $line = 'The Console'
            }
            elseif ($line.StartsWith('at global:') -and $line.EndsWith(', <No file>: line 1')) {
                $potentialAlias = $line.Replace('at global:', [string]$null).Replace(', <No file>: line 1', [string]$null)
                $alias = Get-Alias -Definition $potentialAlias -ErrorAction SilentlyContinue
                if ($null -ne $alias) {
                    $ourAlias = Get-AliasEx -alias $alias.Name
                    if ($null -ne $ourAlias) {
                        $line = "The alias: $ourAlias"
                    }
                }
            }

            Write-Host -ForegroundColor DarkGray "  $line"
        }
    }
    catch {
        # Not sure if possible, but try and prevent recursive loop caused by outputting another ErrorRecord here
        $message = $_.ToString()
        Write-Host "Screwed up writing error: $message"
    }
}

function Write-WarningEx {
    param (
        [Parameter(Mandatory = $true)][string]$message
        , [Parameter(Mandatory = $false)][bool]$showStack = $true
    )

    if ($showStack) {
        $details = '  => ' + $MyInvocation.ScriptName + '@' + $MyInvocation.ScriptLineNumber
        $message += "`n$details"
    }

    Write-Host -ForegroundColor Yellow -Object $message
}

function Import-ModuleEx {
    param (
        [Parameter(Mandatory = $true)][string]$name,
        [Parameter(Mandatory = $true)][string]$version,
        [Parameter(Mandatory = $false)][string]$potentialReleaseNotes
    )

    if ($IsWindows) {
        $temp = "$env:TMP"
    }
    else {
        $temp = "$env:HOME/.cache"
    }

    $checkName = [System.IO.Path]::Combine($temp, $name + '.check')
    $threeDays = [timespan]::FromDays(3)
    if (SomethingAboutTouching -filename $checkName -howLong $threeDays) {

        Write-Host "Checking online for latest $name..." -NoNewline
        . TimeCommand {
            [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', 'I am')]
            $latestModuleInfo = Find-Module -Name $name
        }

        # For now just assuming we always want latest
        if ($latestModuleInfo.Version -ne $version) {
            Write-Warning "$name appears to have an update. You requested $version, but $($latestModuleInfo.Version) is available. Install with:`nInstall-Module -Name $name -RequiredVersion $($latestModuleInfo.Version)"

            if ($null -ne $potentialReleaseNotes) {
                Write-Host "Release notes may be avilable at: $potentialReleaseNotes"
            }
        }
    }

    $modules = Get-Module -Name $name -ListAvailable   
    
    if ($null -eq $modules) {
        Write-Error "Module missing, run: Install-Module -Name $name -RequiredVersion $version`nRelease Details: https://www.powershellgallery.com/packages/$name/$version"
    }

    $maxVersion = $null
    $desiredVersion = [version]::Parse($version)
    $didntFindDesiredVersion = $true
    foreach ($module in $modules) {
        if ($maxVersion -lt $module.Version) {
            $maxVersion = $module.Version
        }
        if ($module.Version -eq $desiredVersion) {
            $didntFindDesiredVersion = $false
        }
    }

    if ($didntFindDesiredVersion) {
        $foundVersions = $modules.Version
        $foundVersions = [string]::Join(', ', $foundVersions)
        Write-NonTerminatingError "While loading $name expected to find version $version, but found $foundVersions.`nRelease Details: https://www.powershellgallery.com/packages/$name/$version"
        Write-Error "Update prompt settings or install via: Install-Module -Name $name -RequiredVersion $version"
    }

    if ($maxVersion -gt $desiredVersion) {
        Write-Warning "By the way, you have version $maxVersion of $name installed, but you asked to load $desiredVersion. What's up with that?"
    }

    Write-Host "Loading module $name..." -NoNewline
    . TimeCommand {
        Import-Module -Name $name -RequiredVersion $version
    }
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
        , [Parameter(Mandatory = $false)][string]$message
    )

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    . $scriptBlock
    $sw.Stop()

    $sw = $sw.ElapsedMilliseconds.ToString('N0')
    $sw = "$message Completed in $sw" + 'ms'
    Write-Host $sw
}

function TouchFile {
    param (
        [Parameter(Mandatory = $true)][string]$filename
    )
    
    $file = Get-ChildItem -Path $filename -ErrorAction SilentlyContinue
    if ($null -ne $file) {
        $file.LastWriteTimeUtc = Get-Date -AsUTC
    }
    else {
        New-Item -Path $filename | Out-Null
    }
}

function SomethingAboutTouching {
    param (
        [Parameter(Mandatory = $true)][string]$filename,
        [Parameter(Mandatory = $true)][timespan]$howLong
    )

    $file = Get-ChildItem -Path $filename -ErrorAction SilentlyContinue
    if ($null -ne $file) {
        $now = Get-Date -AsUTC
        $leaveAloneUntil = $file.LastWriteTimeUtc + $howLong
        if ($leaveAloneUntil -gt $now) {
            return $false
        }
    }    

    TouchFile -filename $filename
    return $true
}

function Spin {
    param (
        [Parameter(Mandatory = $true)][int]$ticks
    )
    $now = [datetime]::UtcNow.Ticks
    $end = $now + $ticks
    while ([datetime]::UtcNow.Ticks -le $end) {    
    }    
}

function SlowPrintFile {
    param (
        [Parameter(Mandatory = $true)][string]$filename,
        [Parameter(Mandatory = $false)][int]$delay = 200000
    )
    $lines = Get-Content -Path $filename
    foreach ($line in $lines) {
        Write-Host $line
        Spin -ticks $delay
    }
}

function Stop-ProcessEx {
    param (
        [Parameter(Mandatory = $true)][string]$name,
        [Parameter(Mandatory = $false)][bool]$forceKill = $false
    )

    # Need silent continue as finding nothing is an error according to this
    $procs = Get-Process -Name $name -ErrorAction SilentlyContinue

    if ($null -eq $procs -or $procs.Length -eq 0) {
        Write-Warning 'Found nothing to kill'
    }
    else {
        if ($forceKill) {
            $procs | Stop-Process -Force
        }
        else {
            $procs | Where-Object { $_.MainWindowHandle -ne [System.IntPtr]::Zero } | ForEach-Object { $_.CloseMainWindow() } | Out-Null

            # Force is about killing another user's process, not about doing a nice shutdown
            # Since these have no main window can't do graceful so just normal kill them
            $procs | Where-Object { $_.MainWindowHandle -eq [System.IntPtr]::Zero } | ForEach-Object { Stop-Process $_ -Force } | Out-Null
        }

        $procs
    }
}

function Stop-ProcessExWrapper {
    param (
        [Parameter(Mandatory = $false)][string[]]$args
    )

    if ($null -eq $args -or $args.Length -eq 0) {
        Write-Error 'What, exactly, are you expecting me to kill?'
    }
    else {
        $usage = 'Usage: [-f] <name>'

        if ($args.Length -gt 2) {
            Write-Error $usage
        }
        else {
            if ($args.Length -eq 1) {
                Stop-ProcessEx -name $args[0]
            }
            else {
                if ($args[0] -ne '-f') {
                    Write-Error $usage
                }
                else {
                    Stop-ProcessEx -name $args[1] -forceKill $true
                }
            }
        }
    }
}

function Format-File {
    param (
        [Parameter(Mandatory = $true)][string]$path
    )

    if (-not [System.IO.File]::Exists($path)) {
        Write-Error "$path does not exist"
    }

    $lines = [string[]][System.IO.File]::ReadLines($path)
    $indentCount = 0
    $outStream = [System.IO.File]::Open($path, [System.IO.FileMode]::Truncate)
    $outWriter = [System.IO.StreamWriter]::new($outStream)

    foreach ($line in $lines) {
        $line = $line.TrimStart()
        
        if ($line.Contains('}')) {
            $indentCount--
            if ($indentCount -lt 0) {
                Write-Error "Went to negative indenting at line: $line"
            }
        }
        
        $formatedLine = ''
        for ($i = 0; $i -lt $indentCount; $i++) {
            $formatedLine += '  '
        }
        
        $formatedLine += ($line + "`n")
        $outWriter.Write($formatedLine)

        if ($line.Contains('{')) {
            $indentCount++
        }
    }
    
    $outWriter.Close()
}

function Get-Git {
    if ($IsWindows) {
        "git.exe"
    }
    else {
        "git"
    }
}
