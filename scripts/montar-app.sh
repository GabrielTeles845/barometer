#!/bin/bash
# Monta o Barometer.app a partir do binário compilado. Usado pelo instalador e pela versão para baixar, para os
# dois saírem iguais.
#
#     bash scripts/montar-app.sh <binário> <destino>/Barometer.app <versão>

set -euo pipefail
BINARIO="$1"
APP="$2"
VERSAO="${3:-1.0}"
DIR="$(cd "$(dirname "$0")/.." && pwd)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARIO" "$APP/Contents/MacOS/barometer"
cp "$DIR/docs/icon/Barometer.icns" "$APP/Contents/Resources/"

# LSUIElement: aplicativo só de barra — sem ícone no Dock e sem janela.
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Barometer</string>
  <key>CFBundleDisplayName</key><string>Barometer</string>
  <key>CFBundleExecutable</key><string>barometer</string>
  <key>CFBundleIconFile</key><string>Barometer</string>
  <key>CFBundleIdentifier</key><string>com.gabrielteles.barometer</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSAO</string>
  <key>CFBundleVersion</key><string>$VERSAO</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# Sem assinatura o "Abrir no login" (SMAppService) não registra. Assinatura local (ad hoc), sem conta da Apple.
codesign -f -s - "$APP" >/dev/null 2>&1
codesign -v "$APP"
