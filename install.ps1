﻿###################################################################################################
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

function GetGroupValue
{
    [cmdletBinding()]
    param($match, [string]$group, [string]$default = "") 

    try
    {
        if ($githubMatch.Groups[$group].Success) 
        {
            $val = $match.Groups[$group].Value
            Write-Debug $val

            return $val
        }
        return $default
    }
    catch
    {
        Write-Error -Exception ([Exception]::new("Error in GetGroupValue(): $($_.Exception.Message) ", $_.Exception))
    }
}

<#
    Конвертируем url в полностью квалифицированный путь
    Т.е. мы разрезаем url на части. И возвращаем объект с разрезаным URL
    В ностоящее время, поддерживается  github.com и локальный gitlab
#>

function Convert-UrlToURLobj
{
    [cmdletBinding()]
    param( [string]$Url )

    try
    {    
        #$githubUriRegex = "(?<Scheme>https://)(?<Host>[^/]+)/"

        # token опционален, используем регулярный выражения с промаркированными группами
        $githubUriRegex = "(?<Scheme>https://)((?<Token>[^@]*)@)?(?<Host>[^/]+)/"
        $githubMatch = [regex]::Match($Url, $githubUriRegex);

        if( $(GetGroupValue $githubMatch "Host" -ErrorAction Stop) -eq "github.com")
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
                        SchemeHost = $(GetGroupValue $githubMatch "Scheme" -ErrorAction Stop) + "api." + $(GetGroupValue $githubMatch "Host" -ErrorAction Stop)
                        Host = GetGroupValue $githubMatch "Host" -ErrorAction Stop
                        Token = GetGroupValue $githubMatch "Token" -ErrorAction Stop
                        User = GetGroupValue $githubMatch "User" -ErrorAction Stop
                        Repo = GetGroupValue $githubMatch "Repo" -ErrorAction Stop
                        Branch = GetGroupValue $githubMatch "Branch" "main" -ErrorAction Stop
                       }
            if((GetGroupValue $githubMatch "TypeURL" -ErrorAction Stop) -eq "tree" -and  
               (GetGroupValue $githubMatch "ScriptOrModule" -ErrorAction Stop)) 
            {
                $URLObj["ModuleName"] = GetGroupValue $githubMatch "ScriptOrModule" -ErrorAction Stop               
            }
            else
            {
                $URLObj["ModuleName"] = GetGroupValue $githubMatch "Repo" -ErrorAction Stop
            }

            return $URLObj
        }
        else
        {   # Инсталируемся не с github, значит с нашего внутреннего GitLab
            # https://my-gitlab/my-powershell/PsModulesFromGit/-/raw/main/install.ps1

            $githubUriRegex = "(?<Scheme>https://)(?<Host>[^/]+)/(?<Group>[^/]+)/(?<Repo>[^/]+)/-/raw/(?<Branch>[^/]+)/(?<Script>[^/]+)"

            $githubMatch = [regex]::Match($Url, $githubUriRegex);

            return @{ 
                SchemeHost = $(GetGroupValue $githubMatch "Scheme" -ErrorAction Stop) + $(GetGroupValue $githubMatch "Host" -ErrorAction Stop)
                Host = GetGroupValue $githubMatch "Host" -ErrorAction Stop
                Group = GetGroupValue $githubMatch "Group" -ErrorAction Stop
                Repo = GetGroupValue $githubMatch "Repo" -ErrorAction Stop
                ModuleName = GetGroupValue $githubMatch "Repo" -ErrorAction Stop
                Branch = GetGroupValue $githubMatch "Branch" "main" -ErrorAction Stop
            }

        }
    }
    catch
    {
        Write-Error -Exception ([Exception]::new("Error in Convert-UrlToURLobj(): $($_.Exception.Message) ", $_.Exception))
    }
}

function Convert-URLobjToDownloadLink
{
    [cmdletBinding()]
    param( $URLobj )

    try
    {
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
    catch
    {
        Write-Error -Exception ([Exception]::new("Error in Convert-URLobjToDownloadLink(): $($_.Exception.Message) ", $_.Exception))    
    }
}

function Add-Credentions
{
    [cmdletBinding()]
    param( $URLobj )

    try
    {
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
    catch
    {
        Write-Error -Exception ([Exception]::new("Error in Add-Credentions(): $($_.Exception.Message) ", $_.Exception))  
    }
}

<#
    Receive-Module  - скачиваем файл пока без логина и пароля
#>

function Receive-Module 
{
    [cmdletBinding()]
    param (
        $URLobj,
        [string] $ToFile
    )

    try
    {
        $downloadUrl = Convert-URLobjToDownloadLink -URLobj $URLobj -ErrorAction Stop

        $AuthInfo = Add-Credentions -URLobj $URLobj -ErrorAction Stop
    
        curl @AuthInfo -Lo $ToFile $downloadUrl

        
        if($isWindows) 
        { 
            Write-Debug "Unblock downloaded file access $ToFile";
            Unblock-File -Path $ToFile -ErrorAction Stop; 
        }
    }
    catch
    {
        Write-Error -Exception ([Exception]::new("Error in Receive-Module(): $($_.Exception.Message) ", $_.Exception))  
    }
}

<#
    Get-LocalTempPath - возвращает имя временной папки
#>

function Get-LocalTempPath 
{
    [cmdletBinding()]
    param ( [string] $RepoName )

    try
    {
        $tmpDir = [System.IO.Path]::GetTempPath();
        return "$tmpDir/$RepoName";
    }
    catch
    {
        Write-Error -Exception ([Exception]::new("Error in Get-LocalTempPath(): $($_.Exception.Message) ", $_.Exception))
    }
}

<#
    Get-ModuleInstallFolder - генерирует имя папки, куда мы будем устанавливать модуль
#>

function Get-ModuleInstallFolder 
{
    [cmdletBinding()]
    param ( [string] $ModuleName )

    try
    {
        $separator = [IO.Path]::PathSeparator;

        # Возвращаем путь к папке с модулями, например такой путь
        #               C:\Users\roro\Documents\PowerShell\Modules
        # Реальный путь  будет зависит от платформы и версии PS

        $ProfileModulePath = $env:PSModulePath.Split($separator)[0];
        if (!(Test-Path $ProfileModulePath)) 
        {
            New-Item -ItemType Directory -Path $ProfileModulePath -ErrorAction Stop;
        }

        $pathToInstall = Join-Path $ProfileModulePath $ModuleName -ErrorAction Stop;

        if (Test-Path $pathToInstall -ErrorAction SilentlyContinue) {
            throw "Unable to install module ''$ModuleName''.`n
Directory with the same name alredy exist in the Profile directory ''$ProfileModulePath''.`n
Please rename the exisitng module folder and try again.";
        }
        return $pathToInstall;
    }
    catch
    {
        Write-Error -Exception ([Exception]::new("Error in Get-ModuleInstallFolder(): $($_.Exception.Message) ", $_.Exception))
    }
}

function Expand-ModuleZip 
{
    [cmdletBinding()]
    param ( [string] $Archive )

    #avoid errors on already existing file
    try 
    {

        Write-Progress -Activity "Module Installation"  -Status "Unpack Module" -PercentComplete 0;
        
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop;
        Write-Debug "Unzip file to floder $Archive";
        [System.IO.Compression.ZipFile]::ExtractToDirectory("${Archive}.zip", "${Archive}");

        Write-Progress -Activity "Module Installation"  -Status "Unpack Module" -PercentComplete 40;
    }
    catch 
    { 
        Write-Error -Exception ([Exception]::new("Error extract file ${Archive}.zip: $($_.Exception.Message) ", $_.Exception))     
    }
}

function Save-ModuleRepoInfo
{
    [cmdletBinding()]
    param (
        [string] $ModulePath,
        [string] $ModuleHash,
        $URLobj
    )

    try
    {
        $ModuleRepoInfo = new-object psobject -Property @{
                                                            URLobj = $URLobj
                                                            ModuleHash = $ModuleHash
                                                         } -ErrorAction Stop

        $ModuleRepoInfo | ConvertTo-Json -Depth 100 -ErrorAction Stop | Out-File -FilePath "$ModulePath\ModuleRepoInfo" -ErrorAction Stop
    }
    catch
    {
        Write-Error -Exception ([Exception]::new("Error in Save-ModuleRepoInfo(): $($_.Exception.Message) ", $_.Exception)) 
    }
}

function Move-ModuleFiles 
{
    [cmdletBinding()]    
    param (
        [string] $ArchiveFolder,
        [string] $Module,
        [string] $DestFolder,
        [string] $ModuleHash,
        $URLobj
    )

    try
    {
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
        Save-ModuleRepoInfo -ModulePath $path -ModuleHash $ModuleHash -URLobj $URLobj -ErrorAction Stop
    
        Write-Progress -Activity "Module Installation"  -Status "Copy Module to PowershellModules folder" -PercentComplete 50;
        Move-Item -Path $path -Destination "$DestFolder" -ErrorAction Stop
        Remove-Item "$DestFolder\.gitattributes" -ErrorAction SilentlyContinue;
        Remove-Item "$DestFolder\.gitignore" -ErrorAction SilentlyContinue;
        Write-Progress -Activity "Module Installation"  -Status "Copy Module to PowershellModules folder" -PercentComplete 60;
    }
    catch
    {
        Write-Error -Exception ([Exception]::new("Error in Move-ModuleFiles(): $($_.Exception.Message) ", $_.Exception)) 
    }
}

function Invoke-Cleanup
{
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

    Write-Host "Tupe 'Import-Module $moduleName' to start using module";

    Write-Progress -Activity "Module Installation" -Completed;
}

function lib_main
{
    [cmdletBinding()]    
    param(
        [string] $Url
    )
    try
    {
        $URLobj=@{}

        # try parse url to URL object
        if( -not [string]::IsNullOrWhitespace($Url) )
        {
            $URLobj = Convert-UrlToURLobj -Url $Url -ErrorAction Stop
            $URLobj['OriginalUrl'] = $Url
        }
        else
        {
            throw [System.ArgumentException] "Incorrect `$Url variable with '$Url' value.";    
        }

        Write-Host -ForegroundColor Green "`nStart downloading Module '$($URLobj['ModuleName'])' from $($URLobj['SchemeHost'])/$($URLobj['User'])" 
        Write-Host -ForegroundColor Green "                  Repository: $($URLobj['Repo'])"
        Write-Host -ForegroundColor Green "                  Branch: $($URLobj['Branch'])"


        $tmpArchiveName = $(Get-LocalTempPath -RepoName $URLobj['Repo'] -ErrorAction Stop);
        $moduleFolder = Get-ModuleInstallFolder -ModuleName $URLobj['ModuleName'] -ErrorAction Stop;

        # Download module to temporary folder
        Receive-Module -URLobj $URLobj -ToFile "${tmpArchiveName}.zip" -ErrorAction Stop;

        sleep 5

        $moduleHash = Get-FileHash -Algorithm SHA384 -Path "${tmpArchiveName}.zip" -ErrorAction Stop

        try
        {
            Expand-ModuleZip -Archive $tmpArchiveName -ErrorAction Stop

            Move-ModuleFiles -ArchiveFolder $tmpArchiveName -Module $URLobj['ModuleName'] -DestFolder $moduleFolder -ModuleHash "$($moduleHash.Hash)" -URLobj $URLobj -ErrorAction Stop;
            Invoke-Cleanup -ArchiveFolder $tmpArchiveName

            Write-Finish -moduleName $URLobj['ModuleName']
        }
        catch
        {
            if($URLobj['Token'] -eq "")
            {
                throw [Exception]::new("You are probably downloading a file from a private repository without specifying a token. Set the token and try again: $($_.Exception.Message) ", $_.Exception)
            }
            else
            {
                throw [Exception]::new("Bad Archive: $($_.Exception.Message) ", $_.Exception)
            }
        }
    }
    catch
    {
        Write-Error -Exception ([Exception]::new("Error in lib_main(): $($_.Exception.Message) ", $_.Exception))
    }
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
    [string]$Url = Get-Variable Url -ValueOnly -ErrorAction SilentlyContinue;

    lib_main -Url $Url 

    Remove-Item Function:GetGroupValue
    Remove-Item Function:Convert-UrlToURLobj
    Remove-Item Function:Convert-URLobjToDownloadLink
    Remove-Item Function:Add-Credentions
    Remove-Item Function:Receive-Module
    Remove-Item Function:Get-LocalTempPath 
    Remove-Item Function:Get-ModuleInstallFolder
    Remove-Item Function:Expand-ModuleZip
    Remove-Item Function:Save-ModuleRepoInfo
    Remove-Item Function:Move-ModuleFiles 
    Remove-Item Function:Invoke-Cleanup
    Remove-Item Function:Write-Finish
    Remove-Item Function:lib_main
    Remove-Item Function:main 
}

