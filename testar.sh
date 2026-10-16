#!/bin/bash
# Roda os testes. Use este em vez do `swift test` puro:
#
#     bash testar.sh            # todos
#     bash testar.sh Portas     # só uma suíte (o nome ou parte dele)
#
# Com só as ferramentas de linha de comando da Apple (sem Xcode), a primeira compilação dos testes depois de
# mudar o app às vezes perde as macros do Swift Testing ("plugin for module 'TestingMacros' not found"); a
# segunda passa. Então, se der exatamente esse erro, apaga só o que é dos testes e roda de novo, uma vez.
# Qualquer outro erro sai na hora. No CI, com o Xcode, isso não acontece.
set -o pipefail
cd "$(dirname "$0")"
TESTES=.build/out/Intermediates.noindex/Barometer.build/Debug/BarometerKitTests-p.build
SAIDA=$(mktemp)
trap 'rm -f "$SAIDA"' EXIT

rodar() {
  rm -rf "$TESTES"
  if [ -n "$1" ]; then swift test --filter "$1"; else swift test; fi 2>&1 | tee "$SAIDA"
}

rodar "$1" && exit 0
grep -q "plugin for module 'TestingMacros' not found" "$SAIDA" || exit 1
echo "· as macros do Swift Testing não carregaram (falha das ferramentas); rodando de novo"
rodar "$1"
