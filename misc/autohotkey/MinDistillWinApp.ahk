#Requires AutoHotkey v2.0

; Launch Distill Desktop App for Windows
Run "C:\Users\User\AppData\Local\distill_web_monitor\distill-web-monitor.exe"

; Wait until window is opened and Hide it
WinWait "Watchlist - Distill Web Monitor"
WinHide ; Hide Distill Window