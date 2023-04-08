PsModulesFromGit is PS module installer from GitHub
===================================================

Обзор
-----

This repository contain fork
[FromGithub](https://github.com/PsModuleInstall/FromGithub) repo.

Этот репозиторий содержит PS модуль **PsModulesFromGit**, который позволяет
напрямую устанавливать любой другой модуль из приватного или публичного
репозитория GitHub, а также обновлять ранее установленный с помощью
**PsModulesFromGit** модуль, если он изменился на GitHub.

 

Установка PsModulesFromGit 
---------------------------

Чтобы установить **PsModulesFromGit** из этого репозитория нужно выполнить два
шага:

1.  Сначало зададим путь к `install.ps1` скрипту установки

```PowerShell
$url = 'https://github.com/rra-roro/PsModulesFromGit/raw/main/install.ps1'
```

1.  Затем выполним такую команду, которая скачает скрипт установки, запустит
    его, и скрипт `install.ps1` установить модуль **PsModulesFromGit**

```PowerShell
iex ("`$url='$url';"+([Net.WebClient]::new()).DownloadString($url+"?$([DateTime]::Now.Ticks)") + "; main"):
```

 
Как использовать PsModulesFromGit 
----------------------------------

### Импорт модуля

После установки **PsModulesFromGit** модуля его нужно импортировать для начала
работы с ним в текущей сесси PS:

```PowerShell
Import-Module PsModulesFromGit
```
 
### Команда установки модулей Install-PSModuleGitHub

Для установки какого либо модуля непосредствено из репозитория GitHub необходимо
вызвать команду **Install-PSModuleGitHub**  

>   **Install-PSModuleGitHub** -URL *\<url-module-repo\>*
>   [-Branch] *\<Repository branch\>*
>   [-ModulePath] *\<Module name (Folder in Repository)\>*
>   [-Token] *\<Personal access Token\>*
 

Рассмотрим параметры:

**-URL**

Обязательный параметр задает GitHub URL к репозиторию с устанавливаемым модулем,
URL задается в формате:

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
https://github.com/<user-name>/<repo-name>
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**-Branch**

Необязательный параметр задает имя ветки в репозитории из которой будет
устанавливаться модуль.

Если параметр не задан, по умолчанию используется ветка `main`

**-ModulePath**

Необязательный параметр. В том случае, если в репозитории, содержатся сразу
несколько модулей, задает подпапку в которой, находится устанавливаемый модуль,
относительно корня репозитория.

**-Token**

Необязательный параметр. Необходим, если мы устанавливаем модуль из приватного
репозитория. Более подробно о формате токена и как его получить смотрите [тут
Private Repo Token](PrivateRepoToken.md).


*Примеры:*

Установка модуля из публичного репозитория из ветки `master`:

```PowerShell
Install-PSModuleGitHub -Url https://github.com/dfinke/ImportExcel -Branch master
```

Установка модуля из приватного репозитория

```PowerShell
Install-PSModuleGitHub -Url https://github.com/rra-roro/TestRepo -Token 'github_pat_.....'
```

### Команда обновления модулей Update-PSModuleGitHub

Для обновления ранее установленных модулей необходимо вызвать команду
**Update-PSModuleGitHub**

>   Update-PSModuleGitHub *\<Name of the module to be updated\>*  
>   

*Пример:*

```PowerShell
Update-PSModuleGitHub PsModulesFromGit
```
