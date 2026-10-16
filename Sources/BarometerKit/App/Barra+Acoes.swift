// O que os botões fazem: abrir, encerrar, fechar, copiar, favoritar.

import AppKit
import Foundation

extension Barra {
    func abrir(_ p: Porta) {
        fecharPainel()
        if p.web, let u = URL(string: "http://localhost:\(p.numero)") {
            NSWorkspace.shared.open(u)
        } else {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString("localhost:\(p.numero)", forType: .string)
        }
    }

    func virarLogin() {
        do {
            if Login.ligado {
                try Login.desligar()
                UserDefaults.standard.set(true, forKey: "desligouLogin")
            } else {
                try Login.ligar()
                UserDefaults.standard.set(false, forKey: "desligouLogin")
            }
            estado.abrirAoLigar = Login.ligado
        } catch {
            avisar("Não consegui mudar o abrir ao ligar o Mac", error.localizedDescription)
        }
    }

    /// Abrir sozinho ao ligar o Mac. Era pelo `SMAppService`, que para este app
    /// (assinado só localmente, em ~/Applications) responde "não achado": ele
    /// nunca abriu sozinho. Agora é um LaunchAgent, um arquivo que o macOS lê
    /// ao entrar na conta e que só abre o app. Liga sozinho na primeira vez; quem
    /// desligar no menu continua desligado.
    func abrirNoLoginNaPrimeiraVez() {
        guard !UserDefaults.standard.bool(forKey: "desligouLogin"), !Login.ligado else { return }
        do { try Login.ligar(); Diario.anotar("abrir ao ligar o Mac: ligado") }
        catch { Diario.anotar("abrir ao ligar o Mac: falhou: \(error.localizedDescription)") }
    }

    /// O × pede confirmação e então faz a coisa certa para cada caso — e o caso
    /// do Docker é a razão de esta função não ser um `kill` de três linhas.
    ///
    /// Quem "ouve" uma porta publicada por container **não é o container**: é o
    /// `com.docker.backend`, um processo só para todos eles. Matá-lo derruba o
    /// Docker Desktop inteiro, com todos os outros containers de brinde, e a
    /// porta continua ocupada quando ele voltar. Container se para com
    /// `docker stop`.
    func confirmarEncerrar(_ p: Porta) {
        let alerta = NSAlert()
        let acao: () -> Void

        if let container = p.container {
            alerta.messageText = t("Parar o container \(container)?")
            alerta.informativeText = t("""
                Ele publica a porta \(p.numero). Vai um `docker stop`, não um \
                kill — quem ouve a porta é o Docker inteiro, e matar aquele \
                processo derrubaria todos os outros containers junto.
                """)
            Diario.anotar("porta \(p.numero) é do container \(container); docker stop")
            acao = { [weak self] in
                self?.fila.async {
                    let parou = self?.sonda.parar(container: container) ?? false
                    Diario.anotar(parou ? "container \(container) parado" : "container \(container) NÃO parou")
                    DispatchQueue.main.async {
                        self?.varrer()
                        if !parou {
                            self?.avisar("O container \(container) não parou",
                                         "Confira se o Docker está aberto. No Terminal: docker stop \(container)")
                        }
                    }
                }
            }
        } else if p.doDocker {
            // Docker sem container identificado: ou o `docker` não está no
            // PATH, ou a porta é de algo que o `docker ps` não mostra. Matar o
            // backend às cegas é justamente o que não se quer.
            alerta.messageText = t("Não vou matar este processo")
            alerta.informativeText = t("""
                A porta \(p.numero) é publicada pelo Docker, e quem a ouve é o \
                processo do Docker inteiro — matá-lo derrubaria todos os \
                containers. Não descobri de qual container ela é. Use \
                `docker ps` e pare o container pelo nome.
                """)
            alerta.addButton(withTitle: t("Entendi"))
            DispatchQueue.main.async { NSApp.activate(ignoringOtherApps: true); alerta.runModal() }
            return
        } else {
            /* Descobrir o trabalho ANTES de perguntar, e não depois: a caixa
               precisa dizer quantos processos vão embora. Matar três quando a
               pergunta falava de um é o tipo de surpresa que faz a pessoa
               desconfiar do botão para sempre. */
            let trab = sonda.trabalho(de: p.pid)
            switch trab?.plano {
            case .grupo(let g):
                Diario.anotar("porta \(p.numero): plano GRUPO \(g), "
                    + "\(trab?.membros.count ?? 0) membros: "
                    + (trab?.membros.map { "\($0.pid) \($0.nome)" }.joined(separator: ", ") ?? ""))
            case .processos:
                Diario.anotar("porta \(p.numero): plano PROCESSOS, "
                    + (trab?.membros.map { "\($0.pid) \($0.nome)" }.joined(separator: ", ") ?? ""))
            case nil:
                Diario.anotar("porta \(p.numero): não li a árvore de processos")
            }
            alerta.messageText = t("Encerrar o que está na porta \(p.numero)?")

            var texto = t("\(p.comoChamar), processo \(p.pid).")
            if let p2 = p.pasta { texto += "\n\(p2)" }

            switch trab?.plano {
            case .grupo:
                let membros = trab?.membros ?? []
                texto += "\n\n" + t(membros.count == 1 ? "Vai embora 1 processo do mesmo trabalho — é o que o Ctrl+C no terminal faria:"
                                                     : "Vão embora \(membros.count) processos do mesmo trabalho — é o que o Ctrl+C no terminal faria:") + "\n"
                texto += membros.map { "  · \($0.resumo)" }.joined(separator: "\n")
            case .processos:
                let membros = trab?.membros ?? []
                if membros.count > 1 {
                    texto += "\n\n" + t("E com ele os \(membros.count - 1) que o mantêm de pé:") + "\n"
                    texto += membros.dropFirst().map { "  · \($0.resumo)" }
                        .joined(separator: "\n")
                } else {
                    /* Honestidade sobre o caminho conservador: quando não se
                       acha o trabalho, vai só quem ouve — e um supervisor
                       (`npm run dev`) sobe outro em menos de um segundo. */
                    texto += "\n\n" + t("Só o processo que ouve a porta. Se houver um supervisor no terminal, ele pode subir outro.")
                }
            case nil:
                texto += "\n\n" + t("Não consegui ler a árvore de processos; vai só quem ouve.")
            }
            alerta.informativeText = texto
            acao = { [weak self] in self?.encerrar(p, trab) }
        }

        alerta.addButton(withTitle: t(p.container != nil ? "Parar" : "Encerrar"))
        alerta.addButton(withTitle: t("Cancelar"))
        alerta.buttons.first?.hasDestructiveAction = true
        /* O menu acabou de ser fechado pelo clique no ×. Pedir a caixa no mesmo
           ciclo a faz nascer atrás do menu que ainda está saindo de cena. */
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            Diario.anotar("abrindo a caixa de confirmação")
            guard alerta.runModal() == .alertFirstButtonReturn else {
                Diario.anotar("cancelado na caixa")
                return
            }
            Diario.anotar("confirmado; executando")
            acao()
        }
    }

    /// TERM, quatro segundos de espera, e só então KILL. Processo travado —
    /// que é justamente o que se quer matar — não responde ao primeiro sinal;
    /// processo são fecha arquivo e salva o que tinha com o primeiro, e levar
    /// KILL de cara seria perder isso à toa.
    ///
    /// O sinal vai para o **trabalho**, não só para quem ouve a porta. Matar só
    /// quem ouve não resolvia: num `npm run dev` quem ouve é um neto, o pai o
    /// ressuscita — medido, a porta voltava com PID novo em 300ms — e o
    /// terminal nunca voltava ao prompt.
    func encerrar(_ p: Porta, _ t: (plano: Plano, membros: [Elo])?) {
        fila.async { [weak self] in
            guard let self else { return }
            // Confere na hora: a lista pode ser de três segundos atrás, e nesse
            // tempo o processo pode ter morrido e o número ter sido reciclado.
            guard self.sonda.aindaDono(pid: p.pid, porta: p.numero) else {
                Diario.anotar("pid \(p.pid) já não é dono da \(p.numero); nada a fazer")
                DispatchQueue.main.async { self.varrer() }
                return
            }
            Diario.anotar("mandando TERM")
            let semPermissao = self.sinalizar(p, t, SIGTERM)
            for _ in 0..<8 {
                Thread.sleep(forTimeInterval: 0.5)
                if !self.sonda.ocupada(p.numero) { break }
            }
            if self.sonda.aindaDono(pid: p.pid, porta: p.numero) {
                Diario.anotar("não soltou em 4s; mandando KILL")
                self.sinalizar(p, t, SIGKILL)
                Thread.sleep(forTimeInterval: 0.5)
            }
            let ainda = self.sonda.ocupada(p.numero)
            Diario.anotar(ainda ? "AINDA OCUPADA a \(p.numero) — o encerramento falhou" : "porta \(p.numero) livre")
            // Antes a falha ia só para o log e o × parecia não fazer nada.
            let dono = ainda ? self.sonda.donoAgora(p.numero) : nil
            DispatchQueue.main.async {
                self.varrer()
                guard ainda else { return }
                if semPermissao {
                    self.avisar("A porta \(p.numero) é de outro usuário",
                                "O processo \(p.pid) não é seu (é do sistema ou do root), e o macOS não deixa um app comum encerrá-lo. No Terminal: sudo kill \(p.pid)")
                } else if let d = dono, d.pid != p.pid {
                    let texto = d.pai == "launchd"
                        ? "Encerrei, mas o próprio macOS (launchd) subiu de novo: costuma ser serviço do Homebrew (brew services stop …) ou um app que reinicia sozinho. Encerre quem o sobe, ou clique no × de novo."
                        : "Encerrei, mas o processo \(d.pai.isEmpty ? "pai" : d.pai) subiu outro (pid \(d.pid)). Encerre quem o sobe, ou clique no × de novo."
                    self.avisar("A porta \(p.numero) voltou a ser ocupada", texto)
                } else {
                    self.avisar("A porta \(p.numero) continua ocupada",
                                "Mandei encerrar e o processo \(p.pid) não soltou. No Terminal: kill -9 \(p.pid)")
                }
            }
        }
    }

    func sinalizar(_ p: Porta, _ t: (plano: Plano, membros: [Elo])?, _ sinal: Int32) -> Bool {
        guard let t else { return kill(p.pid, sinal) != 0 && errno == EPERM }
        return sonda.sinalizar(t.plano, t.membros, sinal)
    }

    func copiar() {
        var linhas = portas.map { p -> String in
            var t = String(format: "%-6d %@", p.numero, p.comoChamar)
            if p.doDocker { t += " (docker)" }
            t += "  ·  pid \(p.pid)"
            if let c = p.contexto { t += "  ·  \(c)" }
            return t
        }
        let livres = Pref.favoritas.filter { n in !portas.contains { $0.numero == n } }
        if !livres.isEmpty {
            linhas.append("")
            linhas.append("livres: " + livres.map(String.init).joined(separator: ", "))
        }
        if linhas.isEmpty { linhas = ["nenhuma porta ouvindo"] }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(linhas.joined(separator: "\n"), forType: .string)
    }

    func pedirFavorita() {
        let alerta = NSAlert()
        alerta.messageText = t("Acompanhar qual porta?")
        alerta.informativeText = t("Ela aparece na lista de favoritas mesmo quando está livre.")
        let campo = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        campo.placeholderString = "3006"
        alerta.accessoryView = campo
        alerta.addButton(withTitle: t("Adicionar"))
        alerta.addButton(withTitle: t("Cancelar"))
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            alerta.window.initialFirstResponder = campo
            guard alerta.runModal() == .alertFirstButtonReturn,
                  let n = Int(campo.stringValue.trimmingCharacters(in: .whitespaces)),
                  n > 0, n < 65536 else { return }
            Pref.favoritas = Pref.favoritas + [n]
        }
    }

    /// O × da lista de memória. Aplicativo fecha como o Cmd+Q (ele salva e pergunta o que precisar); se não
    /// fechar em 5 s, oferece forçar. Processo solto vai como o das portas: o trabalho inteiro, TERM e depois KILL.
    func confirmarFechar(_ g: Maquina.Gasto) {
        let alerta = NSAlert()
        if let caminho = g.app {
            alerta.messageText = t("Fechar o \(g.nome)?")
            alerta.informativeText = t("Como o Cmd+Q: ele fecha as janelas e pergunta se houver algo sem salvar. Usa \(Maquina.gb(g.bytes)) agora.")
            alerta.addButton(withTitle: t("Fechar"))
            alerta.addButton(withTitle: t("Cancelar"))
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                guard alerta.runModal() == .alertFirstButtonReturn else { return }
                let apps = NSWorkspace.shared.runningApplications.filter { $0.bundleURL?.path == caminho }
                Diario.anotar("fechar app \(g.nome): \(apps.count) instância(s)")
                apps.forEach { $0.terminate() }
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 5) { [weak self] in
                    guard apps.contains(where: { !$0.isTerminated }) else { return }
                    DispatchQueue.main.async {
                        let forcar = NSAlert()
                        forcar.messageText = t("O \(g.nome) não fechou")
                        forcar.informativeText = t("Pode estar esperando uma resposta numa janela dele. Forçar fecha na hora e perde o que não foi salvo.")
                        forcar.addButton(withTitle: t("Forçar"))
                        forcar.addButton(withTitle: t("Esperar"))
                        NSApp.activate(ignoringOtherApps: true)
                        if forcar.runModal() == .alertFirstButtonReturn {
                            apps.forEach { $0.forceTerminate() }
                            Diario.anotar("app \(g.nome) forçado")
                        }
                        self?.varrer()
                    }
                }
            }
            return
        }
        let trab = sonda.trabalho(de: g.pid)
        alerta.messageText = t("Encerrar \(g.nome) (pid \(g.pid))?")
        var texto = t("Usa \(Maquina.gb(g.bytes)).")
        if let pasta = sonda.pastaDoProcesso(g.pid) { texto += "\n\(pasta)" }
        if let membros = trab?.membros, membros.count > 1 {
            texto += "\n\n" + t("Vão embora \(membros.count) processos do mesmo trabalho (como o Ctrl+C no terminal):") + "\n"
            texto += membros.map { "  · \($0.resumo)" }.joined(separator: "\n")
        }
        alerta.informativeText = texto
        alerta.addButton(withTitle: t("Encerrar"))
        alerta.addButton(withTitle: t("Cancelar"))
        alerta.buttons.first?.hasDestructiveAction = true
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            guard alerta.runModal() == .alertFirstButtonReturn else { return }
            self.encerrarProcesso(g.pid, nome: g.nome, trab)
        }
    }

    func encerrarProcesso(_ pid: Int32, nome: String, _ t: (plano: Plano, membros: [Elo])?) {
        fila.async { [weak self] in
            guard let self else { return }
            let vivo = { kill(pid, 0) == 0 }
            Diario.anotar("encerrar processo \(nome) \(pid)")
            let semPermissao = t.map { self.sonda.sinalizar($0.plano, $0.membros, SIGTERM) }
                ?? (kill(pid, SIGTERM) != 0 && errno == EPERM)
            for _ in 0..<8 where vivo() { Thread.sleep(forTimeInterval: 0.5) }
            if vivo() {
                if let t { self.sonda.sinalizar(t.plano, t.membros, SIGKILL) } else { kill(pid, SIGKILL) }
                Thread.sleep(forTimeInterval: 0.5)
            }
            let ficou = vivo()
            DispatchQueue.main.async {
                self.varrer()
                if ficou {
                    self.avisar("O \(nome) continua aberto",
                                semPermissao ? "Ele não é seu (é do sistema ou do root). No Terminal: sudo kill \(pid)"
                                             : "Mandei encerrar e ele não saiu. No Terminal: kill -9 \(pid)")
                }
            }
        }
    }

    func avisar(_ titulo: String, _ texto: String) {
        DispatchQueue.main.async {
            let a = NSAlert()
            a.messageText = t(titulo)
            a.informativeText = t(texto)
            a.addButton(withTitle: t("Entendi"))
            NSApp.activate(ignoringOtherApps: true)
            a.runModal()
        }
    }
}
