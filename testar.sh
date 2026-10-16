#!/bin/bash
# Roda os testes. Use este em vez do `swift test` puro:
#
#     bash testar.sh            # todos
#     bash testar.sh Portas     # só uma suíte (o nome ou parte dele)
#
# Com só as ferramentas de linha de comando da Apple (sem Xcode), o `swift test` perde as macros do Swift
# Testing quando recompila os testes aproveitando a compilação anterior ("plugin for module 'TestingMacros'
# not found"). Apagar só o que é dos testes antes de rodar evita isso; o app não é recompilado à toa.
set -e
cd "$(dirname "$0")"
rm -rf .build/out/Intermediates.noindex/Barometer.build/Debug/BarometerKitTests-p.build
if [ -n "$1" ]; then swift test --filter "$1"; else swift test; fi
