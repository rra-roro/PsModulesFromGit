PowerShell projects code guide
==============================

-   All scripts and modules since Windows 10 are saved as UTF-8  
    (should be saved, if not, re-save the file in UTF-8)

-   Under Linux the lines end with LF  
    =\\\> !!! in Linux you have to set **core.autocrlf=input**

    In Windows the lines end with CRLF  
    =\\\> !!! on Windows you must set **core.autocrlf=true**

    Additionally in **.gitattributes**, files with platform-dependent line
    endings can be marked as:

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*.ps1   text
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

-   For Linux compatibility, add the following to the first line of your
    PowerShell scripts

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#! /usr/bin/env pwsh
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

 

 Note: In previous versions of Windows, PowerShell scripts were not
cross-platform and were saved as UTF-16. This made it necessary to put them in
Git as binary files.

 

How to get scripts from a repository in Linux format on a Windows platform to share with Linux users
====================================================================================================

Since the files in Git will be stored in LF (Linux line endings) format,  we can
get them directly from the repository by downloading them from the GitLab site
in zip or other format.

<br>Правила оформления проектов на PowerShell
=============================================

-   Все скрипты и модули начииная с Windows 10 сохраняются, как UTF-8  
    (должны быть сохранены, если это не так, нужно пересохранить файл в UTF-8)

-   В Linux строки заканчиваются LF  
    =\> !!! в Linux необходимо установить **core.autocrlf=input**

    В Windows строки заканчиваются СRLF  
    =\> !!! в Windows необходимо установить **core.autocrlf=true**

    Дополнительно в **.gitattributes**, файлы с платфоменно-зависемым окончанием
    строк можно пометить как:

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*.ps1     text
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

-   Для совместимости c Linux в первой строке PowerShell скриптов добавляем

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#! /usr/bin/env pwsh
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

 

Примечание: в прежних версиях Windows скрипты PowerShell были не
крос-платформенные и сохранялись - как UTF-16. Отчего в Git их требовалось
помещать, как бинарные файлы.

 

Как выгрузить скрипты из репозитория в Linux формате на платформе Windows, чтобы ими поделиться с Linux пользователями
======================================================================================================================

Поскольку файлы в Git  будут хранится в LF (Linux окончание строки) формате.

Мы можем взять их напрямую из репозитория выгрузив с сайта GitLab в zip или ином
формате.

 
