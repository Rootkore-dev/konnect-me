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

echo "== 3. install pre-generated FFI bridge (avoids frb+libclang on the runner) =="
cp "$BRAND/bridge/generated_bridge.dart" flutter/lib/generated_bridge.dart
# freezed part file (build_runner output) that generated_bridge.dart depends on
cp "$BRAND/bridge/generated_bridge.freezed.dart" flutter/lib/generated_bridge.freezed.dart
mkdir -p flutter/macos/Runner
cp "$BRAND/bridge/bridge_generated.h" flutter/macos/Runner/bridge_generated.h
# Rust half of the FFI bridge (generated, not committed): main + native-io include
cp "$BRAND/bridge/bridge_generated.rs" src/bridge_generated.rs
cp "$BRAND/bridge/bridge_generated.io.rs" src/bridge_generated.io.rs
echo "bridge: dart $(wc -c < flutter/lib/generated_bridge.dart)B, rust $(wc -c < src/bridge_generated.rs)B + io $(wc -c < src/bridge_generated.io.rs)B"

echo "== 4. install pre-generated scrap bindings + skip bindgen (no libclang dependency) =="
mkdir -p libs/scrap/generated
cp "$BRAND/scrap-generated/aom_ffi.rs" libs/scrap/generated/aom_ffi.rs
cp "$BRAND/scrap-generated/vpx_ffi.rs" libs/scrap/generated/vpx_ffi.rs
cp "$BRAND/scrap-generated/yuv_ffi.rs" libs/scrap/generated/yuv_ffi.rs
# make gen_vcpkg_package copy the committed binding instead of running bindgen
perl -0777 -i -pe 's/generate_bindings\(&ffi_header, &includes, &ffi_rs, &exact_file, regex\);/if exact_file.exists() { std::fs::copy(&exact_file, &ffi_rs).unwrap(); } else { generate_bindings(&ffi_header, &includes, &ffi_rs, &exact_file, regex); }/g' libs/scrap/build.rs
echo "build.rs patched:"; grep -n 'exact_file.exists' libs/scrap/build.rs | head

echo "== 5. display name: do NOT change PRODUCT_NAME here =="
# build.py hardcodes 'RustDesk.app' and Xcode dislikes spaces in PRODUCT_NAME,
# so we keep the build name as RustDesk and rename the bundle to 'Konnect Me'
# AFTER the build (done in the DMG workflow step, incl. CFBundleName).
echo "(kept PRODUCT_NAME=RustDesk; renamed post-build)"

echo "== 6. in-app logo (RustDesk logo -> Konnect logo) =="
for l in logo logo_light logo_dark; do
  [ -f "$BRAND/logo/$l.png" ] && cp "$BRAND/logo/$l.png" "flutter/assets/$l.png" && echo "  installed assets/$l.png"
done

echo "== 7. display strings: 'Powered by RustDesk' -> 'Powered by Konnect Plus' =="
perl -0777 -i -pe 's/\("powered_by_me",\s*"[^"]*"\)/("powered_by_me", "Powered by Konnect Plus")/' src/lang/en.rs
grep -n 'powered_by_me' src/lang/en.rs | head -1

echo "== 8. bake self-hosted console/API endpoint (login on our own site) =="
# default api-server (unset by user) resolves to our HTTPS portal instead of http://<ip>:21114
perl -0777 -i -pe 's/let s0 = get_custom_rendezvous_server\(custom\);/let s0 = String::new(); let _ = custom;/' src/common.rs
perl -0777 -i -pe 's/"https:\/\/admin\.rustdesk\.com"\.to_owned\(\)/"https:\/\/dashboard.konnect-plus.com".to_owned()/' src/common.rs
echo "api-server bake:"; grep -n 'me.konnect-plus.com\|String::new(); let _ = custom' src/common.rs | head

echo "== branding applied =="
