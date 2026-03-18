@echo off

:: 個人的に使わないUWPアプリの非表示。
for %%a in (
	Clipchamp.Clipchamp Microsoft.WindowsNotepad ^
	Microsoft.BingNews Microsoft.BingWeather Microsoft.MicrosoftOfficeHub Microsoft.MicrosoftSolitaireCollection ^
	MicrosoftTeams Microsoft.YourPhone Microsoft.Todos microsoft.windowscommunicationsapps Microsoft.ZuneMusic ^
	Microsoft.ZuneVideo Microsoft.WindowsMaps Microsoft.GetHelp Microsoft.WindowsFeedbackHub Microsoft.WindowsCamera ^
	Microsoft.WindowsSoundRecorder Microsoft.Paint Microsoft.MicrosoftStickyNotes Microsoft.OutlookForWindows ^
	Microsoft.WindowsAlarms Microsoft.WindowsCalculator Microsoft.Windows.Photos MicrosoftCorporationII.QuickAssist ^
	Microsoft.ScreenSketch Microsoft.People Microsoft.PowerAutomateDesktop Microsoft.Whiteboard Microsoft.MixedReality.Portal ^
	Microsoft.OneConnect Microsoft.Xbox.TCUI Microsoft.549981C3F5F10 MSTeams Microsoft.Copilot ^
	Microsoft.Windows.DevHome MicrosoftWindows.CrossDevice
) do (
	powershell "get-appxpackage -allusers %%a | remove-appxpackage 2>$null"
)

:: 以下は非推奨と感じたのでコメントアウト（Microsoft StoreとNVIDIAコントロールパネルは残るが、ローカルアカウント環境でUWPアプリの再インストールが不可となる）
:: echo Hide All UWP apps except NVIDIA,Intel,AMD related one and Microsoft Store, Xbox dependencies
:: powershell "get-appxpackage -allusers | where-object {$_.name -notlike '*NVIDIA*' -and $_.name -notlike '*Intel*' -and $_.name -notlike '*AMD*' -and $_.name -notlike '*Store*' -and $_.name -notlike '*Runtime*' -and $_.name -notlike '*NET.Native*' -and $_.name -notlike '*VCLibs*' -and $_.name -notlike '*UI.Xaml*' -and $_.name -notlike '*UWP*' -and $_.name -notlike '*xbox*'} | remove-appxpackage 2>$null"

timeout 1

:: Game Bar
echo Uninstalling GameBar
powershell "Get-AppxPackage -AllUsers -PackageTypeFilter Bundle -Name '*Microsoft.XboxGamingOverlay*' | Remove-AppxPackage -AllUsers 2>$null"
timeout 1
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" /t "REG_DWORD" /v "AppCaptureEnabled" /d "0" /f
timeout 1
reg add "HKCU\System\GameConfigStore" /v "GameDVR_Enabled" /t "REG_DWORD" /d "0" /f
timeout 1

:: OneDrive
echo Uninstalling OneDrive
onedrivesetup /uninstall
timeout 1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\RunNotification" /v "StartupTNotiOneDrive" /t "REG_DWORD" /d "0" /f
timeout 1
reg delete hkcu\environment /v OneDrive /f
timeout 1
:: Remove OneDrive entry from Windows 10 explorer sidebar
reg add "HKEY_CLASSES_ROOT\CLSID{018D5C66-4533-4307-9B53-224DE2ED1FE6}" /v "System.IsPinnedToNameSpaceTree" /t "REG_DWORD" /d "0" /f
timeout 1
rmdir /s /q "c:\Users\%username%\AppData\Local\Microsoft\OneDrive"
timeout 1
rmdir /s /q "c:\Users\%username%\OneDrive"
timeout 1

:: Edge
reg add "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v "BrowserSignin" /t "REG_DWORD" /d "0" /f
timeout 1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v "EnableMediaRouter" /t "REG_DWORD" /d "0" /f
timeout 1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v "DefaultBrowserSettingEnabled" /t "REG_DWORD" /d "0" /f
timeout 1
reg add "HKLM\SOFTWARE\Policies\MicrosoftEdge\Main" /v "PreventFirstRunPage" /t "REG_DWORD" /d "1" /f
timeout 1

:: Services
echo Disable telemetry 
reg add "HKLM\Software\Policies\Microsoft\Windows\DataCollection" /v "Allow telemetry" /t "REG_DWORD" /d "0" /f
timeout 1

echo Disable unnecessary Services
for %%a in (
	RasAuto Rasman RemoteAccess RemoteRegistry SessionEnv TermService UmRdpService WinRM ^
	wlidsvc NcaSvc Pcasvc SSDPSRV upnphost WMPNetworkSvc WerSvc fdPHost FDResPub ^
	MapsBroker wcncsvc NetLogon diagsvc DPS WdiServiceHost WdiSystemHost seclogon wisvc SysMain DiagTrack
) do (
	net stop %%a & timeout 1 & sc config %%a start=Disabled
	timeout 1
)
timeout 1

:: ScheduledDefrag
schtasks /change /tn \Microsoft\Windows\Defrag\ScheduledDefrag /DISABLE
timeout 1

:: OptionalFeatures
for %%a in (
	WindowsMediaPlayer WorkFolders-Client Microsoft-RemoteDesktopConnection ^
	SmbDirect MSRDC-Infrastructure MediaPlayback WCF-Services45 ^
	WCF-TCP-PortSharing45 SMB1Protocol
) do (
	powershell "disable-windowsoptionalfeature -norestart -online -featurename %%a"
	timeout 1
)
timeout 1

:: Disable SMBv1
powershell "Set-SmbServerConfiguration -EnableSMB1Protocol $false -force"
timeout 1

:: Disable SMBv2 and SMBv3
powershell "Set-SmbServerConfiguration -EnableSMB2Protocol $false -force"
timeout 1

:: Disable SMB multi channels
powershell "Set-SmbClientConfiguration -EnableMultiChannel $false -force"
timeout 1

:: Disable NetBIOS
powershell "Get-WmiObject -Class Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true } | ForEach-Object { $_.SetTcpipNetbios(2) }"
timeout 1

:: Fast Startup
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" /v "HiberbootEnabled" /t "REG_DWORD" /d "0" /f
timeout 1

:: Remote Assistant
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Remote Assistance" /v "fAllowToGetHelp" /t "REG_DWORD" /d "0" /f
timeout 1

:: Lock Screen
echo Disable Windows Spotlight
reg add "HKCU\Software\Policies\Microsoft\Windows\CloudContent" /v "DisableSpotlightCollectionOnDesktop" /t "REG_DWORD" /d "1" /f
timeout 1

echo Disable Tips on Lockscreen
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "RotatingLockScreenOverlayEnabled" /t "REG_DWORD" /d "0" /f
timeout 1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SubscribedContent-338387Enabled" /t "REG_DWORD" /d "0" /f
timeout 1

echo Removing "Home" tab in Settings App
reg add "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v "SettingsPageVisibility" /t "REG_SZ" /d "hide:home" /f
timeout 1

:: Windows Search
echo Disable Windows Search Highlights
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v "EnableDynamicContentInWSB" /t "REG_DWORD" /d "0" /f
timeout 1

:: Start Menu
echo Disable Recent Files from Start Menu
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "Start_TrackDocs" /t "REG_DWORD" /d "0" /f
timeout 1

echo Disable Recommendations in Start Menu
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "Start_IrisRecommendations" /t "REG_DWORD" /d "0" /f
timeout 1

echo Disable recommended website
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Explorer" /v "HideRecommendedPersonalizedSites" /t "REG_DWORD" /d "1" /f
timeout 1

echo Disable Account related notifications
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "Start_AccountNotifications" /t "REG_DWORD" /d "0" /f
timeout 1

echo Disable Lets finish setup your PC
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement" /v "ScoobeSystemSettingEnabled" /t "REG_DWORD" /d "0" /f
timeout 1

echo Disable Web search on start menu
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Search" /v "BingSearchEnabled" /t "REG_DWORD" /d "0" /f
timeout 1

:: Taskbar
echo Disable PC Gaming notifications
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "DisableGameNotifications" /t "REG_DWORD" /d "1" /f
timeout 1
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SoftLandingEnabled" /t "REG_DWORD" /d "0" /f
timeout 1

:: Window Decorations
echo disable window transparency 
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v "EnableTransparency" /t "REG_DWORD" /d "0" /f
timeout 1

echo move start menu to left side
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "TaskbarAl" /t "REG_DWORD" /d "0" /f
timeout 1

echo Never combine taskbar button and hide labels
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "TaskbarGlomLevel" /t "REG_DWORD" /d "2" /f
timeout 1

:: echo Use small taskbar icons
:: reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "IconSizePreference" /t "REG_DWORD" /d "0" /f
:: timeout 1

echo disable task view
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "ShowTaskViewButton" /t "REG_DWORD" /d "0" /f
timeout 1

echo Disable Taskbar Widgets
reg add "HKLM\SOFTWARE\Policies\Microsoft\Dsh" /v "AllowNewsAndInterests" /t "REG_DWORD" /d "0" /f
timeout 1

echo disable chat button
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Chat" /f
timeout 1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Chat" /v "ChatIcon" /t "REG_DWORD" /d "3" /f
timeout 1

echo disable search box
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Search" /v "SearchboxTaskbarMode" /t "REG_DWORD" /d "0" /f
timeout 1

echo Disable tablet-optimized-taskbar-in-windows-11
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "ExpandableTaskbar" /t "REG_DWORD" /d "0" /f
timeout 1

echo Disable touch keyboard
reg add "HKCU\SOFTWARE\Microsoft\TabletTip\1.7" /v "TipbandDesiredVisibility" /t "REG_DWORD" /d "0" /f
timeout 1
reg add "HKCU\SOFTWARE\Microsoft\TabletTip\1.7" /v "EnableDesktopModeAutoInvoke" /t "REG_DWORD" /d "0" /f
timeout 1
reg add "HKCU\SOFTWARE\Microsoft\TabletTip\1.7" /v "TouchKeyboardTapInvoke" /t "REG_DWORD" /d "0" /f
timeout 1

echo Disable Tablet Mode
reg add "HKLM\System\CurrentControlSet\Control\PriorityControl" /v "ConvertibilityEnabled" /t "REG_DWORD" /d "0" /f
timeout 1

:: Explorer
echo Remove Add to Favorites option on rigth-click Menu
reg add "HKEY_CLASSES_ROOT\*\shell\pintohomefile" /v "ProgrammaticAccessOnly" /t "REG_SZ" /f
timeout 1

echo Remove Ask Copilot from right-click menu
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked" /v "{CB3B0003-8088-4EDE-8769-8B354AB2FF8C}" /t "REG_SZ" /d "Ask Copilot" /f
timeout 1

echo Revert Right Click Menu
reg add "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" /f /ve
timeout 1

echo Remove Cast from Right-Click Menu
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked" /v "{7AD84985-87B4-4a16-BE58-8B72A5B390F7}" /t "REG_SZ" /f
timeout 1

echo disable frequent folders in quick access in windows11
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer" /v "ShowFrequent" /t "REG_DWORD" /d "0" /f
timeout 1

echo disable recently opend items in file explorer
reg add "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v "NoRecentDocsHistory" /t "REG_DWORD" /d "1" /f
timeout 1

echo remove quick access,home,gallery in navigation pane of file explorer
reg add "HKLM\Software\Microsoft\Windows\CurrentVersion\Explorer" /v "HubMode" /t "REG_DWORD" /d "1" /f
timeout 1
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{f874310e-b6b7-47dc-bc84-b9e6b38f5903}" /f
timeout 1
reg add "HKCU\Software\Classes\CLSID\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}" /v "System.IsPinnedToNameSpaceTree" /t "REG_DWORD" /d "0" /f
timeout 1

echo Removing Office.com files in Quick Access
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer" /v "ShowCloudFilesInQuickAccess" /t "REG_DWORD" /d "0" /f
timeout 1

echo Removing Network button on Navigation Pane in explorer 
reg add "HKCU\Software\Classes\CLSID\{F02C1A0D-BE21-4350-88B0-7367FC96EF3C}" /v "System.IsPinnedToNameSpaceTree" /t "REG_DWORD" /d "0" /f
timeout 1

echo Remove Home on explorer sidebar
reg add "HKCU\Software\Classes\CLSID\{f874310e-b6b7-47dc-bc84-b9e6b38f5903}" /v "System.IsPinnedToNameSpaceTree" /t "REG_DWORD" /d "0" /f
timeout 1

::::::::::::::::::::::::
:: My Favorite Tweaks ::
::::::::::::::::::::::::

:: Enable long paths
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\FileSystem" /v "LongPathsEnabled" /t "REG_DWORD" /d "1" /f

:: POWERCFG
echo Go sleep mode when power button is pressed
powercfg /setdcvalueindex SCHEME_CURRENT 4f971e89-eebd-4455-a8de-9e59040e7347 7648efa3-dd9c-4e3e-b566-50f929386280 1
timeout 1
powercfg /setacvalueindex SCHEME_CURRENT 4f971e89-eebd-4455-a8de-9e59040e7347 7648efa3-dd9c-4e3e-b566-50f929386280 1
timeout 1

echo disable all sleep timeouts
for %%a in (
	monitor-timeout-dc monitor-timeout-ac ^
	disk-timeout-dc disk-timeout-ac ^
	standby-timeout-ac standby-timeout-dc ^
	hibernate-timeout-ac hibernate-timeout-dc
) do (
	powercfg /change %%a 0
)
timeout 1

echo enable network standby entry in registry
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\f15576e8-98b7-4186-b944-eafa664402d9" /v "Attributes" /t "REG_DWORD" /d "2" /f
timeout 1

echo enable system cooling policy entry in registry
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\94d3a615-a899-4ac5-ae2b-e4d8f634367f" ^
/v "Attributes" /t "REG_DWORD" /d "2" /f
timeout 1

echo Disable network standby in sleep mode
powercfg /setdcvalueindex scheme_current sub_none F15576E8-98B7-4186-B944-EAFA664402D9 0
timeout 1
powercfg /setacvalueindex scheme_current sub_none F15576E8-98B7-4186-B944-EAFA664402D9 0
timeout 1

echo Setting System Cooling Policy to Active
powercfg /SETDCVALUEINDEX SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 94d3a615-a899-4ac5-ae2b-e4d8f634367f 1
timeout 1
powercfg /SETACVALUEINDEX SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 94d3a615-a899-4ac5-ae2b-e4d8f634367f 1
timeout 1

echo Setting CPU max speed
powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMAX 100
timeout 1
powercfg /setdcvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMAX 100
timeout 1

echo Setting CPU min speed
powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMIN 5
timeout 1
powercfg /setdcvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMIN 5
timeout 1

:: Taskbar
echo Enable taskkill button on taskbar
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings" /v "TaskbarEndTask" /t "REG_DWORD" /d "1" /f
timeout 1

echo Enable notification bell icons
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "ShowNotificationIcon" /t "REG_DWORD" /d "1" /f
timeout 1

:: Explorer
echo Set Startup Delay to 1sec
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize" /v "Startupdelayinmsec" /t "REG_DWORD" /d "1" /f

echo show hidden files,extension in explorer
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "Hidden" /t "REG_DWORD" /d "1" /f
timeout 1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "HideFileExt" /t "REG_DWORD" /d "0" /f
timeout 1

echo Always show full path in taskbar
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState" /v "FullPath" /t "REG_DWORD" /d "1" /f
timeout 1

echo show downloads folder when explorer is launched 
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "LaunchTo" /t "REG_DWORD" /d 3 /f
timeout 1

:: Essential Tasks

:: UpdateTailscale
schtasks /create /tn UpdateTailscale /tr "cmd.exe /c echo y | tailscale.exe update" /sc onlogon /delay 0001:00 /rl highest /f
:: timeout 1

:: UpdateUserApps
schtasks /create /tn UpdateUserApps /tr "K:\Scripts\Windows\Tasks\UpdateUserApps.bat" /sc onlogon /delay 0003:00 /f
timeout 1

:: ClearClipboard
schtasks /create /tn ClearClipboard /tr "K:\Scripts\Windows\Tasks\ClearClipboard.bat" /sc hourly /mo 1 /f
timeout 1

:: Disable ConvertibleSlateMode to turn tabletmode off
:: GPD Win Mini環境で、勝手にタブレットモードになってしまうので力技ではあるが元に戻すために設定。
schtasks /create /tn RevertSlateMode ^
  /tr "reg add HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl /v ConvertibleSlateMode /t REG_DWORD /d 1 /f" ^
  /sc onlogon /rl highest /delay 0000:30 /f
timeout 1

:: タスクスケジューラにおいて、schtasks /createで作成したタスクはデフォルトではAC電源接続時にしか実行されない設定となっている。
:: デスクトップPCであれば問題ないが、ノートパソコン、UMPCの場合、バッテリー駆動時にタスクが実行されないのでGUIで設定するためにtaskschd.msc呼び出し
echo Disable "Run tasks only when running on AC power" and "Stop tasks when power source changes to Battery power" on Conditions Tab on GUI
start taskschd.msc
pause

:: window animation config
:: ウインドウアニメーションのオンオフ設定。
:: 当初レジストリ直接操作を試したが、GUIの「適用」操作がないと正常に反映されなかったため仕方なくGUI操作。
echo Configure window animations with GUI
sysdm.cpl,3
pause

:: Networking
:: Windows Firewall
:: Block VLC Cast and Firefox telemetry
:: 必須ではなく、おまじない程度で設定。
netsh advfirewall reset
netsh advfirewall firewall add rule name="block-vlc-cast-1900-in" dir=in action=block protocol=UDP remoteport=1900 profile=any
netsh advfirewall firewall add rule name="block-vlc-cast-1900-out" dir=out action=block protocol=UDP remoteport=1900 profile=any
netsh advfirewall firewall add rule name="block-vlc-cast-5353-in" dir=in action=block protocol=UDP remoteport=5353 profile=any
netsh advfirewall firewall add rule name="block-vlc-cast-5353-out" dir=out action=block protocol=UDP remoteport=5353 profile=any
netsh advfirewall firewall add rule name="block-mozilla-telemetry-in" remoteip=34.107.134.242 dir=in action=block profile=any
netsh advfirewall firewall add rule name="block-mozilla-telemetry-out" remoteip=34.107.134.242 dir=out action=block profile=any

pause

## Restart
shutdown /r /t 0
