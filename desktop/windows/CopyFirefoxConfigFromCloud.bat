:@echo off

cd /d "C:\Users\User\AppData\Roaming\Mozilla\Firefox\Profiles\*.default-release"

copy "K:\Config\Apps\Firefox\Stable\user.js" .

mkdir .\chrome

copy "K:\Config\Apps\Firefox\Stable\chrome" .\chrome
