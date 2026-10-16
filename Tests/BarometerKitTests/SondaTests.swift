// A leitura do `lsof` e o nome do projeto de cada porta.

import Foundation
import Testing
@testable import BarometerKit

@Suite("Portas")
struct SondaTests {
    static let saida = """
    COMMAND     PID   USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
    node      51234 gabriel   23u  IPv6 0x1234567890abcdef      0t0  TCP *:3000 (LISTEN)
    node      51234 gabriel   24u  IPv4 0x1234567890abcdee      0t0  TCP 127.0.0.1:3000 (LISTEN)
    Code\\x20Helper 777 gabriel 30u IPv4 0x1               0t0  TCP 127.0.0.1:52011 (LISTEN)
    redis-ser   900 gabriel    6u  IPv6 0x2                0t0  TCP [::1]:6379 (LISTEN)
    rapportd    410 gabriel    9u  IPv4 0x3                0t0  TCP *:49152 (LISTEN)
    node      51234 gabriel   25u  IPv4 0x4                0t0  TCP 127.0.0.1:3000->127.0.0.1:60000 (ESTABLISHED)
    """

    @Test("Lê número, processo e endereço de uma linha")
    func interpretaLinha() throws {
        let p = try #require(Sonda.interpretar("node 51234 gabriel 23u IPv6 0x1 0t0 TCP *:3000 (LISTEN)"))
        #expect(p.numero == 3000)
        #expect(p.pid == 51234)
        #expect(p.comando == "node")
        #expect(p.endereco == "*")
    }

    @Test("Endereço IPv6 com vários dois-pontos: a porta é o que vem depois do último")
    func ipv6() throws {
        let p = try #require(Sonda.interpretar("redis 900 g 6u IPv6 0x2 0t0 TCP [::1]:6379 (LISTEN)"))
        #expect(p.numero == 6379)
        #expect(p.endereco == "::1")
    }

    @Test("Nome com espaço escapado volta com espaço")
    func nomeComEspaco() throws {
        let p = try #require(Sonda.interpretar("Code\\x20Helper 777 g 30u IPv4 0x1 0t0 TCP 127.0.0.1:52011 (LISTEN)"))
        #expect(p.comando == "Code Helper")
    }

    @Test("Linha que não é LISTEN fica de fora")
    func soOuvindo() {
        #expect(Sonda.interpretar("node 1 g 25u IPv4 0x4 0t0 TCP 127.0.0.1:3000->127.0.0.1:60000 (ESTABLISHED)") == nil)
        #expect(Sonda.interpretar("COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME") == nil)
    }

    @Test("IPv4 e IPv6 da mesma porta viram uma só, a de escopo mais largo")
    func umaPorNumero() {
        let portas = Sonda.portas(daSaidaDoLsof: Self.saida)
        #expect(portas.map(\.numero) == [3000, 6379, 49152, 52011])
        #expect(portas.first { $0.numero == 3000 }?.endereco == "*")
    }

    @Test("Portas altas e de sistema ficam escondidas; as de projeto aparecem")
    func oQueInteressa() {
        let portas = Sonda.portas(daSaidaDoLsof: Self.saida)
        let visiveis = portas.filter(Sonda.interessa).map(\.numero)
        #expect(visiveis.contains(3000))
        #expect(!visiveis.contains(49152))
        #expect(!visiveis.contains(52011))
    }

    @Test("A linha de comando vira um resumo curto")
    func resumo() {
        #expect(Sonda.resumir("/usr/local/bin/node /Users/a/proj/node_modules/.bin/next start", nomeDoProcesso: "node")
                == "node next start")
        #expect(Sonda.resumir("next-server (v14.2.24)", nomeDoProcesso: "node") == "next-server (v14.2.24)")
        #expect(Sonda.resumir("", nomeDoProcesso: "redis-server") == "redis-server")
    }

    @Test("O projeto vem do package.json, ou da pasta do git")
    func projeto() throws {
        let raiz = FileManager.default.temporaryDirectory.appendingPathComponent("barometer-teste-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: raiz) }
        let loja = raiz.appendingPathComponent("minha-loja/src")
        try FileManager.default.createDirectory(at: loja, withIntermediateDirectories: true)
        try #"{"name": "loja-do-cafe"}"#.write(to: raiz.appendingPathComponent("minha-loja/package.json"), atomically: true, encoding: .utf8)
        let api = raiz.appendingPathComponent("api/cmd")
        try FileManager.default.createDirectory(at: api, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: raiz.appendingPathComponent("api/.git"), withIntermediateDirectories: true)
        let modelo = raiz.appendingPathComponent("site")
        try FileManager.default.createDirectory(at: modelo, withIntermediateDirectories: true)
        try #"{"name": "my-app"}"#.write(to: modelo.appendingPathComponent("package.json"), atomically: true, encoding: .utf8)

        let sonda = Sonda()
        #expect(sonda.projeto(de: loja.path, casa: raiz.path) == "loja-do-cafe")
        #expect(sonda.projeto(de: api.path, casa: raiz.path) == "api")
        // Nome genérico de modelo ("my-app") diz pouco: fica o nome da pasta.
        #expect(sonda.projeto(de: modelo.path, casa: raiz.path) == "site")
    }

    @Test("Docker é reconhecido pelo nome do processo")
    func docker() {
        #expect(Porta.ehDocker("com.docker.backend"))
        #expect(!Porta.ehDocker("node"))
    }
}
