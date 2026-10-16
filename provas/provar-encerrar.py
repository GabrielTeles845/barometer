#!/usr/bin/env python3
"""Prova a decisão de QUEM MORRE quando se clica no ×.

Esta é a prova mais importante do projeto, porque o erro aqui não é cosmético:
um `kill` no grupo errado derruba o terminal, o editor ou a sessão de quem está
usando a máquina. Aconteceu durante o desenvolvimento — um `kill -TERM -$PGID`
de teste matou o próprio shell que rodava o teste.

Ela usa o próprio app compilado (`barometer --arnes-encerrar <pid>`), sobe cobaias de verdade com
árvore de processos conhecida, e confere o que a `trabalho(de:)` decide.

    python3 provas/provar-encerrar.py
"""
import os
import re
import subprocess
import sys
import tempfile
import time

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

with tempfile.TemporaryDirectory() as tmp:
    # O arnês é o próprio app (`--arnes-encerrar`): a decisão e o sinal são o código de verdade do botão.
    c = subprocess.run(["swift", "build", "--package-path", RAIZ], capture_output=True, text=True, timeout=120)
    if c.returncode:
        sys.exit("não compilou:\n" + (c.stdout + c.stderr)[-3000:])
    pasta = subprocess.run(["swift", "build", "--package-path", RAIZ, "--show-bin-path"],
                           capture_output=True, text=True, timeout=120).stdout.strip()
    binario = os.path.join(pasta, "barometer")

    PORTA = "3399"          # alta e improvável, para não brigar com nada seu
    falhas = 0

    def ouvinte():
        r = subprocess.run(["/usr/sbin/lsof", "-nP", f"-iTCP:{PORTA}", "-sTCP:LISTEN"],
                           capture_output=True, text=True, timeout=120)
        for linha in r.stdout.splitlines():
            if "LISTEN" in linha:
                return int(linha.split()[1])
        return None

    def decidir(pid):
        r = subprocess.run([binario, "--arnes-encerrar", str(pid)], capture_output=True, text=True, timeout=120)
        plano, membros = None, []
        for linha in r.stdout.splitlines():
            if linha.startswith("plano="):
                plano = linha[6:]
            elif linha.startswith("membro "):
                p = linha.split(None, 3)
                membros.append((int(p[1]), p[2]))
        return plano, membros

    def provar(titulo, deu, detalhe=""):
        global falhas
        print(f"  {'ok ' if deu else 'X  '} {titulo}{('  — ' + detalhe) if detalhe and not deu else ''}")
        if not deu:
            falhas += 1

    def _vivo(pid):
        try:
            os.kill(pid, 0)
            return True
        except (ProcessLookupError, PermissionError):
            return False

    def matar(*pids):
        for p in pids:
            try:
                os.kill(p, 9)
            except (ProcessLookupError, PermissionError):
                pass

    # ── caso 1: supervisor que RESSUSCITA o filho, com shell no meio ────────
    # É a forma do `npm run dev`, e o caso em que matar só quem ouve não serve.
    print("\ncaso 1 — supervisor com shell no meio (forma do `npm run dev`)")
    script = os.path.join(tmp, "pai.sh")
    open(script, "w").write(
        f"#!/bin/zsh\nwhile true; do python3 -m http.server {PORTA} >/dev/null 2>&1;"
        " /bin/sleep 0.2; done\n")
    os.chmod(script, 0o755)
    pai = subprocess.Popen(["/bin/zsh", script],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    for _ in range(40):
        time.sleep(0.25)
        if ouvinte():
            break
    filho = ouvinte()
    provar("a cobaia subiu e ocupou a porta", filho is not None)

    if filho:
        plano, membros = decidir(filho)
        nomes = [n for _, n in membros]
        print(f"     decidiu: {plano}  membros={nomes}")

        # A prova que importa: o grupo aqui é o do SHELL que rodou o teste
        # (sem job control não há grupo próprio), e mandar sinal para ele
        # derrubaria o terminal. Tem de ser recusado.
        provar("recusou o grupo, porque o líder é um shell",
               plano == "processos", f"plano={plano}")
        conchas = {"zsh", "bash", "sh", "dash", "fish", "-zsh", "-bash"}
        provar("nenhum shell na lista de quem morre",
               not (conchas & set(nomes)), f"membros={nomes}")
        barreiras = {"claude", "Code Helper", "Electron", "launchd", "login", "node"}
        intrusos = [n for n in nomes if n in barreiras or n.startswith("Code")]
        provar("nem terminal, nem editor, nem o Claude Code",
               not intrusos, f"intrusos={intrusos}")
        provar("quem ouve a porta está na lista",
               any(p == filho for p, _ in membros))

    matar(pai.pid)
    time.sleep(0.5)
    p = ouvinte()
    matar(p) if p else None
    time.sleep(0.5)

    # ── caso 2: cadeia sem shell no meio (o pai entra junto) ───────────────
    print("\ncaso 2 — pai e filho sem shell entre eles (o pai deve entrar)")
    pyprog = (
        "import subprocess,sys,time\n"
        f"f=subprocess.Popen([sys.executable,'-m','http.server','{PORTA}'],"
        "stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)\n"
        "time.sleep(600)\n")
    pai2 = subprocess.Popen([sys.executable, "-c", pyprog],
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    for _ in range(40):
        time.sleep(0.25)
        if ouvinte():
            break
    filho2 = ouvinte()
    provar("a cobaia subiu e ocupou a porta", filho2 is not None)
    if filho2:
        plano, membros = decidir(filho2)
        pids = [p for p, _ in membros]
        print(f"     decidiu: {plano}  pids={pids}  (pai={pai2.pid}, filho={filho2})")
        provar("o PAI entra na lista — é ele que ressuscitaria o filho",
               pai2.pid in pids, f"pids={pids}")
        conchas = {"zsh", "bash", "sh", "dash", "fish"}
        provar("e ainda assim nenhum shell entrou",
               not (conchas & {n for _, n in membros}))
    matar(pai2.pid, filho2 or 0)
    time.sleep(0.5)
    p = ouvinte()
    matar(p) if p else None


    # ── caso 3: de ponta a ponta, o caso que o usuário relatou ─────────────
    # "Eu fechei, e o terminal continua com o negocio rodando": matar só quem
    # ouve deixava o supervisor vivo. Aqui o encerramento roda pelo MESMO
    # código do botão, e a porta tem de ficar livre.
    print("\ncaso 3 — encerrar de verdade um supervisor que ressuscita")
    pyprog3 = (
        "import subprocess,sys,time\n"
        "while True:\n"
        f"    f=subprocess.Popen([sys.executable,'-m','http.server','{PORTA}'],"
        "stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)\n"
        "    f.wait()\n"
        "    time.sleep(0.2)\n")
    suv = subprocess.Popen([sys.executable, "-c", pyprog3],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    for _ in range(40):
        time.sleep(0.25)
        if ouvinte():
            break
    alvo3 = ouvinte()
    provar("o supervisor subiu e a porta está ocupada", alvo3 is not None)

    if alvo3:
        # Primeiro a prova de que o bug era real: matar só quem ouve.
        os.kill(alvo3, 15)
        time.sleep(1.5)
        renasceu = ouvinte()
        provar("matando só quem ouve, a porta VOLTA (o bug original)",
               renasceu is not None and renasceu != alvo3,
               f"antes={alvo3} agora={renasceu}")

        # Agora pelo caminho do botão.
        alvo3 = ouvinte()
        r = subprocess.run([binario, "--arnes-encerrar", str(alvo3), "--matar"],
                           capture_output=True, text=True, timeout=120)
        provar("o arnês mandou o sinal pelo código do app",
               "sinal=TERM" in r.stdout, r.stdout[:200])
        livre = False
        for _ in range(16):
            time.sleep(0.5)
            if not ouvinte():
                livre = True
                break
        provar("pelo caminho do botão, a porta FICA livre", livre,
               f"ainda ocupada por {ouvinte()}")
        provar("e o supervisor morreu junto",
               suv.poll() is not None or not _vivo(suv.pid),
               "supervisor ainda de pé")

    matar(suv.pid)
    time.sleep(0.4)
    p = ouvinte()
    matar(p) if p else None

    print("\n" + ("== a decisão está segura ==" if falhas == 0
                  else f"X {falhas} prova(s) falharam"))
    sys.exit(1 if falhas else 0)
