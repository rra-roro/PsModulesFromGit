. $PSScriptRoot\install.ps1

<#
    1) $url = https://github.com/rra-roro/PsModulesFromGit
       $branch = main
       $token

    2) $url = https://github.com/rra-roro/PsModulesFromGit
       $branch = main
       $module
       $token

       ||

    4) $url = https://github.com/rra-roro/PsModulesFromGit/tree/main/Assets
       $token

#>

<#
.SYNOPSIS


.DESCRIPTION
Long description

.EXAMPLE
An example

.NOTES
General notes
#>
function Install-PSModuleGitHub
{
    param (
        [Parameter(Mandatory = $true, 
                   HelpMessage="https://github.com/<user-name>/<repo-name>")]
        [string]$Url,    

        [Parameter(Mandatory = $false, 
                   HelpMessage = 'Repository branch')]
        [string]$Branch = "main",

        [Parameter(Mandatory=$false, 
                   HelpMessage = 'Module name (Folder in Repository)')]
        [Alias("Module")]
        [string] $ModulePath,

        [Parameter(Mandatory=$false, 
                   HelpMessage = 'Personal access Token')]
        [string] $Token
    )

    $githubUriRegex = "(?<Scheme>https://)(?<Host>[^/]+)/"
    $githubMatch = [regex]::Match($Url, $githubUriRegex);

    if( $(GetGroupValue $githubMatch "Host") -ne "github.com")
    {
        throw [System.ArgumentException] "Incorrect `$Url argument. It's not GitHub URL."; 
    }
    
    # $url = https://github.com/rra-roro/PsModulesFromGit/tree/main/Assets
   
    $Url += "/tree/$Branch"
    if($ModulePath) { $Url += "/$ModulePath"} 
    if($Token) { $Url = $Url -replace "(https://)(.+)","`$1$Token@`$2" }

    lib_main -Url $Url 

}

function Update-PSModuleGitHub
{
    param (
        [Parameter(Mandatory=$true, 
                   HelpMessage = 'Module name')]
        [Alias("Module")]
        [string] $ModuleName
    )

    $module = Get-Module PsModulesFromGit -ListAvailable
    $modulePath = $module.ModuleBase

    $ModuleRepoInfo = Get-Content -LiteralPath $modulePath\ModuleRepoInfo | ConvertFrom-Json
    $ModuleRepoInfo
}

Export-ModuleMember Install-PSModuleGitHub,  Update-PSModuleGitHub