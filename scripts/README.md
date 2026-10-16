# Scripts

Ferramentas para as imagens do README. Nada aqui entra no app.

| Script | O que faz |
|---|---|
| `fotos.sh` | Tira as fotos de cada aba (inglês e português) e monta os banners |
| `gif.sh` | Tira os quadros e monta os dois GIFs do README (`docs/images/tour.gif` e `pt/tour.gif`) |
| `demo/` | Quatro servidores de mentira (`node server.js <porta>`) para a aba Portas ter o que mostrar nas fotos |

Os dois scripts compilam o app (`swift build -c release`), ligam os servidores de exemplo só durante as fotos e
desligam pela porta no fim, mesmo se der erro no meio. Precisam do `node` e do `ffmpeg`.

```sh
bash scripts/fotos.sh
bash scripts/gif.sh
```
