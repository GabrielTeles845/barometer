#!/bin/bash
# Os dois GIFs do README: todas as abas e algumas aparências, em inglês e em português.
set -e
source "$(dirname "$0")/comum.sh"
trap desligar_demo EXIT
compilar
Q="$(mktemp -d)"
ALTURA=1010

quadros=(
  "geral|--acender p:4000"
  "cpu|"
  "memoria|"
  "gpu|"
  "disco|"
  "bateria|"
  "portas|"
  "limpeza|"
  "geral|--editar"
  "aparencia|"
  "geral|--fundo vidro --paleta oceano"
  "aparencia|--fundo vidroClaro --paleta neon --destaque rosa"
  "memoria|--fundo fosco --paleta entardecer --cantos 22"
  "cpu|--fundo vidro --paleta mono --destaque azul"
  "geral|--fundo vidroClaro --paleta pastel --cantos 22"
  "geral|--boas-vindas"
  "geral|--modo claro"
  "cpu|--modo claro --paleta oceano --cantos 22"
)

for lang in en pt; do
  ligar_demo $lang
  n=0
  for q in "${quadros[@]}"; do
    aba="${q%%|*}"; extra="${q#*|}"
    arq=$(printf "%s/%s-%02d.png" "$Q" $lang $n)
    # shellcheck disable=SC2086
    "$B" --retrato "$arq" --aba "$aba" --idioma $lang --papel --altura $ALTURA $extra >/dev/null 2>&1
    rm -f "${arq%.png}-icone.png"
    n=$((n + 1))
  done
  desligar_demo
  sleep 1
done

# Cada tela fica 2,2 s e passa para a próxima num esmaecer de 0,25 s. 12 quadros por segundo e 200 cores:
# cada GIF fica perto de 4 MB.
montar() {
  local lang="$1" saida="$2"
  local arquivos=("$Q"/$lang-*.png)
  local entradas=() filtro="" anterior="[0:v]" fica=2.2 troca=0.25
  for f in "${arquivos[@]}"; do entradas+=(-loop 1 -t $fica -i "$f"); done
  for ((i = 1; i < ${#arquivos[@]}; i++)); do
    filtro+="${anterior}[$i:v]xfade=transition=fade:duration=$troca:offset=$(echo "$i * ($fica - $troca)" | bc)[x$i];"
    anterior="[x$i]"
  done
  filtro+="${anterior}fps=12,scale=520:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=200:stats_mode=diff[p];[s1][p]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle"
  ffmpeg -y -loglevel error "${entradas[@]}" -filter_complex "$filtro" -loop 0 "$saida"
}
montar en "$RAIZ/docs/images/tour.gif"
montar pt "$RAIZ/docs/images/pt/tour.gif"
rm -rf "$Q"
ls -la "$RAIZ/docs/images/tour.gif" "$RAIZ/docs/images/pt/tour.gif"
