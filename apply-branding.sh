#!/usr/bin/env bash
# Applies Konnect Me branding to a fresh RustDesk checkout (run from inside it).
# $1 = path to the branding dir that holds konnect-me-icon.png
set -euo pipefail
BRAND="${1:?pass branding dir}"
KEY='zOooW1iVFyb9Pz79yPuvPxPnUKYzdfUPbRuB3y9xihg='
SERVER='87.106.187.16'

echo "== 1. bake server + app name into config.rs =="
perl -0777 -i -pe "s/pub const RENDEZVOUS_SERVERS:\s*&\[&str\]\s*=\s*&\[[^\]]*\];/pub const RENDEZVOUS_SERVERS: \&[\&str] = \&[\"$SERVER\"];/" libs/hbb_common/src/config.rs
perl -0777 -i -pe "s/pub const RS_PUB_KEY:\s*&str\s*=\s*\"[^\"]*\";/pub const RS_PUB_KEY: \&str = \"$KEY\";/" libs/hbb_common/src/config.rs
perl -0777 -i -pe 's/RwLock::new\("RustDesk"\.to_owned\(\)\)/RwLock::new("Konnect Me".to_owned())/' libs/hbb_common/src/config.rs
echo "config.rs:"; grep -nE 'RENDEZVOUS_SERVERS|RS_PUB_KEY|APP_NAME.*RwLock' libs/hbb_common/src/config.rs | head

echo "== 2. macOS app icons (resize our PNG into every appiconset slot) =="
ICONSET="flutter/macos/Runner/Assets.xcassets/AppIcon.appiconset"
if [ -d "$ICONSET" ]; then
  for f in "$ICONSET"/*.png; do
    # read each existing icon's pixel size and regenerate at that size from our logo
    px=$(sips -g pixelWidth "$f" | awk '/pixelWidth/{print $2}')
    [ -n "$px" ] && sips -z "$px" "$px" "$BRAND/konnect-me-icon.png" --out "$f" >/dev/null
  done
  echo "replaced $(ls "$ICONSET"/*.png | wc -l) icon files"
fi

echo "== 3. display name in AppInfo.xcconfig (best-effort) =="
XC="flutter/macos/Runner/Configs/AppInfo.xcconfig"
[ -f "$XC" ] && perl -i -pe 's/^PRODUCT_NAME\s*=.*/PRODUCT_NAME = Konnect Me/' "$XC" && grep -n PRODUCT_NAME "$XC" || true

echo "== branding applied =="
