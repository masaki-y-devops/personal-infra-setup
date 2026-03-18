## This is for GPD devices
xrandr -o right

## This is for HiDPI Screen (Win Mini, MicroPC)
xrandr --output eDP-1 --dpi 138 --rate 60
# xrandr --dpi 100

## GTK Apps scaling tuning (firefox, lxterminal etc...)
# export GDK_DPI_SCALE=1.5

## wait 1 sec to take effect above changes
sleep 1

## run xmonad window manager
exec xmonad
