@echo off

:: Networking
:: Windows Firewall
netsh advfirewall reset
netsh advfirewall firewall add rule name="block-vlc-cast-1900-in" dir=in action=block protocol=UDP remoteport=1900 profile=any
netsh advfirewall firewall add rule name="block-vlc-cast-1900-out" dir=out action=block protocol=UDP remoteport=1900 profile=any
netsh advfirewall firewall add rule name="block-vlc-cast-8080-in" dir=in action=block protocol=TCP remoteport=8080 profile=any
netsh advfirewall firewall add rule name="block-vlc-cast-8080-out" dir=out action=block protocol=TCP remoteport=8080 profile=any
netsh advfirewall firewall add rule name="block-vlc-cast-8081-in" dir=in action=block protocol=TCP remoteport=8081 profile=any
netsh advfirewall firewall add rule name="block-vlc-cast-8081-out" dir=out action=block protocol=TCP remoteport=8081 profile=any
netsh advfirewall firewall add rule name="block-mozilla-telemetry-in" remoteip=34.107.134.242 dir=in action=block profile=any
netsh advfirewall firewall add rule name="block-mozilla-telemetry-out" remoteip=34.107.134.242 dir=out action=block profile=any

pause
