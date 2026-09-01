#!/usr/bin/env python3
"""Write a Debian .deb ar archive.

A .deb is a plain ar archive with three members in a fixed order:
debian-binary, control.tar.gz, data.tar.gz. Written here rather than shelled
out to ar because macOS ships BSD ar, which emits a symbol table and a
different header variant that dpkg refuses - and requiring GNU binutils just to
concatenate three files would put a toolchain between the build and the
package for no reason.

The format is fixed-width text headers, each member padded to an even offset.
Usage: mkar.py OUT MEMBER...
"""
import sys, os

def main():
    out, members = sys.argv[1], sys.argv[2:]
    # Fixed mtime so the same inputs give the same bytes; the deb's own
    # reproducibility depends on the tarballs, but the archive should not undo
    # it by stamping the moment it ran.
    mtime = int(os.environ.get("SOURCE_DATE_EPOCH", "1767225600"))
    with open(out, "wb") as f:
        f.write(b"!<arch>\n")
        for m in members:
            data = open(m, "rb").read()
            name = os.path.basename(m)
            # name(16) mtime(12) uid(6) gid(6) mode(8) size(10) magic(2)
            f.write("{:<16}{:<12}{:<6}{:<6}{:<8}{:<10}".format(
                name, mtime, 0, 0, "100644", len(data)).encode())
            f.write(b"`\n")
            f.write(data)
            if len(data) % 2:
                f.write(b"\n")   # members start on an even offset

if __name__ == "__main__":
    main()
