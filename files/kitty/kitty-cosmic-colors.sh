#!/bin/sh
# Set the kitty selection color from the COSMIC accent color
C="$HOME/.config/cosmic"
OUT="$HOME/.config/kitty/cosmic-colors.conf"
if [ "$(cat "$C/com.system76.CosmicTheme.Mode/v1/is_dark" 2>/dev/null)" = "false" ]; then
  T=Light
else
  T=Dark
fi
F="$C/com.system76.CosmicTheme.$T/v1/accent"
[ -f "$F" ] || exit 0

awk '
  /red:/   && r == "" { gsub(/[^0-9.]/, "", $2); r = $2 }
  /green:/ && g == "" { gsub(/[^0-9.]/, "", $2); g = $2 }
  /blue:/  && b == "" { gsub(/[^0-9.]/, "", $2); b = $2 }
  END {
    if (r == "" || g == "" || b == "") exit 1
    fg = (0.299*r + 0.587*g + 0.114*b > 0.6) ? "#000000" : "#ffffff"
    printf "selection_background #%02x%02x%02x\n", r*255+0.5, g*255+0.5, b*255+0.5
    printf "selection_foreground %s\n", fg
  }
' "$F" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"

pkill -USR1 -x kitty 2>/dev/null
exit 0
