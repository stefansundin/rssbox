Drop your TLS certificate files here and the puma config will automatically use it and bind to port `PORT_TLS` (fallback to 9292).

Use `.crt` for the public certificate file and `.key` for the private key file, e.g. `rssbox.example.com.crt` and `rssbox.example.com.key`.

You can also generate a self-signed certificate with:

```
openssl req -x509 -nodes -days 36500 -newkey rsa:2048 -keyout selfsigned.key -out selfsigned.crt -subj "/"
```

If you use Docker then you can add your cert on top of the official image with a `Dockerfile` that looks something like this:

```
FROM stefansundin/rssbox
COPY rssbox.example.com.crt rssbox.example.com.key config/certs/
```

And run:

```
docker build -t rssbox-tls .
```
