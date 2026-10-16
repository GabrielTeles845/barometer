# Peças comuns dos scripts de imagem: compilar, ligar e desligar os servidores de exemplo.
# Usar com `source scripts/comum.sh` a partir da raiz do repositório.

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEMO="$RAIZ/scripts/demo"

compilar() {
  swift build -c release --package-path "$RAIZ" >/dev/null
  B="$(swift build -c release --package-path "$RAIZ" --show-bin-path)/barometer"
  [ -x "$B" ] || { echo "não compilou"; exit 1; }
}

# ligar_demo en|pt: os dois projetos de exemplo nas portas 3000 e 5173, com nomes no idioma da foto.
ligar_demo() {
  local a b
  if [ "$1" = en ]; then a=my-store; b=landing-site; else a=minha-loja; b=site-vitrine; fi
  (cd "$DEMO/$a" && node server.js 3000 >/dev/null 2>&1 &)
  (cd "$DEMO/$b" && node server.js 5173 >/dev/null 2>&1 &)
  for _ in 1 2 3 4 5; do lsof -nP -iTCP:5173 -sTCP:LISTEN >/dev/null && break; sleep 1; done
}

# Desliga pela porta (o PID do subshell não é o do node).
desligar_demo() {
  for p in 3000 5173; do
    for pid in $(lsof -tnP -iTCP:$p -sTCP:LISTEN 2>/dev/null); do kill "$pid" 2>/dev/null || true; done
  done
}
