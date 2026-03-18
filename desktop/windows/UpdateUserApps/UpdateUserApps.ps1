## 最後にトースト通知を出すための関数
## 参考にさせていただいたサイト: https://qiita.com/relu/items/b7121487a1d5756dfcf9
function notifyforme() {
    ## 引数を指定して、通知内容を決める。$args[0]　がタイトル、$args[1]が本文となる
    ## 使用する場合: notifyforme 'test title' 'this is a test notification'
    $headlineText = $args[0]
    $bodyText = $args[1]
    $ToastText02 = [Windows.UI.Notifications.ToastTemplateType, Windows.UI.Notifications, ContentType = WindowsRuntime]::ToastText02
    $TemplateContent = [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]::GetTemplateContent($ToastText02)
    $TemplateContent.SelectSingleNode('//text[@id="1"]').InnerText = $headlineText
    $TemplateContent.SelectSingleNode('//text[@id="2"]').InnerText = $bodyText
    $AppId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($AppId).Show($TemplateContent)
}

## 変数としてスクリプト名を事前に定義しておいた
$scriptname = "UpdateUserApps.ps1"

## インターネット接続を待機。5秒おきにチェックを繰り返し、GoogleさんのHTMLがかえってこれば接続完了とみなしループを抜ける
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

## Dropboxのデスクトップクライアントが開始するまで待機する。上記ネット接続の確認と同様に、5秒ごとに確認ループし、プロセスが立ち上がったらループを抜ける
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

## CryptomatorをWindowsのK:ドライブにマウントしているため、同ドライブ内に格納したScriptsフォルダをチェックして誤認を防止。
## これはマイルールとして他のドライブにScriptsフォルダとその直下のスクリプト群および、Execフォルダとその下のバイナリファイルを作らない、としているから機能するという認識。
write-output "#####################################################"
write-output "## Checking rclone.exe inside cryptomator vault... ##"
write-output "#####################################################"

$folders = @("Scripts","Exec")

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

## Rcloneアップデートコマンドを呼び出す。
## K:\Exec\rclone\rclone.exeが存在する前提。
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

## mpv付属のアップデート用バッチファイルを呼び出す。
## rcloneと同様、K:\Exec\mpv\updater.batが存在する前提。
write-output "#####################"
write-output "## Updating MPV... ##"
write-output "#####################"
if ( (test-path K:\Exec\mpv\mpv.exe) -eq "True") {
    powershell K:\Exec\mpv\updater.bat
} else {
    ## インストールしていない環境ではスルーでOKなのでコメントアウト。
    ## notifyforme $scriptname "MPV not found, Skipping..."
    ## cmd /c 'pause'
    ## exit 1
}

## WSLのUbuntu環境のAPTパッケージマネージャの更新スクリプトを呼び出す。なければクラウドからコピー
## スクリプト"runapt.sh"に実行権限を付与せずbashコマンドの引数として実行しているが、厳密には不適切と認識。今後の課題。
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
    ## インストールしていない環境ではスルーでOKなのでコメントアウト。
    ## notifyforme $scriptname "WSL not found, Skipping..."
    ## cmd /c 'pause'
    ## exit 1
}

## 7-zip
write-output "#######################"
write-output "## Updating 7-zip... ##"
write-output "#######################"
if ( (test-path "C:\Program Files\7-Zip\7z.exe") -eq "True" ) {
    ## 7-Zip.orgが生きているか確認
    curl.exe --max-time 5 7-zip.org
    if ( $? -eq "True" ) {
        write-output "A response from 7-zip.org is fine. Proceeding..."
    } else {
        notifyforme $scriptname "7zip site is not responding."
    }
    ## 7-zip.orgのスクレイピング結果($latest)と現在インストールしてあるバージョン($now)の比較をする。
    ## [0-9][0-9]は[0-9]{2}と同義だと学んだ。コードでは前者のほうが自分にはわかりやすいため前者のままにしておいた。
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
    ## インストールしていない環境ではスルーでOKなのでコメントアウト。
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
    ## インストールしていない環境ではスルーでOKなのでコメントアウト。
    ## notifyforme $scriptname "Python not found, Skipping..."
    ## cmd /c 'pause'
    ## exit 1
}

## 最後まで走ったことが受動的にわかるように通知を飛ばす
notifyme $scriptname "Script finished."
exit 0

## 現在未使用/autohotkey公式サイトさん側のCloudflareボット対策でcurlが動作しない可能性があるため保留、コメントアウト
## AutoHotKey
#if ( (test-path "C:\Users\User\AppData\Local\Programs\AutoHotkey") -eq "True") {
#    cd c:\Users\User\Downloads
#    curl.exe -OL https://www.autohotkey.com/download/ahk-v2.exe
#    pause
#    del c:\Users\User\Downloads\ahk-v2.exe
#} else {
#}
