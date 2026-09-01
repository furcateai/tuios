# Packaging

`build-deb.sh` turns the cross-compiled binaries in `dist/` into `.deb`
packages, one per architecture.

```sh
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o dist/tuios-linux-amd64 ./cmd/tuios
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o dist/tuios-web-linux-amd64 ./cmd/tuios-web
# and the same for arm64
packaging/build-deb.sh 1.0.0
```

Needs GNU tar (`gtar`) for `--sort` and `--mtime`, which are what make the
package reproducible — without a fixed order and timestamp two builds of the
same tree differ, and then a checksum cannot answer whether a machine is
running what was built. It does not need `dpkg-deb`: `mkar.py` writes the ar
archive directly, because macOS ships BSD ar (which emits a header variant dpkg
refuses) and requiring GNU binutils to concatenate three files would put a
toolchain between the build and the package for no reason.

## Everything ships under /usr

`furcate-cli`'s `deploy/build-sysext.sh` refuses any package carrying `/etc`,
and it is right to: a sysext is replaced wholesale on every update, so an `/etc`
shipped inside one would take an operator's edits with it.

So both configuration files ship as candidates under
`/usr/share/furcate/tui/`, and the postinst adopts them into `/etc`. That is
the distribution's existing convention rather than a new one —
`/usr/share/furcate/profile.sh` is adopted into `/etc/profile.d` by
`deploy/os/adopt` in exactly the same way.

Adoption never writes over an edited file. Each adopted copy is stamped in
`/var/lib/furcate-tui/`, and the comparison is against that stamp rather than
against the new candidate: comparing against the candidate would call every
upgrade an edit. A file the operator changed is kept, and the package says so
and names the new default. Purge takes back only what was never touched.

## Verifying a build

```sh
dpkg-deb --info  dist/furcate-tui_1.0.0_amd64.deb
dpkg-deb --contents dist/furcate-tui_1.0.0_amd64.deb

# the check build-sysext.sh will apply
dpkg-deb -x dist/furcate-tui_1.0.0_amd64.deb /tmp/x
find /tmp/x -mindepth 1 -maxdepth 1 ! -name usr ! -name opt
```

The last command printing nothing is the whole test: the split between what
belongs to the image and what belongs to the machine is real if an extension
can be built from the package, and decorative if it cannot.
