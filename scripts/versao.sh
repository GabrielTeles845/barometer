#!/bin/bash
# Prepara a versão para baixar: compila em release, monta o Barometer.app e o compacta em dist/.
# A versão vem do arquivo VERSAO. Publicar no GitHub é um passo à parte (ver scripts/README.md).
#
#     bash scripts/versao.sh

set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSAO="$(cat "$DIR/VERSAO")"
SAIDA="$DIR/dist"

swift build -c release --package-path "$DIR" 2>&1 | grep -E "error|Build complete" || true
BINARIO="$(swift build -c release --package-path "$DIR" --show-bin-path)/barometer"
[ -x "$BINARIO" ] || { echo "não compilou"; exit 1; }

rm -rf "$SAIDA"
mkdir -p "$SAIDA"
bash "$DIR/scripts/montar-app.sh" "$BINARIO" "$SAIDA/Barometer.app" "$VERSAO"
# ditto guarda a assinatura e os atributos do pacote; um zip comum pode estragar o .app.
ditto -c -k --keepParent "$SAIDA/Barometer.app" "$SAIDA/Barometer-$VERSAO.zip"
(cd "$SAIDA" && shasum -a 256 "Barometer-$VERSAO.zip" > "Barometer-$VERSAO.zip.sha256")
echo "pronto: $SAIDA/Barometer-$VERSAO.zip"
cat "$SAIDA/Barometer-$VERSAO.zip.sha256"
