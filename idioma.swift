// Idiomas: inglês, português e espanhol. O código escreve em português e passa pelo `t()`, que devolve a frase
// no idioma escolhido (o do Mac, ou o que a pessoa escolheu na engrenagem).
//
// Frase com número no meio ("217 GB livres") vale como padrão: "%1 livres" casa com qualquer coisa no lugar do %1
// e a tradução põe o mesmo pedaço no mesmo lugar ("217 GB free"). Assim cada tela continua escrevendo a frase
// inteira, sem montar pedaço por pedaço.

import Foundation

enum Idioma: String, CaseIterable {
    case automatico, en, pt, es

    var nome: String {
        switch self {
        case .automatico: return t("Automático (o do Mac)")
        case .en: return "English"
        case .pt: return "Português"
        case .es: return "Español"
        }
    }

    /// O idioma em uso: o escolhido, ou o primeiro do Mac que o app fala (inglês quando nenhum).
    /// Para a foto (`--retrato --idioma en`): passa por cima do escolhido e do Mac.
    static var forcado: Idioma?

    static var atual: Idioma {
        if let forcado { return forcado }
        let escolhido = Idioma(rawValue: UserDefaults.standard.string(forKey: "idioma") ?? "") ?? .automatico
        if escolhido != .automatico { return escolhido }
        for codigo in Locale.preferredLanguages {
            if codigo.hasPrefix("pt") { return .pt }
            if codigo.hasPrefix("es") { return .es }
            if codigo.hasPrefix("en") { return .en }
        }
        return .en
    }

    static var escolhido: Idioma {
        get { Idioma(rawValue: UserDefaults.standard.string(forKey: "idioma") ?? "") ?? .automatico }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "idioma") }
    }
}

/// Número com a vírgula ou o ponto do idioma: "8,9" em português e espanhol, "8.9" em inglês.
func decimal(_ v: Double, casas: Int = 1) -> String {
    let texto = String(format: "%.\(casas)f", v)
    return Idioma.atual == .en ? texto : texto.replacingOccurrences(of: ".", with: ",")
}

/// Milhar com o separador do idioma: "5.786" em português e espanhol, "5,786" em inglês.
func milhar(_ n: Int) -> String {
    guard n >= 1000 else { return String(n) }
    return "\(n / 1000)\(Idioma.atual == .en ? "," : ".")\(String(format: "%03d", n % 1000))"
}

/// A frase no idioma em uso. O português é a chave.
func t(_ frase: String) -> String {
    let idioma = Idioma.atual
    guard idioma != .pt else { return frase }
    if let par = Traducao.exatas[frase] { return idioma == .en ? par.0 : par.1 }
    for p in Traducao.padroes {
        let alcance = NSRange(frase.startIndex..., in: frase)
        guard let achado = p.regex.firstMatch(in: frase, range: alcance) else { continue }
        var saida = idioma == .en ? p.en : p.es
        for i in (1..<achado.numberOfRanges).reversed() {
            guard let r = Range(achado.range(at: i), in: frase) else { continue }
            saida = saida.replacingOccurrences(of: "%\(i)", with: String(frase[r]))
        }
        return saida
    }
    return frase
}

enum Traducao {
    /// Português → (inglês, espanhol).
    static let exatas: [String: (String, String)] = [
        // Abas e cartões
        "Geral": ("Overview", "General"), "Memória": ("Memory", "Memoria"), "Disco": ("Disk", "Disco"),
        "Bateria": ("Battery", "Batería"), "Portas": ("Ports", "Puertos"), "Este Mac": ("This Mac", "Este Mac"),
        "Visão rápida": ("At a glance", "Vista rápida"), "Histórico": ("History", "Historial"),
        "Memória por partes": ("Memory breakdown", "Memoria por partes"), "Núcleos da CPU": ("CPU cores", "Núcleos de la CPU"),
        "Temperaturas": ("Temperatures", "Temperaturas"), "O que mais usa": ("Top processes", "Lo que más usa"),
        "Editar": ("Edit", "Editar"), "Pronto": ("Done", "Listo"), "Voltar ao padrão": ("Reset to default", "Restablecer"),
        "Ligue o que quer ver no Geral. Segure e arraste para mudar a ordem.":
            ("Turn on what you want in the Overview. Hold and drag to reorder.",
             "Activa lo que quieres ver en General. Mantén pulsado y arrastra para reordenar."),
        "Este Mac não tem bateria.": ("This Mac has no battery.", "Este Mac no tiene batería."),
        // Rodapé e ajustes
        "Atualizar agora": ("Refresh now", "Actualizar ahora"), "Mostrar todas as portas": ("Show all ports", "Mostrar todos los puertos"),
        "Abrir o Monitor de Atividade": ("Open Activity Monitor", "Abrir el Monitor de Actividad"),
        "Copiar a lista de portas": ("Copy the port list", "Copiar la lista de puertos"), "Ajustes": ("Settings", "Ajustes"),
        "Abrir ao ligar o Mac": ("Open at login", "Abrir al iniciar el Mac"),
        "CPU e memória no ícone": ("CPU and memory in the icon", "CPU y memoria en el icono"),
        "Portas favoritas": ("Favorite ports", "Puertos favoritos"), "Outra porta…": ("Another port…", "Otro puerto…"),
        "Idioma": ("Language", "Idioma"), "Automático (o do Mac)": ("Automatic (the Mac's)", "Automático (el del Mac)"),
        "Sair": ("Quit", "Salir"), "Cancelar": ("Cancel", "Cancelar"), "Entendi": ("Got it", "Entendido"),
        "Adicionar": ("Add", "Añadir"), "Encerrar": ("Quit", "Cerrar"), "Parar": ("Stop", "Detener"),
        "Fechar": ("Close", "Cerrar"), "Forçar": ("Force", "Forzar"), "Esperar": ("Wait", "Esperar"),
        // Anéis e gráfico
        "Chip": ("Chip", "Chip"), "Temp.": ("Temp.", "Temp."),
        "Juntando as primeiras leituras (uma por minuto).": ("Collecting the first readings (one per minute).",
                                                             "Reuniendo las primeras lecturas (una por minuto)."),
        "últimas 6 h": ("last 6 h", "últimas 6 h"),
        // Memória
        "apps": ("apps", "apps"), "fixa": ("wired", "fija"), "comprimida": ("compressed", "comprimida"), "cache": ("cached", "caché"),
        "swap": ("swap", "swap"), "folgada": ("fine", "holgada"), "apertada": ("tight", "ajustada"), "no limite": ("at the limit", "al límite"),
        // Processos
        "O QUE MAIS USA": ("TOP BY", "LO QUE MÁS USA"), "memória": ("memory", "memoria"), "× fecha": ("× closes", "× cierra"),
        "este app": ("this app", "esta app"), "sistema": ("system", "sistema"), "aplicativo": ("app", "app"),
        // CPU
        "usuário": ("user", "usuario"), "carga": ("load", "carga"), "ligado há": ("up", "encendido hace"),
        "eficiência": ("efficiency", "eficiencia"), "desempenho": ("performance", "rendimiento"),
        "temperatura ok": ("temperature ok", "temperatura ok"), "esquentando": ("warming up", "calentándose"),
        "quente, reduzindo": ("hot, slowing down", "caliente, reduciendo"), "muito quente": ("very hot", "muy caliente"),
        // Disco e GPU
        "leitura": ("read", "lectura"), "escrita": ("write", "escritura"), "desde que o Mac ligou": ("since the Mac started", "desde que se encendió el Mac"),
        "lido": ("read", "leído"), "escrito": ("written", "escrito"), "leituras": ("reads", "lecturas"), "escritas": ("writes", "escrituras"),
        "DISCO": ("DISK", "DISCO"), "uso": ("usage", "uso"),
        // Bateria e temperaturas
        "Saúde": ("Health", "Salud"), "Ciclos": ("Cycles", "Ciclos"), "Capacidade": ("Capacity", "Capacidad"),
        "Temperatura": ("Temperature", "Temperatura"), "Voltagem": ("Voltage", "Voltaje"), "Corrente": ("Current", "Corriente"),
        "da capacidade original": ("of the original capacity", "de la capacidad original"), "da bateria": ("of the battery", "de la batería"),
        "agora": ("now", "ahora"), "saindo da bateria": ("leaving the battery", "saliendo de la batería"), "entrando": ("charging in", "entrando"),
        "parada": ("idle", "parada"), "Carregando": ("Charging", "Cargando"), "Carregada, na tomada": ("Charged, plugged in", "Cargada, enchufada"),
        "Na tomada, sem carregar": ("Plugged in, not charging", "Enchufada, sin cargar"), "Na bateria": ("On battery", "Con batería"),
        "carga otimizada pelo macOS": ("charging optimized by macOS", "carga optimizada por macOS"),
        "carregando": ("charging", "cargando"), "na tomada": ("plugged in", "enchufada"), "na bateria": ("on battery", "con batería"),
        "SSD": ("SSD", "SSD"), "disco": ("disk", "disco"), "célula": ("cell", "celda"),
        "Normal": ("Normal", "Normal"), "Razoável": ("Fair", "Aceptable"), "Precisa de manutenção": ("Service recommended", "Requiere servicio"),
        // Portas
        "Nenhuma porta ouvindo": ("No ports listening", "Ningún puerto escuchando"), "Portas ouvindo": ("Listening ports", "Puertos escuchando"),
        "clique abre · × encerra": ("click opens · × stops", "clic abre · × cierra"), "nenhuma porta ouvindo": ("no ports listening", "ningún puerto escuchando"),
        // O que é cada serviço do macOS
        "desenha a tela": ("draws the screen", "dibuja la pantalla"), "núcleo do macOS": ("macOS kernel", "núcleo de macOS"),
        "libera espaço em disco": ("frees disk space", "libera espacio en disco"), "analisa as fotos": ("analyzes photos", "analiza las fotos"),
        "biblioteca do Fotos": ("Photos library", "biblioteca de Fotos"), "abre os apps": ("launches apps", "abre las apps"),
        "atualização do macOS": ("macOS updates", "actualización de macOS"), "certificados": ("certificates", "certificados"),
        "segurança dos apps": ("app security", "seguridad de las apps"), "antivírus do macOS": ("macOS antivirus", "antivirus de macOS"),
        "som": ("sound", "sonido"), "energia": ("power", "energía"), "registros do sistema": ("system logs", "registros del sistema"),
        "sugestões da Siri": ("Siri suggestions", "sugerencias de Siri"), "barra de menus": ("menu bar", "barra de menús"),
        "Central de Controle": ("Control Center", "Centro de control"), "Impressão": ("Printing", "Impresión"),
        "Mac remoto": ("Remote Mac", "Mac remoto"), "Compartilhamento": ("Sharing", "Compartir"), "Compartilhar tela": ("Screen Sharing", "Compartir pantalla"),
        "Bonjour": ("Bonjour", "Bonjour"), "macOS": ("macOS", "macOS"),
        // Limpeza
        "Limpeza": ("Cleanup", "Limpieza"), "Medindo…": ("Measuring…", "Midiendo…"),
        "podem sair sem perder nada seu": ("can go without losing anything of yours", "pueden irse sin perder nada tuyo"),
        "Limpar": ("Clean", "Limpiar"), "Esvaziar": ("Empty", "Vaciar"),
        "Limpar tudo (menos a Lixeira)": ("Clean everything (except the Trash)", "Limpiar todo (menos la Papelera)"),
        "Documentos, downloads e fotos nunca entram aqui. Cada limpeza pede confirmação.":
            ("Documents, downloads and photos are never touched. Every cleanup asks first.",
             "Documentos, descargas y fotos nunca entran aquí. Cada limpieza pide confirmación."),
        "Caches dos apps": ("App caches", "Cachés de las apps"),
        "Os apps refazem sozinhos; podem abrir um pouco mais devagar na primeira vez.":
            ("Apps rebuild them on their own; they may open a bit slower the first time.",
             "Las apps los rehacen solas; pueden abrir un poco más lento la primera vez."),
        "Cache do npm": ("npm cache", "Caché de npm"), "Cache do Bun": ("Bun cache", "Caché de Bun"), "Cache do pnpm": ("pnpm store", "Caché de pnpm"),
        "Os pacotes são baixados de novo quando um projeto precisar.": ("Packages download again when a project needs them.",
                                                                        "Los paquetes se descargan de nuevo cuando un proyecto los necesite."),
        "Dados derivados do Xcode": ("Xcode DerivedData", "Datos derivados de Xcode"),
        "O Xcode recompila na próxima vez que abrir cada projeto.": ("Xcode rebuilds the next time you open each project.",
                                                                      "Xcode recompila la próxima vez que abras cada proyecto."),
        "Cache dos simuladores": ("Simulator caches", "Caché de los simuladores"),
        "Os simuladores do Xcode refazem quando abrirem.": ("Xcode simulators rebuild them when they start.", "Los simuladores de Xcode lo rehacen al abrir."),
        "Registros dos apps": ("App logs", "Registros de las apps"),
        "Arquivos de log antigos; os apps criam novos.": ("Old log files; apps create new ones.", "Archivos de registro antiguos; las apps crean nuevos."),
        "Lixeira": ("Trash", "Papelera"), "Esvazia a Lixeira. Não tem volta.": ("Empties the Trash. There's no undo.", "Vacía la Papelera. No se puede deshacer."),
        "Esvaziar a Lixeira?": ("Empty the Trash?", "¿Vaciar la Papelera?"),
        "Os arquivos da Lixeira são apagados de vez. Não tem como recuperar depois.":
            ("Everything in the Trash is deleted for good. There's no getting it back.",
             "Los archivos de la Papelera se borran para siempre. No se pueden recuperar."),
        // Avisos e caixas
        "Não vou matar este processo": ("I won't kill this process", "No voy a cerrar este proceso"),
        "Acompanhar qual porta?": ("Which port to watch?", "¿Qué puerto seguir?"),
        "Ela aparece na lista de favoritas mesmo quando está livre.": ("It shows in the favorites even when it's free.",
                                                                       "Aparece en favoritos aunque esté libre."),
        "Não consegui mudar o abrir ao ligar o Mac": ("Couldn't change Open at login", "No pude cambiar Abrir al iniciar el Mac"),
        "Pode estar esperando uma resposta numa janela dele. Forçar fecha na hora e perde o que não foi salvo.":
            ("It may be waiting for an answer in one of its windows. Force quits right away and loses anything unsaved.",
             "Puede estar esperando una respuesta en una de sus ventanas. Forzar cierra al instante y pierde lo no guardado."),
        "Só o processo que ouve a porta. Se houver um supervisor no terminal, ele pode subir outro.":
            ("Only the process listening on the port. If a supervisor runs in the terminal, it may start another one.",
             "Solo el proceso que escucha el puerto. Si hay un supervisor en la terminal, puede iniciar otro."),
        "Não consegui ler a árvore de processos; vai só quem ouve.": ("Couldn't read the process tree; only the listener goes.",
                                                                      "No pude leer el árbol de procesos; solo se va el que escucha."),
    ]

    struct Padrao {
        let regex: NSRegularExpression
        let en: String
        let es: String
    }

    /// Frases com pedaços variáveis. %1, %2… casam com qualquer texto e voltam no mesmo lugar.
    static let padroes: [Padrao] = [
        ("%1 livres", "%1 free", "%1 libres"), ("de %1", "of %1", "de %1"), ("%1% usado", "%1% used", "%1% usado"),
        ("máx %1", "max %1", "máx %1"), ("últimos %1 min", "last %1 min", "últimos %1 min"), ("últimas %1 h", "last %1 h", "últimas %1 h"),
        ("%1 núcleos", "%1 cores", "%1 núcleos"), ("memória %1", "memory %1", "memoria %1"), ("%1 mil", "%1k", "%1 mil"),
        ("%1 mi", "%1M", "%1 M"),
        ("carregador de %1 W", "%1 W charger", "cargador de %1 W"), ("o Mac está gastando %1 W", "the Mac is drawing %1 W", "el Mac está consumiendo %1 W"),
        ("de %1 previstos", "of %1 rated", "de %1 previstos"), ("de %1 mAh de fábrica", "of %1 mAh new", "de %1 mAh de fábrica"),
        ("cheia em %1", "full in %1", "llena en %1"), ("%1 restantes", "%1 left", "%1 restantes"),
        ("%1 ciclos", "%1 cycles", "%1 ciclos"), ("saúde %1", "health %1", "salud %1"), ("de %1 em uso", "of %1 in use", "de %1 en uso"),
        ("sistema · %1", "system · %1", "sistema · %1"), ("%1 proc.", "%1 proc.", "%1 proc."), ("livres: %1", "free: %1", "libres: %1"),
        ("ocultas: %1", "hidden: %1", "ocultos: %1"), ("%1 e mais %2", "%1 and %2 more", "%1 y %2 más"),
        ("Memória usada: %1", "Memory used: %1", "Memoria usada: %1"),
        ("CPU %1 · memória %2", "CPU %1 · memory %2", "CPU %1 · memoria %2"), ("%1 · chip %2", "%1 · chip %2", "%1 · chip %2"),
        ("Parar o container %1?", "Stop the %1 container?", "¿Detener el contenedor %1?"),
        ("O container %1 não parou", "The %1 container didn't stop", "El contenedor %1 no se detuvo"),
        ("Confira se o Docker está aberto. No Terminal: docker stop %1", "Check that Docker is running. In Terminal: docker stop %1",
         "Comprueba que Docker esté abierto. En la Terminal: docker stop %1"),
        ("Ele publica a porta %1. Vai um `docker stop`, não um kill — quem ouve a porta é o Docker inteiro, e matar aquele processo derrubaria todos os outros containers junto.",
         "It publishes port %1. This runs `docker stop`, not a kill: the whole of Docker listens on the port, and killing that process would take down every other container too.",
         "Publica el puerto %1. Se usa `docker stop`, no un kill: quien escucha el puerto es todo Docker, y cerrar ese proceso tumbaría todos los demás contenedores."),
        ("A porta %1 é publicada pelo Docker, e quem a ouve é o processo do Docker inteiro — matá-lo derrubaria todos os containers. Não descobri de qual container ela é. Use `docker ps` e pare o container pelo nome.",
         "Port %1 is published by Docker, and the whole Docker process listens on it; killing it would take down every container. I couldn't tell which container it belongs to. Use `docker ps` and stop the container by name.",
         "El puerto %1 lo publica Docker, y quien lo escucha es todo el proceso de Docker; cerrarlo tumbaría todos los contenedores. No supe de qué contenedor es. Usa `docker ps` y detén el contenedor por su nombre."),
        ("Encerrar o que está na porta %1?", "Quit what's on port %1?", "¿Cerrar lo que está en el puerto %1?"),
        ("%1, processo %2.", "%1, process %2.", "%1, proceso %2."),
        ("Vão embora %1 processos do mesmo trabalho — é o que o Ctrl+C no terminal faria:", "%1 processes from the same job will go, just like Ctrl+C in the terminal:",
         "Se van %1 procesos del mismo trabajo, como haría Ctrl+C en la terminal:"),
        ("Vai embora 1 processo do mesmo trabalho — é o que o Ctrl+C no terminal faria:", "1 process from the same job will go, just like Ctrl+C in the terminal:",
         "Se va 1 proceso del mismo trabajo, como haría Ctrl+C en la terminal:"),
        ("E com ele os %1 que o mantêm de pé:", "Along with the %1 keeping it alive:", "Y con él los %1 que lo mantienen vivo:"),
        ("A porta %1 é de outro usuário", "Port %1 belongs to another user", "El puerto %1 es de otro usuario"),
        ("O processo %1 não é seu (é do sistema ou do root), e o macOS não deixa um app comum encerrá-lo. No Terminal: sudo kill %2",
         "Process %1 isn't yours (it belongs to the system or root), and macOS doesn't let a regular app quit it. In Terminal: sudo kill %2",
         "El proceso %1 no es tuyo (es del sistema o de root), y macOS no deja que una app normal lo cierre. En la Terminal: sudo kill %2"),
        ("A porta %1 voltou a ser ocupada", "Port %1 got taken again", "El puerto %1 volvió a ocuparse"),
        ("Encerrei, mas o próprio macOS (launchd) subiu de novo: costuma ser serviço do Homebrew (brew services stop …) ou um app que reinicia sozinho. Encerre quem o sobe, ou clique no × de novo.",
         "I quit it, but macOS itself (launchd) started it again: usually a Homebrew service (brew services stop …) or an app that restarts on its own. Stop whatever starts it, or click × again.",
         "Lo cerré, pero el propio macOS (launchd) lo volvió a iniciar: suele ser un servicio de Homebrew (brew services stop …) o una app que se reinicia sola. Detén lo que lo inicia, o pulsa × otra vez."),
        ("Encerrei, mas o processo %1 subiu outro (pid %2). Encerre quem o sobe, ou clique no × de novo.",
         "I quit it, but process %1 started another one (pid %2). Stop whatever starts it, or click × again.",
         "Lo cerré, pero el proceso %1 inició otro (pid %2). Detén lo que lo inicia, o pulsa × otra vez."),
        ("A porta %1 continua ocupada", "Port %1 is still in use", "El puerto %1 sigue ocupado"),
        ("Mandei encerrar e o processo %1 não soltou. No Terminal: kill -9 %2", "I asked it to quit and process %1 didn't let go. In Terminal: kill -9 %2",
         "Le pedí que se cerrara y el proceso %1 no lo soltó. En la Terminal: kill -9 %2"),
        ("Fechar o %1?", "Quit %1?", "¿Cerrar %1?"),
        ("Como o Cmd+Q: ele fecha as janelas e pergunta se houver algo sem salvar. Usa %1 agora.",
         "Like Cmd+Q: it closes its windows and asks if anything is unsaved. Using %1 right now.",
         "Como Cmd+Q: cierra sus ventanas y pregunta si hay algo sin guardar. Usa %1 ahora."),
        ("O %1 não fechou", "%1 didn't quit", "%1 no se cerró"),
        ("Encerrar %1 (pid %2)?", "Quit %1 (pid %2)?", "¿Cerrar %1 (pid %2)?"), ("Usa %1.", "Using %1.", "Usa %1."),
        ("Vão embora %1 processos do mesmo trabalho (como o Ctrl+C no terminal):", "%1 processes from the same job will go (like Ctrl+C in the terminal):",
         "Se van %1 procesos del mismo trabajo (como Ctrl+C en la terminal):"),
        ("O %1 continua aberto", "%1 is still running", "%1 sigue abierto"),
        ("Ele não é seu (é do sistema ou do root). No Terminal: sudo kill %1", "It isn't yours (it belongs to the system or root). In Terminal: sudo kill %1",
         "No es tuyo (es del sistema o de root). En la Terminal: sudo kill %1"),
        ("Mandei encerrar e ele não saiu. No Terminal: kill -9 %1", "I asked it to quit and it didn't. In Terminal: kill -9 %1",
         "Le pedí que se cerrara y no lo hizo. En la Terminal: kill -9 %1"),
        ("Liberou %1.", "Freed %1.", "Se liberaron %1."), ("%1 para limpar", "%1 to clean", "%1 para limpiar"),
        ("Limpar %1?", "Clean %1?", "¿Limpiar %1?"),
        ("Vão sair %1. %2", "%1 will go. %2", "Se irán %1. %2"),
        ("Limpar tudo, %1?", "Clean everything, %1?", "¿Limpiar todo, %1?"),
        ("Saem os caches dos apps e dos gerenciadores de pacote, os dados do Xcode e os registros. A Lixeira fica.",
         "App and package manager caches, Xcode data and logs will go. The Trash stays.",
         "Se van las cachés de las apps y de los gestores de paquetes, los datos de Xcode y los registros. La Papelera se queda."),
        ("%1 h %2 min", "%1 h %2 min", "%1 h %2 min"), ("%1 d %2 h", "%1 d %2 h", "%1 d %2 h"),
    ]
    // O mais específico primeiro: "de %1 previstos" tem de casar antes de "de %1".
    .sorted { $0.0.replacingOccurrences(of: "%", with: "").count > $1.0.replacingOccurrences(of: "%", with: "").count }
    .map { pt, en, es in
        var r = NSRegularExpression.escapedPattern(for: pt)
        for i in 1...4 { r = r.replacingOccurrences(of: "%\(i)", with: "(.+?)") }
        return Padrao(regex: try! NSRegularExpression(pattern: "^" + r + "$"), en: en, es: es)
    }
}
