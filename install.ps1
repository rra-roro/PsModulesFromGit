<#
  $url = 'https://github.com/rra-roro/PsModulesFromGit/raw/main/install.ps1'

  $url = 'https://192.168.0.251:40000/my-powershell/PsModulesFromGit/-/raw/main/install.ps1'

  iex ("`$url='$url';"+(new-object net.webclient).DownloadString($url))
#>

# capture variable values
[string]$Url = Get-Variable -ValueOnly -ErrorAction SilentlyContinue Url;

function GetGroupValue($match, [string]$group, [string]$default = "") 
{
    $val = $match.Groups[$group].Value
    Write-Debug $val
    if ($val) 
    {
        return $val
    }
    return $default
}

function Convert-Url()
{
    param( [string]$Url )
    
    $githubUriRegex = "(?<Scheme>https://)(?<Host>[^/]+)/"
    $githubMatch = [regex]::Match($Url, $githubUriRegex);

    if( $(GetGroupValue $githubMatch "Host") -eq "github.com")
    {
        # Инсталируемся с github, значит с нашего внутреннего GitLab
        # https://github.com/rra-roro/PsModulesFromGit/raw/main/install.ps1
        $githubUriRegex = "(?<Scheme>https://)(?<Host>[^/]+)/(?<User>[^/]+)/(?<Repo>[^/]+)/raw/(?<Branch>[^/]+)/(?<Script>[^/]+)";

        $githubMatch = [regex]::Match($Url, $githubUriRegex);
    
        return @{
            SchemeHost = $(GetGroupValue $githubMatch "Scheme") + $(GetGroupValue $githubMatch "Host")
            Host = GetGroupValue $githubMatch "Host" 
            User = GetGroupValue $githubMatch "User"
            Repo = GetGroupValue $githubMatch "Repo"
            ModuleName = GetGroupValue $githubMatch "Repo"
            Branch = GetGroupValue $githubMatch "Branch" "main"
        }
    }
    else
    {   # Инсталируемся не с github, значит с нашего внутреннего GitLab
        # https://my-gitlab/my-powershell/PsModulesFromGit/-/raw/main/install.ps1

        $githubUriRegex = "(?<Scheme>https://)(?<Host>[^/]+)/(?<Group>[^/]+)/(?<Repo>[^/]+)/-/raw/(?<Branch>[^/]+)/(?<Script>[^/]+)"

        $githubMatch = [regex]::Match($Url, $githubUriRegex);

        return @{ 
            SchemeHost = $(GetGroupValue $githubMatch "Scheme") + $(GetGroupValue $githubMatch "Host")
            Host = GetGroupValue $githubMatch "Host"
            Group = GetGroupValue $githubMatch "Group"
            Repo = GetGroupValue $githubMatch "Repo"
            ModuleName = GetGroupValue $githubMatch "Repo"
            Branch = GetGroupValue $githubMatch "Branch" "main"
        }

    }
}

function Get-LocalTempPath 
{
    param ( [string] $RepoName )

    $tmpDir = [System.IO.Path]::GetTempPath();
    return "$tmpDir\$RepoName";
}

function Get-ModuleInstallFolder 
{
    param ( [string] $ModuleName )

    $separator = [IO.Path]::PathSeparator;

    $ProfileModulePath = $env:PSModulePath.Split($separator)[0];
    if (!(Test-Path $ProfileModulePath)) 
    {
        New-Item -ItemType Directory -Path $ProfileModulePath;
    }

    $pathToInstal = Join-Path $ProfileModulePath $ModuleName;

    if (Test-Path $pathToInstal) {
        throw "Unable to install module ''$ModuleName''. 
        Directory with the same name alredy exist in the Profile directory ''$ProfileModulePath''.
        Please rename the exisitng module folder and try again. 
        ";
    }
    return $pathToInstal;
}

function Receive-Module 
{
    param (
        [string] $Url,
        [string] $ToFile
    )

    $client = New-Object System.Net.WebClient;
    
    try
    {
        $progressEventArgs = @{
                                InputObject = $client
                                EventName = 'DownloadProgressChanged'
                                SourceIdentifier = 'ModuleDownload'
                                Action = {
                                            Write-Progress -Activity "Module Installation" -Status `
                                                            ("Downloading Module: {0} of {1}" -f $eventargs.BytesReceived, $eventargs.TotalBytesToReceive) `
                                                           -PercentComplete $eventargs.ProgressPercentage 
                                         }
                               };

        $completeEventArgs = @{
                                InputObject = $client
                                EventName = 'DownloadFileCompleted'
                                SourceIdentifier = 'ModuleDownloadCompleted'
                              };

        Register-ObjectEvent @progressEventArgs;
        Register-ObjectEvent @completeEventArgs;
    
        $client.DownloadFileAsync($Url, $ToFile);

        Wait-Event -SourceIdentifier ModuleDownloadCompleted;
    }
    catch [System.Net.WebException]  
    {  
        Write-Host("Cannot download $Url");
    } 
    finally 
    {
        $client.dispose();
        Unregister-Event -SourceIdentifier ModuleDownload;
        Unregister-Event -SourceIdentifier ModuleDownloadCompleted;
    }

    Write-Debug "Unblock downloaded file access $ToFile";
    Unblock-File -Path $ToFile;
}

function Expand-ModuleZip 
{
    param ( [string] $Archive )

    #avoid errors on already existing file
    try 
    {

        Write-Progress -Activity "Module Installation"  -Status "Unpack Module" -PercentComplete 0;
        
        Add-Type -AssemblyName System.IO.Compression.FileSystem;
        Write-Debug "Unzip file to floder $Archive";
        [System.IO.Compression.ZipFile]::ExtractToDirectory("${Archive}.zip", "${Archive}");
    }
    catch {  }

    Write-Progress -Activity "Module Installation"  -Status "Unpack Module" -PercentComplete 40;
}

function Move-ModuleFiles 
{
    param (
        [string] $ArchiveFolder,
        [string] $Module,
        [string] $DestFolder,
        [string] $ModuleHash
    )
    # Extracted zip module from GitHub 
    $path = (Resolve-Path -Path "${ArchiveFolder}\*-master\$Module").Path
    if(!$path)
    {
        # Extracted zip module from GitLab
        $path=(Resolve-Path -Path "${ArchiveFolder}\*-main\").Path
    }

    Write-Progress -Activity "Module Installation"  -Status "Store computed moduel hash" -PercentComplete 40;
    Out-File -InputObject $ModuleHash -FilePath "$path\hash" 
    
    Write-Progress -Activity "Module Installation"  -Status "Copy Module to PowershellModules folder" -PercentComplete 50;
    Move-Item -Path $path -Destination "$DestFolder"
    Remove-Item "$DestFolder\.gitattributes" -ErrorAction SilentlyContinue;
    Remove-Item "$DestFolder\.gitignore" -ErrorAction SilentlyContinue;
    Write-Progress -Activity "Module Installation"  -Status "Copy Module to PowershellModules folder" -PercentComplete 60;
}

function Invoke-Cleanup{
    param (
        [string] $ArchiveFolder
    )
    Write-Progress -Activity "Module Installation"  -Status "Finishing Installation and Cleanup " -PercentComplete 80;
    Remove-Item "${ArchiveFolder}*" -Recurse -ErrorAction SilentlyContinue;
    Write-Progress -Activity "Module Installation"  -Status "Module installed sucessaful";
}


function Write-Finish {
    param (
        [string] $moduleName
    )
    Write-Host "Module installation complete";

    Write-Host "Tupe ''Import-Module $moduleName'' to start using module";

}


$URLobj=@{}

# try convert url to fully cvalified path
if( -not [string]::IsNullOrWhitespace($Url) )
{
    $URLobj = Convert-Url -Url $Url
}
else
{
    throw [System.ArgumentException] "Incorrect `$Url variable with '$Url' value.";    
}


$host.ui.WriteLine([ConsoleColor]::Green, [ConsoleColor]::Black, "Start downloading Module '$($URLobj['ModuleName'])' from $($URLobj['SchemeHost']) Repository:$($URLobj['Repo']) Branch:$($URLobj['Branch'])")

$tmpArchiveName = $(Get-LocalTempPath -RepoName $URLobj['Repo']);
$moduleFolder = Get-ModuleInstallFolder -ModuleName $URLobj['ModuleName'];

$downloadUrl = ""

if( $URLobj['Host'] -eq "github.com")
{
    # https://github.com/rra-roro/PsModulesFromGit/archive/refs/heads/main.zip
    $downloadUrl = [uri]"$($URLobj['SchemeHost'])/$($URLobj['User'])/$($URLobj['Repo'])/archive/refs/heads/$($URLobj['Branch']).zip";
}
else
{
    # https://my-gitlab/my-powershell/PsModulesFromGit/-/archive/main/PsModulesFromGit-main.zip
    $downloadUrl = [uri]"$($URLobj['SchemeHost'])/$($URLobj['Group'])/$($URLobj['Repo'])/-/archive/$($URLobj['Branch'])/$($URLobj['ModuleName'])-$($URLobj['Branch']).zip"
}

Receive-Module -Url $downloadUrl -ToFile "${tmpArchiveName}.zip";

sleep 5

$moduleHash = Get-FileHash -Algorithm SHA384 -Path "${tmpArchiveName}.zip"

Expand-ModuleZip -Archive $tmpArchiveName;

Move-ModuleFiles -ArchiveFolder $tmpArchiveName -Module $URLobj['ModuleName'] -DestFolder $moduleFolder -ModuleHash "$($moduleHash.Hash)";
Invoke-Cleanup -ArchiveFolder $tmpArchiveName

Write-Finish -moduleName $URLobj['ModuleName']
