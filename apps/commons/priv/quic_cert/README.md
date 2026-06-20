# QUIC dev certificate

Self-signed localhost certificate for the QUIC transport in development.

**Dev only. Never use these in production.** The private key is committed for
zero-setup local runs; a real deployment must supply its own cert/key (or a
pinned CA) out of band.

Regenerate with:

```sh
openssl ecparam -genkey -name prime256v1 -noout -out key.pem
openssl req -new -x509 -key key.pem -out cert.pem -days 3650 -subj "/CN=localhost"
openssl ec  -in key.pem  -outform DER -out key.der
openssl x509 -in cert.pem -outform DER -out cert.der
```

erlang_quic is fed the **DER** files (`cert.der`, `key.der`); the PEM copies are
kept for inspection/regeneration. The EC key DER decodes to an `'ECPrivateKey'`
record, which is what `quic_tls:convert_private_key/2` expects.
