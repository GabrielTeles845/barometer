#!/bin/bash
# As fotos de cada aba (inglês e português), a da barra de menus e os banners.
set -e
source "$(dirname "$0")/comum.sh"
trap desligar_demo EXIT
compilar
for lang in en pt; do
  if [ $lang = en ]; then
    R="$RAIZ/docs/images"; nomes="cpu:cpu memoria:memory gpu:gpu disco:disk bateria:battery portas:ports limpeza:cleanup"
  else
    R="$RAIZ/docs/images/pt"; nomes="cpu:cpu memoria:memoria gpu:gpu disco:disco bateria:bateria portas:portas limpeza:limpeza"
  fi
  ligar_demo $lang
  "$B" --retrato "$R/overview.png" --acender p:3000 --idioma $lang >/dev/null 2>&1
  for par in $nomes; do "$B" --retrato "$R/${par##*:}.png" --aba "${par%%:*}" --idioma $lang >/dev/null 2>&1; done
  "$B" --retrato "$R/edit.png" --editar --idioma $lang >/dev/null 2>&1
  mv "$R/overview-icone.png" "$R/menubar.png"; rm -f "$R"/*-icone.png
  desligar_demo
  sleep 1
done
swift "$RAIZ/docs/icon/montar-banner.swift" "$RAIZ/docs/images" "$RAIZ/docs/images/banner.png"
swift "$RAIZ/docs/icon/montar-banner.swift" "$RAIZ/docs/images/pt" "$RAIZ/docs/images/pt/banner.png" overview.png cpu.png memoria.png
