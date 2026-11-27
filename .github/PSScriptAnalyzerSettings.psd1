@{
    Severity     = @('Error', 'Warning')
    ExcludeRules = @(
        # Console output is the user interface of this tool
        'PSAvoidUsingWriteHost',
        # Internal helper functions, confirmation is asked once for the whole run
        'PSUseShouldProcessForStateChangingFunctions',
        # Turkish function names use singular nouns already
        'PSUseSingularNouns'
    )
}
