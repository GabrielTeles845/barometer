#!/bin/zsh
# Compila e instala o Barometer. Rodar de novo por cima é seguro.
#
#     zsh instalar.sh
#
# Não há conta, chave nem rede: o app pergunta ao `lsof` o que está ouvindo.

set -e
DIR="${0:a:h}"
APPS="$HOME/Applications"
APP="$APPS/Barometer.app"
ANTIGO="$APPS/Portas na Barra.app"

erro()  { print -P "%F{red}✗%f $1"; exit 1 }
passo() { print -P "%F{cyan}·%f $1" }
feito() { print -P "%F{green}✓%f $1" }

passo "conferindo as ferramentas"
command -v swiftc >/dev/null || erro "falta o swiftc — rode: xcode-select --install"
[ -x /usr/sbin/lsof ] || erro "não achei o /usr/sbin/lsof"
feito "ferramentas no lugar"

passo "compilando (leva alguns segundos)"
TEMP=$(mktemp -d)
swiftc -O -parse-as-library -o "$TEMP/barometer" "$DIR"/*.swift \
  -framework AppKit -framework IOKit -framework ServiceManagement -lIOReport

# Fechar a versão antiga antes de trocar o binário debaixo dela.
pkill -f "barometer.app/Contents/MacOS/barometer" 2>/dev/null || true
pkill -x barometer 2>/dev/null || true
# O nome antigo ("Portas na Barra") sai: fecha e vai para a Lixeira.
pkill -x portas-barra 2>/dev/null || true
[ -d "$ANTIGO" ] && mv "$ANTIGO" "$HOME/.Trash/" 2>/dev/null || true
sleep 1

mkdir -p "$APPS"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$TEMP/barometer" "$APP/Contents/MacOS/"
mkdir -p "$APP/Contents/Resources"
cp "$DIR/docs/icon/Barometer.icns" "$APP/Contents/Resources/"

# LSUIElement: aplicativo só de barra — sem ícone no Dock e sem janela.
cat > "$APP/Contents/Info.plist" <<'PLIST'
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
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# Sem assinatura o "Abrir no login" (SMAppService) não registra.
codesign -f -s - "$APP" >/dev/null 2>&1
codesign -v "$APP" 2>/dev/null || erro "a assinatura não fechou"
rm -rf "$TEMP"
feito "aplicativo montado em $APP"

open -a "$APP"
print
feito "instalado. O ícone (duas barrinhas) já deve estar na barra."
