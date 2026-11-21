#!/usr/bin/env bash
# Stage WINQ-EMU binaries and firmware for Windows distribution.
# Run from the repository root in an MSYS2 UCRT64 shell.
set -euo pipefail
mkdir -p installer/bin/share installer/icons
cp launcher/winq-emu.ico installer/icons/winq-emu.ico

# Use the built fork directly, rather than depending on Meson install.
# The NSIS installer expects binaries in installer/bin and the ROMs
# in installer/bin/share, exactly as in upstream's installer.nsi.
for exe in qemu-system-x86_64.exe qemu-system-x86_64w.exe qemu-img.exe; do
  cp "_deps/qemu/build/$exe" installer/bin/
done
cp /ucrt64/bin/libvirglrenderer-1.dll installer/bin/

# Build-generated and source firmware are not under
# /ucrt64/share/qemu on this QEMU fork. Stage them explicitly.
shopt -s nullglob
for firmware in _deps/qemu/pc-bios/*.{bin,rom,fd}; do
  cp "$firmware" installer/bin/share/
done
mkdir -p installer/bin/share/keymaps installer/bin/share/firmware
cp -a _deps/qemu/pc-bios/keymaps/. installer/bin/share/keymaps/
if [[ -d _deps/qemu/build/pc-bios/descriptors ]]; then
  cp -a _deps/qemu/build/pc-bios/descriptors/. installer/bin/share/firmware/
fi
shopt -u nullglob

# Inspect PE import tables rather than relying on a hard-coded
# C:\msys64 path or executing binaries with ldd. Copy only DLLs
# actually available under the UCRT64 prefix (not Windows DLLs).
declare -A scanned=()
collect_deps() {
  local binary="$1" dll lower found
  while IFS= read -r dll; do
    lower="${dll,,}"
    [[ -n "${scanned[$lower]:-}" ]] && continue
    scanned[$lower]=1
    found="$(find /ucrt64/bin -maxdepth 1 -type f -iname "$dll" -print -quit)"
    if [[ -n "$found" ]]; then
      cp -n "$found" installer/bin/
      collect_deps "$found"
    fi
  done < <(objdump -p "$binary" | sed -nE \
    's/^[[:space:]]*DLL Name:[[:space:]]*([^[:space:]]+).*/\1/p')
}
for binary in installer/bin/*.exe installer/bin/*.dll; do
  collect_deps "$binary"
done

# The installer explicitly requires BIOS ROMs and keymaps.
compgen -G 'installer/bin/share/*.bin' >/dev/null
compgen -G 'installer/bin/share/*.rom' >/dev/null
test -s installer/bin/share/bios.bin
test -d installer/bin/share/keymaps
compgen -G 'installer/bin/share/keymaps/*' >/dev/null
echo "Packaged $(find installer/bin -iname '*.dll' | wc -l) DLLs"
echo "Firmware files: $(find installer/bin/share -maxdepth 1 -type f | wc -l)"
