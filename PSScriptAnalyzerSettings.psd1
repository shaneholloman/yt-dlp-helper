@{
    IncludeRules = @('*')
    ExcludeRules = @('PSAvoidUsingWriteHost')
    Rules = @{
        PSAvoidUsingInvokeExpression = @{
            Enable = $true
        }
        PSUseShouldProcessForStateChangingFunctions = @{
            Enable = $false
        }
        PSUseSingularNouns = @{
            Enable = $false
        }
    }
}
