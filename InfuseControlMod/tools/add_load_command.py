#!/usr/bin/env python3
# Adds a single LC_LOAD_DYLIB load command to a Mach-O (thin or fat) so the app
# loads our tweak at launch. Idempotent: skips arch slices that already load it.
#
# Usage: add_load_command.py <macho_path> <dylib_install_path>
import sys

try:
    import lief
except ImportError:
    sys.exit("lief not installed (pip install lief)")

def main():
    if len(sys.argv) != 3:
        sys.exit("usage: add_load_command.py <macho> <dylib_install_path>")
    macho, dylib = sys.argv[1], sys.argv[2]

    fat = lief.MachO.parse(macho)
    if fat is None:
        sys.exit(f"could not parse Mach-O: {macho}")

    added = 0
    for binary in fat:
        names = [lib.name for lib in binary.libraries]
        if dylib in names:
            continue
        binary.add_library(dylib)
        added += 1

    fat.write(macho)
    print(f"add_load_command: ensured '{dylib}' is loaded ({added} slice(s) updated) in {macho}")

if __name__ == "__main__":
    main()
