# Scripts

Ferramentas para as imagens do README. Nada aqui entra no app.

| Script | O que faz |
|---|---|
| `fotos.sh` | Tira as fotos de cada aba (inglês e português) e monta os banners |
| `gif.sh` | Tira os quadros e monta os dois GIFs do README (`docs/images/tour.gif` e `pt/tour.gif`) |
| `montar-app.sh` | Monta o `Barometer.app` a partir do binário (usado pelo `instalar.sh` e pelo `versao.sh`) |
| `versao.sh` | A versão para baixar: compila em release, monta o app com a versão do arquivo `VERSAO` e compacta em `dist/` |
| `demo/` | Quatro servidores de mentira (`node server.js <porta>`) para a aba Portas ter o que mostrar nas fotos |

Os dois scripts compilam o app (`swift build -c release`), ligam os servidores de exemplo só durante as fotos e
desligam pela porta no fim, mesmo se der erro no meio. Precisam do `node` e do `ffmpeg`.

```sh
bash scripts/fotos.sh
bash scripts/gif.sh
```

## Publicar uma versão

1. Trocar o número em `VERSAO` (1.0.0, 1.1.0…) e fazer o commit.
2. `bash scripts/versao.sh` (sai `dist/Barometer-<versão>.zip` e o `.sha256`).
3. `gh release create v<versão> dist/Barometer-<versão>.zip dist/Barometer-<versão>.zip.sha256 --title "Barometer <versão>" --notes-file <notas>`.

O app vai com assinatura local (ad hoc), sem conta paga da Apple: o macOS bloqueia na primeira abertura e o README
ensina o "Abrir Mesmo Assim".
