Fingerprinting TLS clients with JA3
====

This article is a short guide to using JA3 for fingerprinting TLS clients, with possible use cases and a simple demo.

<noscript>
  <strong>Enable JavaScript to use the demo.</strong>
</noscript>
<!-- Yes, I'm a bad person who uses tables for layouts. -->
<table>
  <tr>
    <td>
      <button type="button" onclick="fingerprint()">Fingerprint me!</button>
    </td>
    <td>
      <blockquote>
        <p>Your JA3 fingerprint is: <tt id="ja3-fp">?</tt></p>
        <p>One in <span id="num-clients">?</span> clients have this value. That's <span id="entropy">?</span> bits of entropy.</p>
      </blockquote>
    </td>
  </tr>
</table>
<script type="text/javascript">
function fingerprint() {
  var reqFp = new XMLHttpRequest();
  reqFp.onreadystatechange = function(e) {
    if (reqFp.readyState != 4) return;
    if (reqFp.status != 200) {
      alert("An error occurred during the HTTP request (see console for details?)");
      return;
    }
    var fp = reqFp.responseText;
    document.getElementById("ja3-fp").textContent = fp;

    var reqMd = new XMLHttpRequest();
    reqMd.onreadystatechange = function(e) {
      if (reqMd.readyState != 4) return;
      if (reqMd.status != 200) {
        alert("An error occurred during the HTTP request (see console for details?)");
        return;
      }
      document.getElementById("num-clients").textContent = reqMd.responseText;
      var num = parseFloat(reqMd.responseText);
      document.getElementById("entropy").textContent = Math.log2(num).toFixed(3);
    };
    reqMd.open("GET", "https://jwlss.pw:8443/metadata", true);
    reqMd.send(null);
  };
  reqFp.open("GET", "https://jwlss.pw:8443/cached", true);
  reqFp.send(null);  
}
</script>

## How can you fingerprint TLS clients?

The principle behind JA3 fingerprinting is simple. Because TLS is a generic protocol supporting several extensions, [hundreds](https://www.iana.org/assignments/tls-parameters/tls-parameters.xhtml) of cipher suites and tens of elliptic curves, clients and servers must tell each other what features they support. Specifically, clients send this information in the Client Hello packet as part of the handshake in a standard, machine-readable way: this easily lends itself to creating a fingerprint of the client. JA3 does this simply concatenating the following fields:

 * SSL version
 * Accepted ciphers
 * List of extensions
 * Accepted elliptic curves
 * Accepted elliptic curve formats

and hashing them with MD5 to produce 32-character fingerprint that can be manipulated more easily. (The implementation is actually more complex due to bogus extensions intentionally introduced in TLS 1.3, but this is a high-level overview.)

## What are some possible use cases?

JA3 fingerprints effectively depend on the software being used to connect to a TLS service. This can be used as an datapoint for HTTPS or SSH honeypots, allowing for relatively fine-grained **classification of compromised devices in botnets**. Indeed, this is the context where I first heard of JA3, thanks to Remco Verhoef's work on [Honeytrap](https://github.com/honeytrap/honeytrap/commit/192795147948103a24d34dc06dba74eecdeb086b).

For the same reason, HTTPS/SSH servers in highly controlled environments could reasonably implement JA3-based **whitelisting** of known devices as an additional layer of security: even with correct credentials, an intruder with a bad client can be identified and denied access, logged, or even transparently redirected to a honeypot, with the intruder none the wiser.

The [HASSH blog post](https://engineering.salesforce.com/open-sourcing-hassh-abed3ae5044c) introduced the possibility of **countering data exfiltration based on SSH KEXINIT**, which may not be logged or detected by traditional means, with simple anomaly detection. Data exfiltration will produce a vast number of *different* kexinit messages, which can easily be turned into an alert.

As with all fingerprints, it poses an **opportunity to track users** for the advertising industry and a **threat for privacy enthusiasts**: JA3 fingerprints are effectively an equivalent of the User-Agent header, though less fine-grained and (at this time) impossible to change.

One more interesting scenario is **fingerprint-defined routing**, where an attacker who can MITM a connection can deduce vulnerabilities from the Client Hello and try to attack the connection, while transparently proxying patched clients to the correct destinations.

Finally, [this talk](https://www.youtube.com/watch?v=NI0Lmp0K1zc) by John Althouse (developer of JA3) goes into more detail on opportunities for client and server fingerprinting.

## Possible mitigations

Fingerprinting is most useful when each client is linked to a unique fingerprint. Clients that want to avoid or deceive fingerprinting can either adopt the fingerprint of common software (thus making it impossible to trace back a fingerprint to a specific client), or adopt unique fingerprints per connection.

At the implementation level this can translate to:

 * advertising dummy future ciphers each time in order to create unique fingerprints. This should be relatively safe since servers will ignore the dummy ciphers as unknown, but is not exactly future-proof, and may actually pose implementation difficulties in the future - what if a cipher ID is considered "dummy" by an old client, but actually implemented years later? The server may agree to using that cipher, and then the client would have to drop the connection since it can't actually use that cipher.
 
 * advertising dummy *old* ciphers each time in order to create unique fingerprints. This should be far safer: modern servers will ignore the old ciphers for being insecure, and insecure servers that accept these ciphers can be rejected by the client.

 * randomly toggling support for known ciphers, again in order to create unique fingerprints. The client must take care not to disable support for modern secure ciphers, lest it tricks itself into a downgrade attack.

 * implementing all ciphers used by a common client (eg. the latest version of Firefox). This introduces significant complexity, which may not be viable for applications like low-budget botnets.

## This demo

The demo at the top of a page is a simple HTTPS server that builds upon Remco's JA3 patches to the Go stdlib. You can find the source code [here](https://github.com/CapacitorSet/ja3-server).

---

><small>Released under [**CC-BY 4.0**](https://creativecommons.org/licenses/by/4.0/).
