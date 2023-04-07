###################################################################################################
#
#  Библиотечные ф-ии - используемы install.ps1 для установки PsModulesFromGit, и
#                      используемы PsModulesFromGit для своей работы
#
###################################################################################################
<#
  install.ps1 - это скрипт, который содержит:
                1) ф-ию main() - котороая позволяет установить модуль PsModulesFromGit 
                   (или любой другой модуль, где есть этот install.ps1 файл в папке модуля)
                   напрямую из публичного репозитория GitHub, локального GitLab, или BitBucket
                   Ее описание, инструкцию по использованию и саму ф-ию можно найти в конце файла

                2) Так же этот скрипт содержит библиотечные ф-ии, которые 
                   используются модулем PsModulesFromGit для загрузки любых PS модулей из
                   приватных или публичных репозиториев GitHub, локального GitLab, или BitBucket
                   Для этого модуль PsModulesFromGit импортирует содержимое install.ps1 скрипта

  Библиотечные ф-ии позволяют парсить URL модулей из разных публичных и приватных репозиториев, и 
  загружать из них файлы.
  
  Примеры URL для загрузки модулей из различных репозиториев:
 
  1) публичный репозиторий GitHub
  
  2) приватный репозиторий GitHub
     

  ---------------------
     $url = "https://$MyToken@github.com/rra-roro/PsModulesFromGit/raw/main/install.ps1"
  
     iex ("`$url='$url';"+($o = [Net.WebClient]::new(); $o.Headers.Add("Authorization", "Bearer $MyToken")).DownloadString($url+"?$([DateTime]::Now.Ticks)") + "; main $MyToken")
  
#>

function GetGroupValue($match, [string]$group, [string]$default = "") 
{
    if ($githubMatch.Groups[$group].Success) 
    {
        $val = $match.Groups[$group].Value
        Write-Debug $val

        return $val
    }
    return $default
}

<#
    Конвертируем url в полностью квалифицированный путь
    Т.е. мы разрезаем url на части. И возвращаем объект с разрезаным URL
    В ностоящее время, поддерживается  github.com и локальный gitlab
#>

function Convert-UrlToURLobj
{
    param( [string]$Url )
    
    #$githubUriRegex = "(?<Scheme>https://)(?<Host>[^/]+)/"

    # token опционален, используем регулярный выражения с промаркированными группами
    $githubUriRegex = "(?<Scheme>https://)((?<Token>[^@]*)@)?(?<Host>[^/]+)/"
    $githubMatch = [regex]::Match($Url, $githubUriRegex);

    if( $(GetGroupValue $githubMatch "Host") -eq "github.com")
    {
        # Инсталируемся с github
        # https://github.com/rra-roro/PsModulesFromGit/raw/main/install.ps1
        # или
        # https://token@github.com/rra-roro/PsModulesFromGit/raw/main/install.ps1
        # или
        # https://token@github.com/rra-roro/PsModulesFromGit/tree/main/Assets

        $githubUriRegex = "(?<Scheme>https://)((?<Token>[^@]*)@)?(?<Host>[^/]+)/(?<User>[^/]+)/(?<Repo>[^/]+)/(?<TypeURL>[^/]+)/(?<Branch>[^/]+)(/(?<ScriptOrModule>[^/]*))?";

        $githubMatch = [regex]::Match($Url, $githubUriRegex);

        $URLObj = @{
                    SchemeHost = $(GetGroupValue $githubMatch "Scheme") + "api." + $(GetGroupValue $githubMatch "Host")
                    Host = GetGroupValue $githubMatch "Host" 
                    Token = GetGroupValue $githubMatch "Token"
                    User = GetGroupValue $githubMatch "User"
                    Repo = GetGroupValue $githubMatch "Repo"
                    Branch = GetGroupValue $githubMatch "Branch" "main"
                   }
        if((GetGroupValue $githubMatch "TypeURL") -eq "tree" -and  
           (GetGroupValue $githubMatch "ScriptOrModule")) 
        {
            $URLObj["ModuleName"] = GetGroupValue $githubMatch "ScriptOrModule"               
        }
        else
        {
            $URLObj["ModuleName"] = GetGroupValue $githubMatch "Repo"
        }

        return $URLObj
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

function Convert-URLobjToDownloadLink
{
    param( $URLobj )

    if( $URLobj['Host'] -eq "github.com")
    {
        # https://github.com/rra-roro/PsModulesFromGit/archive/refs/heads/main.zip
        # [uri]"$($URLobj['SchemeHost'])/$($URLobj['User'])/$($URLobj['Repo'])/archive/refs/heads/$($URLobj['Branch']).zip";
        # [uri]"https://api.github.com/repos/rra-roro/TestRepo/zipball"
        [uri]"$($URLobj['SchemeHost'])/repos/$($URLobj['User'])/$($URLobj['Repo'])/zipball/$($URLobj['Branch'])";
    }
    else
    {
        # https://my-gitlab/my-powershell/PsModulesFromGit/-/archive/main/PsModulesFromGit-main.zip
        [uri]"$($URLobj['SchemeHost'])/$($URLobj['Group'])/$($URLobj['Repo'])/-/archive/$($URLobj['Branch'])/$($URLobj['ModuleName'])-$($URLobj['Branch']).zip"
    }
}

function Add-Credentions
{
    param( $URLobj )

    if( $URLobj['Host'] -eq "github.com")
    {
        #----- GitHub private repo - token access
        # https://docs.github.com/en/rest/repos/contents?apiVersion=2022-11-28#download-a-repository-archive-zip
        # https://stackoverflow.com/questions/8377081/github-api-download-zip-or-tarball-link
        # https://stackoverflow.com/questions/9159894/download-specific-files-from-github-in-command-line-not-clone-the-entire-repo
        #
        # Не работает -> $client.Credentials = new NetworkCredential("username", "password");
        #
        # ---- О токенах ----
        # https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/about-authentication-to-github#githubs-token-formats
        # https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token#creating-a-personal-access-token-classic
        # https://docs.github.com/en/organizations/managing-programmatic-access-to-your-organization/setting-a-personal-access-token-policy-for-your-organization

        if($URLobj['Token'])
        {
            '-H', "Accept: application/vnd.github+json", '-H', "Authorization: Bearer $($URLobj['Token'])", '-H', "X-GitHub-Api-Version: 2022-11-28"
        }
    }
}

<#
    Receive-Module  - скачиваем файл пока без логина и пароля
#>

function Receive-Module 
{
    param (
        $URLobj,
        [string] $ToFile
    )

    $downloadUrl = Convert-URLobjToDownloadLink -URLobj $URLobj

    $AuthInfo = Add-Credentions -URLobj $URLobj
    
    curl @AuthInfo -Lo $ToFile $downloadUrl 


    Write-Debug "Unblock downloaded file access $ToFile";
    Unblock-File -Path $ToFile;
}

<#
    Get-LocalTempPath - возвращает имя временной папки
#>

function Get-LocalTempPath 
{
    param ( [string] $RepoName )

    $tmpDir = [System.IO.Path]::GetTempPath();
    return "$tmpDir\$RepoName";
}

<#
    Get-ModuleInstallFolder - генерирует имя папки, куда мы будем устанавливать модуль
#>

function Get-ModuleInstallFolder 
{
    param ( [string] $ModuleName )

    $separator = [IO.Path]::PathSeparator;

    # Возвращаем путь к папке с модулями, например такой путь
    #               C:\Users\roro\Documents\PowerShell\Modules
    # Реальный путь  будет зависит от платформы и версии PS

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

function Save-ModuleRepoInfo
{
    param (
        [string] $ModulePath,
        [string] $ModuleHash,
        [string] $URLobj
    )

    $URLobj | ConvertTo-Json -Depth 100 | Out-File -FilePath "$ModulePath\URLOBJ"

    $ModuleRepoInfo = new-object psobject -Property @{
                                                        ModuleName = $URLObj["ModuleName"] 
                                                        URL=$(Convert-URLobjToDownloadLink -URLobj $URLobj)
                                                        ModuleHash = $ModuleHash
                                                        Token = $URLObj["Token"] 
                                                     }

    $ModuleRepoInfo | ConvertTo-Json -Depth 100 | Out-File -FilePath "$ModulePath\ModuleRepoInfo"
}

function Move-ModuleFiles 
{
    param (
        [string] $ArchiveFolder,
        [string] $Module,
        [string] $DestFolder,
        [string] $ModuleHash,
        [string] $URLobj
    )

    # Extracted zip module from GitHub 
    $path = (Resolve-Path -Path "${ArchiveFolder}\*-*-*\$Module").Path
    if(!$path)
    {
        $path = (Resolve-Path -Path "${ArchiveFolder}\*-*-*\").Path
        if(!$path)
        {            
            # Extracted zip module from GitLab and GitHub
            $path = (Resolve-Path -Path "${ArchiveFolder}\*-*\$Module").Path 
            if(!$path)
            {
                $path = (Resolve-Path -Path "${ArchiveFolder}\*-*\").Path
            }
        }
    }

    Write-Progress -Activity "Module Installation"  -Status "Save Module Repo Info" -PercentComplete 40;
    Save-ModuleRepoInfo -ModulePath $path -ModuleHash $ModuleHash -URLobj $URLobj
    
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

function lib_main
{
    param(
        [string] $Url
    )

    $URLobj=@{}

    # try parse url to URL object
    if( -not [string]::IsNullOrWhitespace($Url) )
    {
        $URLobj = Convert-UrlToURLobj -Url $Url
    }
    else
    {
        throw [System.ArgumentException] "Incorrect `$Url variable with '$Url' value.";    
    }

    Write-Host -ForegroundColor Green "`nStart downloading Module '$($URLobj['ModuleName'])' from $($URLobj['SchemeHost'])/$($URLobj['User'])" 
    Write-Host -ForegroundColor Green "                  Repository: $($URLobj['Repo'])"
    Write-Host -ForegroundColor Green "                  Branch: $($URLobj['Branch'])"


    $tmpArchiveName = $(Get-LocalTempPath -RepoName $URLobj['Repo']);
    $moduleFolder = Get-ModuleInstallFolder -ModuleName $URLobj['ModuleName'];

    # Download module to temporary folder
    Receive-Module -URLobj $URLobj -ToFile "${tmpArchiveName}.zip";

    sleep 5

    $moduleHash = Get-FileHash -Algorithm SHA384 -Path "${tmpArchiveName}.zip"

    Expand-ModuleZip -Archive $tmpArchiveName;

    Move-ModuleFiles -ArchiveFolder $tmpArchiveName -Module $URLobj['ModuleName'] -DestFolder $moduleFolder -ModuleHash "$($moduleHash.Hash)" -URLobj $URLobj;
    Invoke-Cleanup -ArchiveFolder $tmpArchiveName

    Write-Finish -moduleName $URLobj['ModuleName']
}

###################################################################################################
#
#  Ф-ия main() - Основной код скрипта install.ps1, устанавливающая модуль PsModulesFromGit
#
###################################################################################################
<#
  install.ps1 - это скрипт, который содержит:
                1) ф-ию main() - котороая позволяет установить модуль PsModulesFromGit  
                   (или любой другой модуль, где есть этот install.ps1 файл в папке модуля)
                   напрямую из публичного репозитория GitHub, локального GitLab, или BitBucket

                2) Так же этот скрипт содержит библиотечные ф-ии, которые 
                   используются модулем PsModulesFromGit для загрузки любых PS модулей из
                   приватных или публичных репозиториев GitHub, локального GitLab, или BitBucket
                   Для этого модуль PsModulesFromGit импортирует содержимое install.ps1 скрипта
                   Описание, билиотечных ф-ий см. в начале файла install.ps1
   
  Концепция такая, что мы используем install.ps1 для установки PsModulesFromGit на локальный компьютер, а затем
  используем PsModulesFromGit для установки любого другого модуля, или обновления версии этого установленного модуля 
  напрямую из репозитория.

  Примечание: Однако, если поместить install.ps1 непосредственно в публичный репозиторий какого-либо иного модуля, то 
              это скрипт скачает и установит такой модуль.

  Примечание: мы не можем инсталировать PsModulesFromGit из приватного репозитория с помощью install.ps1 
              Поскольку для скачивания и запуска install.ps1 из репозитория мы используем выражение iex (т.е. Invoke-Expression),
              которое не может поддержать использования различных вариантов аутентификации.

              Но после установки PsModulesFromGit, этот модуль может скачивать модули из приватных репозиториев.
              Например, можно скачать модуль из приватного репозиторий с GitHub используя токен. 
              Более подробно см. описание PsModulesFromGit

  Для запуска скрипта непосредственно из публичного репозитория, нужно:
  1) создать переменную $url, где указать путь к файлу install.ps1  
  2) а затем взять комманду iex, которая является псевдоним командлета Invoke-Expression:

     iex ("`$url='$url';"+([Net.WebClient]::new()).DownloadString($url+"?$([DateTime]::Now.Ticks)") + "; main")
  
  скопировать ее вставить в PowerShell и запустить без изменений

  Например, PsModulesFromGit можно установить так:

        Из публичного репозитория GitHub:

            $url = 'https://github.com/rra-roro/PsModulesFromGit/raw/main/install.ps1'
            iex ("`$url='$url';"+([Net.WebClient]::new()).DownloadString($url+"?$([DateTime]::Now.Ticks)") + "; main")

        Из локального публичного репозитория GitLab:

            $url = 'https://192.168.0.251:40000/my-powershell/PsModulesFromGit/-/raw/main/install.ps1'
            iex ("`$url='$url';"+([Net.WebClient]::new()).DownloadString($url+"?$([DateTime]::Now.Ticks)") + "; main")
#>


function main()
{
    # capture variable values
    [string]$Url = Get-Variable -ValueOnly -ErrorAction SilentlyContinue Url;

    lib_main -Url $Url 
}