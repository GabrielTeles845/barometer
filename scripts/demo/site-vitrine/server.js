require("http").createServer((q,r)=>r.end("ok")).listen(process.argv[2],"127.0.0.1")
