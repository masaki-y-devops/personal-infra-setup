<# :
@echo off

:: Check Admin privileges
:: https://blog.treedown.net/entry/2024/01/25/010000
whoami /priv | find "SeSystemtimePrivilege" > nul
if %errorlevel% neq 0 (
	echo No Administrator privileges. Aborted.
	echo Right click this script and Choose "Run as Administrator".
	pause
	exit 1
)

::::::::::::::
:: PowerCfg ::
::::::::::::::

:: Disable all sleep timeout
for %%a in (
	monitor-timeout-dc monitor-timeout-ac ^
	disk-timeout-dc disk-timeout-ac ^
	standby-timeout-ac standby-timeout-dc ^
	hibernate-timeout-ac hibernate-timeout-dc
) do (
	echo Changing %%a timeout to never...
	powercfg /change %%a 0
	timeout 1
)

:: Disable network standby in sleep mode
powercfg /setdcvalueindex scheme_current sub_none F15576E8-98B7-4186-B944-EAFA664402D9 0
timeout 1
powercfg /setacvalueindex scheme_current sub_none F15576E8-98B7-4186-B944-EAFA664402D9 0
timeout 1

:: Setting System Cooling Policy to Active
powercfg /SETDCVALUEINDEX SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 94d3a615-a899-4ac5-ae2b-e4d8f634367f 1
timeout 1
powercfg /SETACVALUEINDEX SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 94d3a615-a899-4ac5-ae2b-e4d8f634367f 1
timeout 1

:: Setting CPU max speed
powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMAX 100
timeout 1
powercfg /setdcvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMAX 100
timeout 1

:: Setting CPU min speed
powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMIN 5
timeout 1
powercfg /setdcvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMIN 5
timeout 1

:: Go sleep mode when power button is pressed
powercfg /setdcvalueindex SCHEME_CURRENT 4f971e89-eebd-4455-a8de-9e59040e7347 7648efa3-dd9c-4e3e-b566-50f929386280 1
timeout 1
powercfg /setacvalueindex SCHEME_CURRENT 4f971e89-eebd-4455-a8de-9e59040e7347 7648efa3-dd9c-4e3e-b566-50f929386280 1
timeout 1

:::::::::::::
:: regedit ::
:::::::::::::

:: show battery percentage in taskbar
:: https://www.elevenforum.com/t/enable-or-disable-show-battery-percentage-on-taskbar-in-windows-11.32691/
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "IsBatteryPercentageEnabled" /t "REG_DWORD" /d "1" /f

:: remove duplicate removable drives in explorer side bar
:: https://www.elevenforum.com/t/add-or-remove-duplicate-drives-in-navigation-pane-of-file-explorer-in-windows-11.3043/
reg add "HKCU\Software\Classes\WOW6432Node\CLSID\{F5FB2C77-0E2F-4A16-A381-3E560C68BC83}\ShellFolder" /v "Attributes" /t REG_DWORD /d 0xb0100000 /f
timeout 1
reg add "HKCU\Software\Classes\CLSID\{F5FB2C77-0E2F-4A16-A381-3E560C68BC83}\ShellFolder" /v "Attributes" /t REG_DWORD /d 0xb0100000 /f
timeout 1

:: enable sudo, inline
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Sudo" /v "Enabled" /t "REG_DWORD" /d "3" /f
timeout 1

reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" /v "HiberbootEnabled" /t "REG_DWORD" /d "0" /f
timeout 1

reg add "HKLM\SYSTEM\CurrentControlSet\Control\Remote Assistance" /v "fAllowToGetHelp" /t "REG_DWORD" /d "0" /f
timeout 1

:: Disable Windows Spotlight
reg add "HKCU\Software\Policies\Microsoft\Windows\CloudContent" /v "DisableSpotlightCollectionOnDesktop" /t "REG_DWORD" /d "1" /f
timeout 1

:: Disable Tips on Lockscreen
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "RotatingLockScreenOverlayEnabled" /t "REG_DWORD" /d "0" /f
timeout 1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SubscribedContent-338387Enabled" /t "REG_DWORD" /d "0" /f
timeout 1

:: Removing "Home" tab in Settings App
reg add "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v "SettingsPageVisibility" /t "REG_SZ" /d "hide:home" /f
timeout 1

:: Disable Windows Search Highlights
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v "EnableDynamicContentInWSB" /t "REG_DWORD" /d "0" /f
timeout 1

:: Disable Recent Files from Start Menu
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "Start_TrackDocs" /t "REG_DWORD" /d "0" /f
timeout 1

:: Disable Recommendations in Start Menu
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "Start_IrisRecommendations" /t "REG_DWORD" /d "0" /f
timeout 1

:: Disable recommended recent apps in start menu
:: https://www.elevenforum.com/t/add-or-remove-recently-added-apps-on-start-menu-in-windows-11.1157/
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Start" /v "ShowRecentList" /t "REG_DWORD" /d "0" /f
timeout 1

:: Disable recommended website
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Explorer" /v "HideRecommendedPersonalizedSites" /t "REG_DWORD" /d "1" /f
timeout 1

:: Disable Account related notifications
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "Start_AccountNotifications" /t "REG_DWORD" /d "0" /f
timeout 1

:: Disable Lets finish setup your PC
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement" /v "ScoobeSystemSettingEnabled" /t "REG_DWORD" /d "0" /f
timeout 1

:: Disable Web search on start menu
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Search" /v "BingSearchEnabled" /t "REG_DWORD" /d "0" /f
timeout 1

:: Disable PC Gaming notifications
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "DisableGameNotifications" /t "REG_DWORD" /d "1" /f
timeout 1
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SoftLandingEnabled" /t "REG_DWORD" /d "0" /f
timeout 1

:: disable window transparency 
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v "EnableTransparency" /t "REG_DWORD" /d "0" /f
timeout 1

:: move start menu to left side
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "TaskbarAl" /t "REG_DWORD" /d "0" /f
timeout 1

:: Never combine taskbar button and hide labels
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "TaskbarGlomLevel" /t "REG_DWORD" /d "2" /f
timeout 1

:: Use small taskbar icons
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "IconSizePreference" /t "REG_DWORD" /d "0" /f
timeout 1

:: disable task view
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "ShowTaskViewButton" /t "REG_DWORD" /d "0" /f
timeout 1

:: Disable Taskbar Widgets
reg add "HKLM\SOFTWARE\Policies\Microsoft\Dsh" /v "AllowNewsAndInterests" /t "REG_DWORD" /d "0" /f
timeout 1

:: disable chat button
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Chat" /f
timeout 1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Chat" /v "ChatIcon" /t "REG_DWORD" /d "3" /f
timeout 1

:: disable search box
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Search" /v "SearchboxTaskbarMode" /t "REG_DWORD" /d "0" /f
timeout 1

:: Disable tablet-optimized-taskbar-in-windows-11
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "ExpandableTaskbar" /t "REG_DWORD" /d "0" /f
timeout 1

:: Disable touch keyboard
reg add "HKCU\SOFTWARE\Microsoft\TabletTip\1.7" /v "TipbandDesiredVisibility" /t "REG_DWORD" /d "0" /f
timeout 1
reg add "HKCU\SOFTWARE\Microsoft\TabletTip\1.7" /v "EnableDesktopModeAutoInvoke" /t "REG_DWORD" /d "0" /f
timeout 1
reg add "HKCU\SOFTWARE\Microsoft\TabletTip\1.7" /v "TouchKeyboardTapInvoke" /t "REG_DWORD" /d "0" /f
timeout 1

:: Disable Tablet Mode
reg add "HKLM\System\CurrentControlSet\Control\PriorityControl" /v "ConvertibilityEnabled" /t "REG_DWORD" /d "0" /f
timeout 1

:: Remove Add to Favorites option on rigth-click Menu
reg add "HKEY_CLASSES_ROOT\*\shell\pintohomefile" /v "ProgrammaticAccessOnly" /t "REG_SZ" /f
timeout 1

:: Remove Ask Copilot from right-click menu
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked" /v "{CB3B0003-8088-4EDE-8769-8B354AB2FF8C}" /t "REG_SZ" /d "Ask Copilot" /f
timeout 1

:: Revert Right Click Menu
reg add "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" /f /ve
timeout 1

:: Remove Cast from Right-Click Menu
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked" /v "{7AD84985-87B4-4a16-BE58-8B72A5B390F7}" /t "REG_SZ" /f
timeout 1

:: disable frequent folders in quick access in windows11
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer" /v "ShowFrequent" /t "REG_DWORD" /d "0" /f
timeout 1

:: disable recently opend items in file explorer
reg add "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v "NoRecentDocsHistory" /t "REG_DWORD" /d "1" /f
timeout 1

:: remove quick access,home,gallery in navigation pane of file explorer
reg add "HKLM\Software\Microsoft\Windows\CurrentVersion\Explorer" /v "HubMode" /t "REG_DWORD" /d "1" /f
timeout 1
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{f874310e-b6b7-47dc-bc84-b9e6b38f5903}" /f
timeout 1
reg add "HKCU\Software\Classes\CLSID\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}" /v "System.IsPinnedToNameSpaceTree" /t "REG_DWORD" /d "0" /f
timeout 1

:: Removing Office.com files in Quick Access
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer" /v "ShowCloudFilesInQuickAccess" /t "REG_DWORD" /d "0" /f
timeout 1

:: Removing Network button on Navigation Pane in explorer 
reg add "HKCU\Software\Classes\CLSID\{F02C1A0D-BE21-4350-88B0-7367FC96EF3C}" /v "System.IsPinnedToNameSpaceTree" /t "REG_DWORD" /d "0" /f
timeout 1

:: Remove Home on explorer sidebar
reg add "HKCU\Software\Classes\CLSID\{f874310e-b6b7-47dc-bc84-b9e6b38f5903}" /v "System.IsPinnedToNameSpaceTree" /t "REG_DWORD" /d "0" /f
timeout 1

reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\FileSystem" /v "LongPathsEnabled" /t "REG_DWORD" /d "1" /f
timeout 1

:: enable network standby entry in registry
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\f15576e8-98b7-4186-b944-eafa664402d9" /v "Attributes" /t "REG_DWORD" /d "2" /f
timeout 1

:: enable system cooling policy entry in registry
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\94d3a615-a899-4ac5-ae2b-e4d8f634367f" ^
/v "Attributes" /t "REG_DWORD" /d "2" /f
timeout 1

:: Enable taskkill button on taskbar
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings" /v "TaskbarEndTask" /t "REG_DWORD" /d "1" /f
timeout 1

:: Enable notification bell icons
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "ShowNotificationIcon" /t "REG_DWORD" /d "1" /f
timeout 1

:: Set Startup Delay to 1sec
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize" /v "Startupdelayinmsec" /t "REG_DWORD" /d "1" /f

:: show hidden files,extension in explorer
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "Hidden" /t "REG_DWORD" /d "1" /f
timeout 1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "HideFileExt" /t "REG_DWORD" /d "0" /f
timeout 1

:: Always show full path in taskbar
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState" /v "FullPath" /t "REG_DWORD" /d "1" /f
timeout 1

:: show downloads folder when explorer is launched 
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "LaunchTo" /t "REG_DWORD" /d 3 /f
timeout 1

:: remove "ms-gamebar not found" pop-up when xinput gamepad is connected
reg add HKCR\ms-gamebar /f /ve /d URL:ms-gamebar
timeout 1
reg add HKCR\ms-gamebar /f /v "URL Protocol" /d ""
timeout 1
reg add HKCR\ms-gamebar /f /v "NoOpenWith" /d ""
timeout 1
reg add HKCR\ms-gamebar\shell\open\command /f /ve /d "\\"$env:SystemRoot\System32\systray.exe\""
timeout 1
reg add HKCR\ms-gamebarservices /f /ve /d URL:ms-gamebarservices
timeout 1
reg add HKCR\ms-gamebarservices /f /v "URL Protocol" /d ""
timeout 1
reg add HKCR\ms-gamebarservices /f /v "NoOpenWith" /d ""
timeout 1
reg add HKCR\ms-gamebarservices\shell\open\command /f /ve /d "\\"$env:SystemRoot\System32\systray.exe\""
timeout 1

:: GUI animations  
reg add "HKCU\Control Panel\Desktop\WindowMetrics" /v "MinAnimate" /t "REG_DWORD" /d "0" /f
timeout 1
reg add "HKCU\Control Panel\Desktop" /v "EnableAeroPeek" /t "REG_DWORD" /d "0" /f
timeout 1
reg add "HKCU\Control Panel\Desktop" /v "AlwaysHibernateThumbnails" /t "REG_DWORD" /d "0" /f
timeout 1
reg add "HKCU\Control Panel\Desktop" /v "DragFullWindows" /t "REG_DWORD" /d "0" /f
timeout 1
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "IconsOnly" /t "REG_DWORD" /d "0" /f
timeout 1
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "ListViewAlphaSelect" /t "REG_DWORD" /d "0" /f
timeout 1
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "ListViewShadow" /t "REG_DWORD" /d "0" /f
timeout 1
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "TaskbarAnimations" /t "REG_DWORD" /d "0" /f
timeout 1

reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" /v "VisualFXSetting" /t "REG_DWORD" /d "3" /f
timeout 1

reg add "HKCU\Control Panel\Desktop" /v "FontSmoothing" /t "REG_SZ" /d "2" /f
timeout 1
reg add "HKCU\Control Panel\Desktop" /v "FontSmoothingGamma" /t "REG_DWORD" /d "0" /f
timeout 1
reg add "HKCU\Control Panel\Desktop" /v "FontSmoothingOrientation" /t "REG_DWORD" /d "1" /f
timeout 1
reg add "HKCU\Control Panel\Desktop" /v "FontSmoothingType" /t "REG_DWORD" /d "2" /f
timeout 1
reg add "HKCU\Control Panel\Desktop" /v "UserPreferencesMask" /t "REG_BINARY" /d "9012038010000000" /f
timeout 1

:: Disable telemetry 
reg add "HKLM\Software\Policies\Microsoft\Windows\DataCollection" /v "Allow telemetry" /t "REG_DWORD" /d "0" /f
timeout 1

:: OneDrive entry
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\RunNotification" /v "StartupTNotiOneDrive" /t "REG_DWORD" /d "0" /f
timeout 1
reg delete hkcu\environment /v OneDrive /f
timeout 1
reg add "HKEY_CLASSES_ROOT\CLSID{018D5C66-4533-4307-9B53-224DE2ED1FE6}" /v "System.IsPinnedToNameSpaceTree" /t "REG_DWORD" /d "0" /f
timeout 1

:: Edge settings
reg add "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v "BrowserSignin" /t "REG_DWORD" /d "0" /f
timeout 1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v "EnableMediaRouter" /t "REG_DWORD" /d "0" /f
timeout 1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v "DefaultBrowserSettingEnabled" /t "REG_DWORD" /d "0" /f
timeout 1
reg add "HKLM\SOFTWARE\Policies\MicrosoftEdge\Main" /v "PreventFirstRunPage" /t "REG_DWORD" /d "1" /f
timeout 1

:::::::::::
:: netsh ::
:::::::::::

:: Windows Firewall

:: refresh
netsh advfirewall reset

:: Block VLC Cast and Firefox telemetry
netsh advfirewall firewall add rule name="block-vlc-cast-1900-in" dir=in action=block protocol=UDP remoteport=1900 profile=any
netsh advfirewall firewall add rule name="block-vlc-cast-1900-out" dir=out action=block protocol=UDP remoteport=1900 profile=any
netsh advfirewall firewall add rule name="block-vlc-cast-5353-in" dir=in action=block protocol=UDP remoteport=5353 profile=any
netsh advfirewall firewall add rule name="block-vlc-cast-5353-out" dir=out action=block protocol=UDP remoteport=5353 profile=any
netsh advfirewall firewall add rule name="block-mozilla-telemetry-in" remoteip=34.107.134.242 dir=in action=block profile=any
netsh advfirewall firewall add rule name="block-mozilla-telemetry-out" remoteip=34.107.134.242 dir=out action=block profile=any

:: set relatively strict rules
:: this is not for ProtonVPN-enabled environment as this rule drops WireGuard connection establishments
::netsh advfirewall firewall add rule name="allow-tcp-80-out" dir=out action=allow protocol=TCP remoteport=80 profile=any
::netsh advfirewall firewall add rule name="allow-tcp-443-out" dir=out action=allow protocol=TCP remoteport=443 profile=any
::netsh advfirewall firewall add rule name="allow-tcp-53-out" dir=out action=allow protocol=TCP remoteport=53 profile=any
::netsh advfirewall firewall add rule name="allow-udp-53-out" dir=out action=allow protocol=UDP remoteport=53 profile=any
::netsh advfirewall set allprofiles firewallpolicy blockinbound,blockoutbound
::netsh advfirewall set allprofiles settings unicastresponsetomulticast disable
::netsh advfirewall set allprofiles state on

:: log settings
::netsh advfirewall set allprofiles logging maxfilesize 4096
::netsh advfirewall set allprofiles logging droppedconnections enable

::::::::::::::
:: Services ::
::::::::::::::

:: Disable Services
for %%a in (
	lfsvc LanmanWorkstation lmhosts ^
	RasAuto Rasman RemoteAccess RemoteRegistry ^
	SessionEnv TermService UmRdpService WinRM ^
	wlidsvc NcaSvc Pcasvc SSDPSRV upnphost ^
	WMPNetworkSvc WerSvc fdPHost FDResPub ^
	MapsBroker wcncsvc NetLogon diagsvc DPS ^
	WdiServiceHost WdiSystemHost seclogon wisvc SysMain DiagTrack
) do (
	echo Stopping %%a service...
	net stop %%a & timeout 1 & sc config %%a start=Disabled
	timeout 1
)

:: Turn off Location services
:: https://www.elevenforum.com/t/enable-or-disable-location-services-in-windows-11.3003/
SystemSettingsAdminFlows.exe SetCamSystemGlobal location 0

:: configure Microsoft Store service to start it as delayed-auto
sc config InstallService start=delayed-auto

:: OptionalFeatures
for %%a in (
	WindowsMediaPlayer ^
	WorkFolders-Client ^
	Microsoft-RemoteDesktopConnection ^
	SmbDirect ^
	MSRDC-Infrastructure ^
	MediaPlayback ^
	WCF-Services45 ^
	WCF-TCP-PortSharing45 ^
	SMB1Protocol
) do (
	echo Stopping %%a optional feature...
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

::::::::::
:: Apps ::
::::::::::

:: REMOVAL
for %%a in (
	Clipchamp.Clipchamp ^
	Microsoft.Teams ^
	Microsoft.BingNews ^
	Microsoft.BingSearch ^
	Microsoft.BingWeather ^
	Microsoft.Copilot ^
	Microsoft.GamingApp ^
	Microsoft.GetHelp ^
	Microsoft.MixedReality.Portal ^
	Microsoft.OneConnect ^
	Microsoft.OutlookForWindows ^
	Microsoft.People ^
	Microsoft.Paint ^
	Microsoft.PowerAutomateDesktop ^
	Microsoft.ScreenSketch ^
	Microsoft.Todos ^
	Microsoft.Whiteboard ^
	Microsoft.YourPhone ^
	Microsoft.ZuneMusic ^
	Microsoft.ZuneVideo ^
	Microsoft.WindowsCommunicationsApps ^
	Microsoft.WindowsMaps ^
	Microsoft.WindowsFeedbackHub ^
	Microsoft.WindowsCamera ^
	Microsoft.WindowsSoundRecorder ^
	Microsoft.WindowsAlarms ^
	Microsoft.WindowsCalculator ^
	Microsoft.Windows.DevHome ^
	Microsoft.Windows.Photos ^
	MicrosoftWindows.CrossDevice ^
	Microsoft.MicrosoftOfficeHub ^
	Microsoft.MicrosoftSolitaireCollection ^
	Microsoft.MicrosoftStickyNotes ^
	MicrosoftCorporationII.MicrosoftFamily ^
	MicrosoftCorporationII.QuickAssist
) do (
	echo Uninstalling %%a...
	powershell "get-appxpackage -allusers %%a | remove-appxpackage 2>$null"
	timeout 1
)

for %%a in (
	Microsoft.Teams
) do (
	echo Uninstalling %%a...
	echo y | winget uninstall %%a
	timeout 1
)

onedrivesetup /uninstall
timeout 1
rmdir /s /q "c:\Users\%username%\AppData\Local\Microsoft\OneDrive" 2>nul
timeout 1
rmdir /s /q "c:\Users\%username%\OneDrive" 2>nul
timeout 1

:: INSTALLATION
echo y | winget upgrade --all -h --accept-source-agreements --accept-package-agreements
timeout 1

for %%a in (
	Mozilla.Firefox.ja ^
	Vivaldi.Vivaldi ^
	Neemb.Distill ^
	Dropbox.Dropbox ^
	Cryptomator.Cryptomator ^
	WinFsp.WinFsp ^
	Microsoft.VCRedist.2015+.x64 ^
	AutoHotkey.AutoHotkey ^
	7zip.7zip ^
	FreeTube.FreeTube ^
	shinchiro.mpv ^
	jurplel.qview ^
	git.git ^
	OpenJS.NodeJS
) do (
	echo Installing %%a...
	echo y | winget install %%a -h --accept-source-agreements --accept-package-agreements
	timeout 1
)

echo y | winget install Microsoft.VisualStudioCode -h --override "/verysilent /mergetasks=!runcode,addcontextmenufiles,addcontextmenufolders"
timeout 1
echo y | winget install Microsoft.VisualStudio.Community --override "--add Microsoft.VisualStudio.Workload.ManagedDesktop --includeRecommended --passive --norestart"
timeout 1

::::::::::::::
:: schtasks ::
::::::::::::::

:: Disable ScheduledDefrag
schtasks /change /tn \Microsoft\Windows\Defrag\ScheduledDefrag /DISABLE
timeout 1

:: RunWingetStoreUpgrade
schtasks /create /tn RunWingetUpgrade /tr "cmd.exe /c echo y | winget upgrade --all -h" /sc onlogon /delay 0001:00 /rl highest /f
timeout 1

:: DisableTabletMode for UMPC
schtasks /create /tn DisableTabletMode /tr "reg add HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl /v ConvertibleSlateMode /t REG_DWORD /d 1 /f" /sc onlogon /rl highest /delay 0000:30 /f
timeout 1

::::::::::::::::::::::::::::::::::::::
:: reload this script as powershell ::
::::::::::::::::::::::::::::::::::::::

powershell -noprofile -executionpolicy bypass -command "iex ([System.IO.File]::ReadAllText('%~f0', [System.Text.Encoding]::UTF8))"

exit /b
: #>

## Run store GUI app updates to ensure store CLI availability
Get-CimInstance -Namespace Root/Microsoft/Windows/TaskScheduler -ClassName MSFT_ScheduledTask -Filter 'TaskName = "ManualAppUpdate"' | Invoke-CimMethod -MethodName Run
Start-Service -Name "InstallService" -ErrorAction SilentlyContinue

## Disable Power Restrictions when running tasks
function Disable-TaskPowerRestriction ($taskName) {
    $task = Get-ScheduledTask -TaskName $taskName
    $task.Settings.DisallowStartIfOnBatteries = $false
    $task.Settings.StopIfGoingOnBatteries = $false
    Set-ScheduledTask -InputObject $task
}

## 
Disable-TaskPowerRestriction -taskName "RunWingetUpgrade"
Disable-TaskPowerRestriction -taskName "DisableTabletMode"

cmd /c pause