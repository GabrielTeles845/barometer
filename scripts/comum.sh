# Peças comuns dos scripts de imagem: compilar, ligar e desligar os servidores de exemplo.
# Usar com `source scripts/comum.sh` a partir da raiz do repositório.

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEMO="$RAIZ/scripts/demo"

compilar() {
  swift build -c release --package-path "$RAIZ" >/dev/null
  B="$(swift build -c release --package-path "$RAIZ" --show-bin-path)/barometer"
  [ -x "$B" ] || { echo "não compilou"; exit 1; }
}

# As portas dos exemplos. As fotos só mostram estas: as portas e os projetos de verdade da máquina não vão para o
# README (17/10: a foto ia mostrar os projetos de trabalho de quem rodou).
PORTAS_DEMO="4000 5173"
export BAROMETER_FOTO_PORTAS="4000,5173"
PIDS_DEMO=()

# ligar_demo en|pt: os dois projetos de exemplo, com nomes no idioma da foto. Para se a porta já estiver ocupada:
# desligar depois mataria o que é de outra pessoa.
ligar_demo() {
  local a b p
  for p in $PORTAS_DEMO; do
    if lsof -nP -iTCP:$p -sTCP:LISTEN >/dev/null 2>&1; then echo "a porta $p está ocupada; libere e rode de novo"; exit 1; fi
  done
  if [ "$1" = en ]; then a=my-store; b=landing-site; else a=minha-loja; b=site-vitrine; fi
  (cd "$DEMO/$a" && exec node server.js 4000 >/dev/null 2>&1) & PIDS_DEMO+=($!)
  (cd "$DEMO/$b" && exec node server.js 5173 >/dev/null 2>&1) & PIDS_DEMO+=($!)
  for _ in 1 2 3 4 5; do lsof -nP -iTCP:5173 -sTCP:LISTEN >/dev/null && break; sleep 1; done
}

# Desliga só o que o ligar_demo subiu, pelo PID (nunca pela porta).
desligar_demo() {
  for pid in "${PIDS_DEMO[@]}"; do kill "$pid" 2>/dev/null || true; done
  PIDS_DEMO=()
}
