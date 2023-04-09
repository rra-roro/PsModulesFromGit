. $PSScriptRoot\install.ps1

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
    [cmdletBinding()]
    param (
        [Parameter(Mandatory = $true, 
                   HelpMessage="https://github.com/<user-name>/<repo-name>",
                   ParameterSetName="Url")]
        [string]$Url,    

        [Parameter(Mandatory = $true, 
                   HelpMessage="Returned Find-Module Object ",
                   ParameterSetName="ProjectUri",
                   ValueFromPipelineByPropertyName)]
        [string]$ProjectUri,    

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

    Process 
    {
        try
        {
            if($PSBoundParameters.ContainsKey("ProjectUri"))
            {
                $Url = $null
                if($ProjectUri.OriginalString.StartsWith("https://github.com"))
                {
                    $Url = $ProjectUri.AbsolutePath
                } 
                else 
                {
                    $name = $ProjectUri.LocalPath.split('/')[-1]
                    throw [Exception]::new("Module [$name]: not installed, it is not hosted on GitHub.")
                }
            }

            $githubUriRegex = "(?<Scheme>https://)(?<Host>[^/]+)/"
            $githubMatch = [regex]::Match($Url, $githubUriRegex);

            if( $(GetGroupValue $githubMatch "Host" -ErrorAction Stop) -ne "github.com")
            {
                throw [System.ArgumentException] "Incorrect `$Url argument. It's not GitHub URL."; 
            }
    
            # $url = https://github.com/rra-roro/PsModulesFromGit/tree/main/Assets
   
            $Url += "/tree/$Branch"
            if($ModulePath) { $Url += "/$ModulePath"} 
            if($Token) { $Url = $Url -replace "(https://)(.+)","`$1$Token@`$2" }

            lib_main -Url $Url 

        }
        catch
        {
            Write-Error -ErrorRecord $_
        }
    }
}

function Update-PSModuleGitHub
{
    [cmdletBinding()]
    param (
        [Parameter(Mandatory=$true, 
                   HelpMessage = 'Module name')]
        [Alias("Module")]
        [string] $ModuleName,

        [Parameter(Mandatory=$false, 
                   HelpMessage = 'Forced module reinstallation')]
        [Alias("Module")]
        [switch] $Force
    )

    try
    {
        $module = Get-Module $ModuleName -ListAvailable -ErrorAction Stop
        $modulePath = $module.ModuleBase

        if(-not $module)
        {
            throw "'$ModuleName' module not found"
        }

        if(-not $(Test-Path $modulePath\ModuleRepoInfo) )
        {
            throw "'$ModuleName' wasn't installed by PsModulesFromGit"
        }

        $ModuleRepoInfo = Get-Content -LiteralPath $modulePath\ModuleRepoInfo  -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop


        $URLobj = @{}
        $ModuleRepoInfo.URLobj.psobject.properties | Foreach { $URLobj[$_.Name] = $_.Value }
    
        Write-Host -ForegroundColor Green "`nStart downloading Module '$($URLobj['ModuleName'])' from $($URLobj['SchemeHost'])/$($URLobj['User'])" 
        Write-Host -ForegroundColor Green "                  Repository: $($URLobj['Repo'])"
        Write-Host -ForegroundColor Green "                  Branch: $($URLobj['Branch'])"

        # Download module to temporary folder
        $tmpArchiveName = $(Get-LocalTempPath -RepoName $URLobj['Repo'] -ErrorAction Stop);
        Receive-Module -URLobj $URLobj -ToFile "${tmpArchiveName}.zip" -ErrorAction Stop;

        sleep 5

        $moduleHash = Get-FileHash -Algorithm SHA384 -Path "${tmpArchiveName}.zip" -ErrorAction Stop

        if($moduleHash.Hash -ne $ModuleRepoInfo.ModuleHash -or $Force)
        {

            if(Test-Path $modulePath)
            {
                Rename-Item -Path $modulePath -NewName "_$ModuleName" -ErrorAction Stop
            }

            $moduleFolder = Get-ModuleInstallFolder -ModuleName $URLobj['ModuleName'] -ErrorAction Stop;

            Expand-ModuleZip -Archive $tmpArchiveName -ErrorAction Stop;

            Move-ModuleFiles -ArchiveFolder $tmpArchiveName -Module $URLobj['ModuleName'] -DestFolder $moduleFolder -ModuleHash "$($moduleHash.Hash)" -URLobj $URLobj -ErrorAction Stop;
            Invoke-Cleanup -ArchiveFolder $tmpArchiveName

            Write-Finish -moduleName $URLobj['ModuleName']

            if(Test-Path "$modulePath\..\_$ModuleName" )
            {
                Remove-Item -Path "$modulePath\..\_$ModuleName" -Recurse -Force
            }

            Remove-Module $ModuleName
            if($ModuleName -eq 'PsModulesFromGit') { Import-Module PsModulesFromGit }
        }
        else
        {
            Invoke-Cleanup -ArchiveFolder $tmpArchiveName
            Write-Host "`nModule '$ModuleName' didn't change.";
        }
    }
    catch
    {
        Write-Error -ErrorRecord $_
    }
}

Export-ModuleMember Install-PSModuleGitHub,  Update-PSModuleGitHub