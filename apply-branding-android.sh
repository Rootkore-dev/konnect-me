#!/usr/bin/env bash
# Applies Konnect Me branding to a fresh RustDesk checkout for the ANDROID build.
# Run from inside the rustdesk checkout. $1 = branding dir (holds icon png, bridge/, android/res).
# Deliberately does NOT do the macOS-only bits (sips icons) or the desktop
# scrap-bindgen workaround (Android CI uses system libclang like upstream).
set -euo pipefail
BRAND="${1:?pass branding dir}"
KEY='zOooW1iVFyb9Pz79yPuvPxPnUKYzdfUPbRuB3y9xihg='
SERVER='87.106.187.16'

echo "== 1. bake server + app name into config.rs =="
perl -0777 -i -pe "s/pub const RENDEZVOUS_SERVERS:\s*&\[&str\]\s*=\s*&\[[^\]]*\];/pub const RENDEZVOUS_SERVERS: \&[\&str] = \&[\"$SERVER\"];/" libs/hbb_common/src/config.rs
perl -0777 -i -pe "s/pub const RS_PUB_KEY:\s*&str\s*=\s*\"[^\"]*\";/pub const RS_PUB_KEY: \&str = \"$KEY\";/" libs/hbb_common/src/config.rs
perl -0777 -i -pe 's/RwLock::new\("RustDesk"\.to_owned\(\)\)/RwLock::new("Konnect Me".to_owned())/' libs/hbb_common/src/config.rs
grep -nE 'RENDEZVOUS_SERVERS|RS_PUB_KEY' libs/hbb_common/src/config.rs | head

echo "== 2. install pre-generated FFI bridge (skip generate-bridge job) =="
cp "$BRAND/bridge/generated_bridge.dart" flutter/lib/generated_bridge.dart
cp "$BRAND/bridge/generated_bridge.freezed.dart" flutter/lib/generated_bridge.freezed.dart
cp "$BRAND/bridge/bridge_generated.rs" src/bridge_generated.rs
cp "$BRAND/bridge/bridge_generated.io.rs" src/bridge_generated.io.rs
echo "bridge: dart $(wc -c < flutter/lib/generated_bridge.dart)B, rust $(wc -c < src/bridge_generated.rs)B"

echo "== 3. in-app logo (RustDesk logo -> Konnect logo) =="
for l in logo logo_light logo_dark; do
  [ -f "$BRAND/logo/$l.png" ] && cp "$BRAND/logo/$l.png" "flutter/assets/$l.png" && echo "  installed assets/$l.png"
done

echo "== 4. display string: 'Powered by RustDesk' -> 'Powered by Konnect Plus' =="
perl -0777 -i -pe 's/\("powered_by_me",\s*"[^"]*"\)/("powered_by_me", "Powered by Konnect Plus")/' src/lang/en.rs

echo "== 5. bake self-hosted console/API endpoint =="
perl -0777 -i -pe 's/let s0 = get_custom_rendezvous_server\(custom\);/let s0 = String::new(); let _ = custom;/' src/common.rs
perl -0777 -i -pe 's/"https:\/\/admin\.rustdesk\.com"\.to_owned\(\)/"https:\/\/dashboard.konnect-plus.com".to_owned()/' src/common.rs
grep -n 'dashboard.konnect-plus.com' src/common.rs | head

echo "== 6. Android app label (manifest + strings) -> Konnect Me =="
MAN=flutter/android/app/src/main/AndroidManifest.xml
perl -0777 -i -pe 's/android:label="RustDesk Input"/android:label="Konnect Me Input"/g' "$MAN"
perl -0777 -i -pe 's/android:label="RustDesk"/android:label="Konnect Me"/g' "$MAN"
STR=flutter/android/app/src/main/res/values/strings.xml
perl -0777 -i -pe 's/<string name="app_name">RustDesk<\/string>/<string name="app_name">Konnect Me<\/string>/' "$STR"
perl -0777 -i -pe 's/RustDesk screen sharing/Konnect Me screen sharing/' "$STR"
grep -nE 'android:label' "$MAN"; grep -n 'app_name' "$STR"

echo "== 7. Android launcher icons (legacy tile + adaptive foreground + navy bg) =="
RES=flutter/android/app/src/main/res
cp -f "$BRAND/android/res/mipmap-mdpi/"*.png    "$RES/mipmap-mdpi/"
cp -f "$BRAND/android/res/mipmap-hdpi/"*.png    "$RES/mipmap-hdpi/"
cp -f "$BRAND/android/res/mipmap-xhdpi/"*.png   "$RES/mipmap-xhdpi/"
cp -f "$BRAND/android/res/mipmap-xxhdpi/"*.png  "$RES/mipmap-xxhdpi/"
cp -f "$BRAND/android/res/mipmap-xxxhdpi/"*.png "$RES/mipmap-xxxhdpi/"
cp -f "$BRAND/android/res/values/ic_launcher_background.xml" "$RES/values/ic_launcher_background.xml"
echo "icons installed; bg color:"; grep -o '#[0-9A-Fa-f]*' "$RES/values/ic_launcher_background.xml"

echo "== android branding applied =="
