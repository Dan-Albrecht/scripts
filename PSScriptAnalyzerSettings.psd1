@{
    IncludeDefaultRules = $true
    IncludeRules = @('PSPlaceOpenBrace', 'PSPlaceCloseBrace', 'PSAvoidTrailingWhitespace')
    Rules = @{
        PSPlaceOpenBrace = @{
            Enable = $true
            OnSameLine = $true
        }
        PSPlaceCloseBrace = @{
            Enable = $true
            NewLineAfter = $false
        }
    }
}
