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

    $module = Get-Module $ModuleName -ListAvailable
    $modulePath = $module.ModuleBase

    if(-not $module)
    {
        throw "'$ModuleName' module not found"
    }

    if(-not $(Test-Path $modulePath\ModuleRepoInfo) )
    {
        throw "'$ModuleName' wasn't installed by PsModulesFromGit"
    }

    $ModuleRepoInfo = Get-Content -LiteralPath $modulePath\ModuleRepoInfo | ConvertFrom-Json


    $URLobj = @{}
    $ModuleRepoInfo.URLobj.psobject.properties | Foreach { $URLobj[$_.Name] = $_.Value }
    
    Write-Host -ForegroundColor Green "`nStart downloading Module '$($URLobj['ModuleName'])' from $($URLobj['SchemeHost'])/$($URLobj['User'])" 
    Write-Host -ForegroundColor Green "                  Repository: $($URLobj['Repo'])"
    Write-Host -ForegroundColor Green "                  Branch: $($URLobj['Branch'])"

    # Download module to temporary folder
    $tmpArchiveName = $(Get-LocalTempPath -RepoName $URLobj['Repo']);
    Receive-Module -URLobj $URLobj -ToFile "${tmpArchiveName}.zip";

    sleep 5

    $moduleHash = Get-FileHash -Algorithm SHA384 -Path "${tmpArchiveName}.zip"

    if($moduleHash -ne $ModuleRepoInfo.ModuleHash)
    {

        if(Test-Path $modulePath)
        {
            Rename-Item -Path $modulePath -NewName "_$ModuleName"
        }

        $moduleFolder = Get-ModuleInstallFolder -ModuleName $URLobj['ModuleName'];

        Expand-ModuleZip -Archive $tmpArchiveName;

        Move-ModuleFiles -ArchiveFolder $tmpArchiveName -Module $URLobj['ModuleName'] -DestFolder $moduleFolder -ModuleHash "$($moduleHash.Hash)" -URLobj $URLobj;
        Invoke-Cleanup -ArchiveFolder $tmpArchiveName

        Write-Finish -moduleName $URLobj['ModuleName']

        if(Test-Path "$modulePath\..\_$ModuleName" )
        {
            Remove-Item -Path "$modulePath\..\_$ModuleName" -Recurse -Force
        }
    }
    else
    {
        Invoke-Cleanup -ArchiveFolder $tmpArchiveName
        Write-Host "Module '$ModuleName' didn't change.";
    }
}

Export-ModuleMember Install-PSModuleGitHub,  Update-PSModuleGitHub