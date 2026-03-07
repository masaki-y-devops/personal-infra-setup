<# : 
@echo off
@if not "%~0"=="%~dp0.\%~nx0" start /min cmd /c,"%~dp0.\%~nx0" %* & goto :eof
set SCRIPT_PATH=%~f0
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "&{Get-Content -Raw -Encoding UTF8 $env:SCRIPT_PATH | Invoke-Expression}"
exit /b
: #>

## Define notification functions
function notifyforme() {
    ## To set argument to notification messages, use $args[0] and $args[1]
    ## example: notifyforme 'test title' 'this is a test notification'
    $headlineText = $args[0]
    $bodyText = $args[1]
    $ToastText02 = [Windows.UI.Notifications.ToastTemplateType, Windows.UI.Notifications, ContentType = WindowsRuntime]::ToastText02
    $TemplateContent = [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]::GetTemplateContent($ToastText02)
    $TemplateContent.SelectSingleNode('//text[@id="1"]').InnerText = $headlineText
    $TemplateContent.SelectSingleNode('//text[@id="2"]').InnerText = $bodyText
    $AppId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($AppId).Show($TemplateContent)
}

## Set variables
$scriptname = "UpdateUserApps.bat"

## Wait until Internet connection is available
do {
    write-output "Checking internet connection by getting HTML from google.com..."
    curl.exe --max-time 5 https://google.com
    if ( $? -eq "True" ) {
        write-output "Internet connection found. Proceeding..."
        break
    } else {
        write-output "Internet connection not found."
        write-output "Please connect this computer to the Internet."
        write-output "Waiting 10sec and then Retrying to check..."
        start-sleep -seconds 10
    }
} while ($true)

## Wait until Cloud Storage Client starts
do {
    write-output "Checking desktop syncing app process..."
    $app = tasklist /fi "IMAGENAME eq dropbox.exe" | select-string "dropbox.exe" | % {$_.Matches.Value}
    if ( $app -eq "dropbox.exe" ) {
        write-output "desktop app found."
        ## write-output "Waiting 10s to stabilize file access..."
        ## start-sleep -seconds 10
        break
    } else {
        write-output "desktop app not found."
        write-output "Waiting 10sec and then Retrying to check..."
        start-sleep -seconds 10
    }
} while ($true)

## Find correct folders inside cryptomator vault drive
write-output "#####################################################"
write-output "## Checking rclone.exe inside cryptomator vault... ##"
write-output "#####################################################"

$folders = @("Scripts")

foreach ($i in $folders) {
    if ( (test-path K:\$i) -eq "True") {
        write-output "K:\$i found, Proceeding..."
    } else {
        write-output "K:\$i not found, Skipping..."
        write-output "Please mount drive to K: and run this script again. Exiting..."
        notifyforme $scriptname "An error occurred."
        cmd /c 'pause'
        exit 1
    }
}

## Rclone
write-output "########################"
write-output "## Updating Rclone... ##"
write-output "########################"
if ( (test-path K:\Exec\rclone\rclone.exe) -eq "True") {
    K:\Exec\rclone\rclone.exe selfupdate
} else {
    ## notifyforme $scriptname "Rclone not found, Skipping..."
    ## cmd /c 'pause'
    ## exit 1
}

## mpv
write-output "#####################"
write-output "## Updating MPV... ##"
write-output "#####################"
if ( (test-path K:\Exec\mpv\mpv.exe) -eq "True") {
    powershell K:\Exec\mpv\updater.bat
} else {
    ## notifyforme $scriptname "MPV not found, Skipping..."
    ## cmd /c 'pause'
    ## exit 1
}

## WSL
write-output "#####################"
write-output "## Updating WSL... ##"
write-output "#####################"
write-output "Checking current installation status..."
wsl --version
if ( $? -eq "True" ) {
    write-output "WSL installation found."
    if ( (test-path "C:\Users\User\usrlocalbin\runapt.sh") -eq "True" ) {
        write-output "Update scripts found. Proceeding..."
    } else {
        write-output "Update scripts not found, Creating usrlocalbin directory and Copying runapt.sh into it from Cloud..."
        mkdir C:\Users\User\usrlocalbin
        cp K:\Scripts\Windows\WSL\runapt.sh C:\Users\User\usrlocalbin
    }
    write-output "Running APT..."
    wsl -e bash /mnt/c/Users/User/usrlocalbin/runapt.sh
} else {
    ## notifyforme $scriptname "WSL not found, Skipping..."
    ## cmd /c 'pause'
    ## exit 1
}

## 7-zip
write-output "#######################"
write-output "## Updating 7-zip... ##"
write-output "#######################"
if ( (test-path "C:\Program Files\7-Zip\7z.exe") -eq "True" ) {
    ## check 7-zip.org availability
    curl.exe --max-time 5 7-zip.org
    if ( $? -eq "True" ) {
        write-output "A response from 7-zip.org is fine. Proceeding..."
    } else {
        notifyforme $scriptname "7zip site is not responding."
        ## exit 1
    }
    ## get latest version and current 7-Zip version.
    ## [0-9][0-9] is equivalent to [0-9]{2}
    $latest = curl.exe -s https://7-zip.org | select-string '7-Zip\s+[0-9][0-9]\.[0-9][0-9]' | % { $_.Matches.Value } | select-object -first 1 | % { $_.split(' ')[1] } | % { $_.replace('.','') }
    $now = & 'C:\Program Files\7-Zip\7z.exe' | select-string '7-Zip\s+[0-9][0-9]\.[0-9][0-9]' | % { $_.Matches.Value } | select-object -first 1 | % { $_.split(' ')[1] } | % { $_.replace('.','') }
    
    if ( $latest -ne $now ) {
        write-output "A Update version, ${latest} found. Updating from ${now} to ${latest}..."
        curl.exe -OL https://www.7-zip.org/a/7z${latest}-x64.exe; ${updater} = "7z${latest}-x64.exe" ;& .\${updater}
        write-output "Waiting for user actions to complete updates..."
        cmd /c 'pause'
        remove-item -force .\${updater}
    } else {
        write-output "A already installed version, ${now} is latest. No need to update."
    }
} else {
    ## notifyforme $scriptname "7Zip not found, Skipping..."
    ## cmd /c 'pause'
    ## exit 1
}

## pip
write-output "#####################"
write-output "## Updating pip... ##"
write-output "#####################"
if ( (test-path "C:\Users\User\AppData\Local\Python\pythoncore-*\python.exe") -eq "True" ) {
    write-output "Python installation found. Updating pip..."
    python -m pip install --upgrade pip
} else {
    ## notifyforme $scriptname "Python not found, Skipping..."
    ## cmd /c 'pause'
    ## exit 1
}

notifyme $scriptname "Script finished."
exit 0

## AutoHotKey
#if ( (test-path "C:\Users\User\AppData\Local\Programs\AutoHotkey") -eq "True") {
#    cd c:\Users\User\Downloads
#    curl.exe -OL https://www.autohotkey.com/download/ahk-v2.exe
#    pause
#    del c:\Users\User\Downloads\ahk-v2.exe
#} else {
#}
