@echo off

:: DNS over HTTPS
echo Setting DoH HTTP Address to use...
powershell "add-dnsclientdohserveraddress -serveraddress "94.140.14.14" -dohtemplate 'https://dns.adguard-dns.com/dns-query' -allowfallbacktoudp $false -autoupgrade $true"
powershell "add-dnsclientdohserveraddress -serveraddress "94.140.15.15" -dohtemplate 'https://dns.adguard-dns.com/dns-query' -allowfallbacktoudp $false -autoupgrade $true"
powershell "add-dnsclientdohserveraddress -serveraddress "2a10:50c0::ad1:ff" -dohtemplate 'https://dns.adguard-dns.com/dns-query' -allowfallbacktoudp $false -autoupgrade $true"
powershell "add-dnsclientdohserveraddress -serveraddress "2a10:50c0::ad2:ff" -dohtemplate 'https://dns.adguard-dns.com/dns-query' -allowfallbacktoudp $false -autoupgrade $true"

:: Control-D Social (Malware + Ads,Tracking + Social Networks) Blocking
:: powershell "add-dnsclientdohserveraddress -serveraddress "76.76.2.3" -dohtemplate 'https://freedns.controld.com/p3' -allowfallbacktoudp $false -autoupgrade $true"
:: powershell "add-dnsclientdohserveraddress -serveraddress "76.76.10.3" -dohtemplate 'https://freedns.controld.com/p3' -allowfallbacktoudp $false -autoupgrade $true"
:: powershell "add-dnsclientdohserveraddress -serveraddress "2606:1a40::3" -dohtemplate 'https://freedns.controld.com/p3' -allowfallbacktoudp $false -autoupgrade $true"
:: powershell "add-dnsclientdohserveraddress -serveraddress "2606:1a40:1::3" -dohtemplate 'https://freedns.controld.com/p3' -allowfallbacktoudp $false -autoupgrade $true"

echo Writing SetAdguardDoH.ps1 to C:\userlocalbin and Running schtasks to make it permanent...
mkdir C:\usrlocalbin
(echo $ifnumber=get-netadapter ^| where-object name -ne 'Tailscale' ^| select-object -expandproperty ifIndex) >> C:\usrlocalbin\SetAdguardDoH.ps1
echo foreach ^(^$i in ^$ifnumber) ^{ set-dnsclientserveraddress -interfaceindex ^$i -serveraddresses '94.140.14.14','94.140.15.15','2a10:50c0::ad1:ff','2a10:50c0::ad2:ff' ^} >> C:\usrlocalbin\SetAdguardDoH.ps1
schtasks /create /tn SetAdguardDoH /tr "powershell.exe -WindowStyle minimized C:\usrlocalbin\SetAdguardDoH.ps1" /sc onlogon /delay 0000:10 /ru system /f

:: disable powersave
echo Disable "Run tasks only when running on AC power" and "Stop tasks when power source changes to Battery power" on Conditions Tab on GUI
start taskschd.msc

echo Running ForceDoH.ps1 initially...
powershell "set-executionpolicy remotesigned"
powershell "C:\usrlocalbin\SetAdguardDoH.ps1"

echo Displaying current settings...
powershell "$dev=get-netadapter | where-object name -ne 'Tailscale' | select-object -expandproperty ifIndex; foreach ($i in $dev) { get-dnsclientserveraddress -interfaceindex $i }"
pause
