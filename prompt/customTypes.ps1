class PromptSettings {
    
    [Collections.Generic.List[String]]$Aliases

    [ValidateNotNullOrEmpty()][string]$SettingsFile

    PromptSettings() {
        $this.Aliases = New-Object Collections.Generic.List[String]
        $this.SettingsFile = [System.IO.Path]::GetFullPath("$PSScriptRoot\..\..\..\repoSettings.json")
    }
}

class RepoSettings {
    # Full path to the root of the repo
    [ValidateNotNullOrEmpty()][string]$Root

    # Default branch name to pull from
    [ValidateNotNullOrEmpty()][string]$DefaultBranch

    # Need a default constructor to make the serializer happy, but
    # don't want to allow null properties to come in. So best I can
    # come up with is just throw if anyone but the serializer calls
    RepoSettings() {
        $stack = [System.Diagnostics.StackTrace]::new($false)
        $method = $stack.GetFrame(13).GetMethod()
        $typeName = $method.DeclaringType.FullName
        # Seems like single object vs array will come in with different stack
        # so just look for the namespace subsring; good enough
        $expectedTypeStartsWith = "System.Text.Json.Serialization."

        if ($false -eq $typeName.StartsWith($expectedTypeStartsWith)) {
            Write-Error "You're not allowed to call this; only deserializer is.`nYou: $typeName`nExpected: $expectedTypeStartsWith"
        }
    }

    RepoSettings($Root, $DefaultBranch) {
        $this.Root = $Root
        $this.DefaultBranch = $DefaultBranch
    }

    [RepoSettings[]] static Load([string]$settingsFile) {

        if (!(Test-Path -Path $settingsFile)) {
            $message = "Settings file '$settingsFile' does not exist"
    
            Write-NonTerminatingError $message
            
            $example = [RepoSettings]::GenerateExample()
            $message = "An example one for the current repo would look like:`n$example"
            Write-NonTerminatingError $message
            Write-Error '💩'

            throw "Shouldn't have made it here"            
        }
        else {
            $allText = Get-Content -Path $settingsFile
            $settings = [System.Text.Json.JsonSerializer]::Deserialize($allText, [RepoSettings[]], $null)
            return $settings
        }
    }

    [string] static GenerateExample() {
        $currentRoot = [RepoSettings]::GetCurrentRepoRoot()
        $example = [RepoSettings[]]@(
            [RepoSettings]::new($currentRoot, "main")
        )
        $example = [System.Text.Json.JsonSerializer]::Serialize($example, $null)
        return $example
    }

    [string] static GetCurrentRepoRoot() {
        $output = Invoke-WithErrorHandling "git" @('rev-parse', '--show-toplevel')

        # Output array should only have one line that is the repo, anything else and some assumption is wrong
        if ($output.Count -ne 1) {
            $output = $output | Out-String
            Write-Error "Expected to get a single line of output, but got:`n$output"
        }

        # Aparently a string array of 1 item is/can be directly directed as just a plain string...
        $currentRepo = [System.IO.Path]::GetFullPath($output)

        return $currentRepo
    }

    [RepoSettings] static GetCurrentSettings([string]$settingsFile) {
        $allRepos = [RepoSettings]::Load($settingsFile)
        $currentRoot = [RepoSettings]::GetCurrentRepoRoot()
        $currentSettings = $allRepos | Where-Object { $_.Root -eq $currentRoot }

        if ($null -eq $currentSettings) {
            $example = [RepoSettings]::GenerateExample()
            Write-NonTerminatingError "Current repo doesn't exist in repo settings file at $settingsFile"
            Write-NonTerminatingError "Add an entry like the following to it:`n$example"
            Write-Error '💩'
        }

        if ($currentSettings.Count -ne 1) {
            Write-Error "Settings file $settingsFile seems to have multiple entries for repo at $currentRoot"
        }

        return $currentSettings
    }
}
