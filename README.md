# Konnect Me — macOS build

GitHub Actions builds a branded **Konnect Me.dmg** on a macOS runner (no Mac needed).

- Source: RustDesk 1.4.9, rebranded to Konnect Me, server baked in (87.106.187.16).
- Trigger: push to `main`, or run the **Build Konnect Me macOS DMG** workflow manually (Actions tab → Run workflow).
- Output: download the **Konnect-Me-macos-aarch64** artifact (the .dmg) from the finished run.

Unsigned build (Gatekeeper: right-click → Open, or add Apple Developer signing later via secrets).
