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

echo "== 5. display name in AppInfo.xcconfig (best-effort) =="
XC="flutter/macos/Runner/Configs/AppInfo.xcconfig"
[ -f "$XC" ] && perl -i -pe 's/^PRODUCT_NAME\s*=.*/PRODUCT_NAME = Konnect Me/' "$XC" && grep -n PRODUCT_NAME "$XC" || true

echo "== branding applied =="
