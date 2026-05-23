-- for basic feature
import XMonad as X

-- for proper fullscreen behaviour (especially for freetube)
import XMonad.Hooks.EwmhDesktops

-- for xmobar support
import XMonad.Hooks.ManageDocks
import XMonad.Hooks.StatusBar
import XMonad.Hooks.StatusBar.PP

-- for keybinds
import XMonad.Util.Run
import qualified Data.Map as M
import Graphics.X11.ExtraTypes.XF86

-- for general window management
import XMonad.StackSet as W
import XMonad.Actions.Navigation2D
import XMonad.ManageHook
import XMonad.Hooks.ManageHelpers

-- for reflectVert,reflectHoriz,ResizableTall
import XMonad.Layout.Reflect

-- colors
white = "#FFFFFF"
black = "#000000"
gray = "#666666"
 
-- workspace naming
ws1 = "Home"
ws2 = "Sub"

-- bluetooth vars
btconnect = "bluetoothctl connect F0:F5:64:9F:FB:8D"
btnetwork = "dbus-send --system --type=method_call --dest=org.bluez /org/bluez/hci0/dev__F0_F5_64_9F_FB_8D org.bluez.Network1.Connect string:'nap'"
btdisconnect = "bluetoothctl disconnect F0:F5:64:9F:FB:8D"

-- other variables
mySB = statusBarProp "xmobar ~/.xmonad/xmobarrc" (pure myPP)

myPP = xmobarPP
       { ppLayout = \_ -> ""
       , ppTitle = const ""
       , ppCurrent = xmobarColor white black
       , ppHidden = xmobarColor gray black
       }

myManageHook = composeAll
    [ isDialog --> doCenterFloat
    , stringProperty "WM_WINDOW_ROLE" =? "pop-up" --> doCenterFloat
    , stringProperty "WM_WINDOW_ROLE" =? "About" --> doCenterFloat
    , stringProperty "WM_WINDOW_ROLE" =? "GtkFileChooserDialog" --> doCenterFloat
    ]

myLayout = reflectVert . reflectHoriz $ Tall 1 (3/100) (1/2)

myKeys conf@(XConfig {X.modMask = modMask}) = M.fromList $
 [ ((modMask, xK_Return), sequence_ [windows $ W.greedyView ws1, windows W.focusMaster, spawn "rofi -show run"])
 , ((modMask, xK_BackSpace), sequence_ [kill, refresh])
 , ((modMask, xK_1), windows $ W.greedyView ws1)
 , ((modMask, xK_2), windows $ W.greedyView ws2)
 , ((modMask, xK_q), sequence_ [windows $ W.shift ws1, windows $ W.greedyView ws1])
 , ((modMask, xK_w), sequence_ [windows $ W.shift ws2, windows $ W.greedyView ws2])
 , ((modMask, xK_Left), sendMessage Expand)
 , ((modMask, xK_Right), sendMessage Shrink)
 , ((0, xF86XK_AudioLowerVolume), spawn "pactl set-sink-volume @DEFAULT_SINK@ -1%")
 , ((0, xF86XK_AudioRaiseVolume), spawn "pactl set-sink-volume @DEFAULT_SINK@ +1%")
 , ((modMask, xK_u), spawn "echo `expr $(cat /sys/class/backlight/intel_backlight/brightness) - 10` > /sys/class/backlight/intel_backlight/brightness")
 , ((modMask, xK_i), spawn "echo `expr $(cat /sys/class/backlight/intel_backlight/brightness) + 10` > /sys/class/backlight/intel_backlight/brightness")
 , ((modMask, xK_n), spawn "btconnect && btnetwork")
 , ((modMask, xK_m), spawn "btdisconnect")
 ]

myMouse conf@(XConfig {X.modMask = modMask}) = M.fromList $
  [ ((modMask, button1), \w -> spawn ":")
  ]

myStartup = do
 spawn "xset s off -dpms"
 spawn "xsetroot -cursor_name left_ptr"
 spawn "fcitx5"
 spawn "feh --bg-fill ~/Wallpapers/*.{jpg,jpeg,png,webp}"
 
main = xmonad . withSB mySB . ewmhFullscreen . ewmh . docks $ def
     { modMask = mod4Mask
     , borderWidth = 0
     , normalBorderColor = black
     , focusedBorderColor = black
     , terminal = "lxterminal"
     , manageHook = myManageHook
     , layoutHook = avoidStruts $ myLayout
     , keys = myKeys
     , mouseBindings = myMouse
     , startupHook = myStartup
     , X.workspaces = [ws1,ws2]
     , focusFollowsMouse = False
     , clickJustFocuses = False
     }
