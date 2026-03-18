export GTK_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx
export QT_IM_MODULE=fcitx

xrandr -o right
xrandr --dpi 90
sleep 1

exec xmonad
