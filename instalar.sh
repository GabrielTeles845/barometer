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
command -v swift >/dev/null || erro "falta o swift — rode: xcode-select --install"
[ -x /usr/sbin/lsof ] || erro "não achei o /usr/sbin/lsof"
feito "ferramentas no lugar"

passo "compilando (leva alguns segundos)"
swift build -c release --package-path "$DIR" 2>&1 | grep -E "error|Compiling|Build complete" || true
BINARIO="$(swift build -c release --package-path "$DIR" --show-bin-path)/barometer"
[ -x "$BINARIO" ] || erro "não compilou — rode 'swift build' na pasta para ver o erro"

# Fechar a versão antiga antes de trocar o binário debaixo dela.
pkill -f "barometer.app/Contents/MacOS/barometer" 2>/dev/null || true
pkill -x barometer 2>/dev/null || true
# O nome antigo ("Portas na Barra") sai: fecha e vai para a Lixeira.
pkill -x portas-barra 2>/dev/null || true
[ -d "$ANTIGO" ] && mv "$ANTIGO" "$HOME/.Trash/" 2>/dev/null || true
sleep 1

mkdir -p "$APPS"
bash "$DIR/scripts/montar-app.sh" "$BINARIO" "$APP" "$(cat "$DIR/VERSAO")" || erro "a assinatura não fechou"
feito "aplicativo montado em $APP"

open -a "$APP"
print
feito "instalado. O ícone (duas barrinhas) já deve estar na barra."
