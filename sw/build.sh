#!/usr/bin/env bash
# Assemble bubble_sort.s and produce a Vivado .coe file for IMEM.
# Requires the RISC-V GNU toolchain (riscv32-unknown-elf-* or riscv64-unknown-elf-*).
set -euo pipefail

# riscv64-unknown-elf-* targets RV32I when given -march=rv32i -mabi=ilp32
AS=riscv64-unknown-elf-as
LD=riscv64-unknown-elf-ld
OBJCOPY=riscv64-unknown-elf-objcopy

build_coe() {
    local name="$1"
    $AS -march=rv32i -mabi=ilp32 -o "${name}.o" "${name}.s"
    $LD -m elf32lriscv -Ttext=0x00000000 --no-warn-rwx-segments -o "${name}.elf" "${name}.o"
    $OBJCOPY -O binary "${name}.elf" "${name}.bin"
    python3 - "${name}" <<'EOF'
import struct, sys

name = sys.argv[1]
with open(f"{name}.bin", "rb") as f:
    raw = f.read()

if len(raw) % 4:
    raw += b'\x00' * (4 - len(raw) % 4)

words = [struct.unpack_from("<I", raw, i)[0] for i in range(0, len(raw), 4)]

with open(f"{name}.coe", "w") as f:
    f.write("memory_initialization_radix=16;\n")
    f.write("memory_initialization_vector=\n")
    for i, w in enumerate(words):
        sep = ";" if i == len(words) - 1 else ","
        f.write(f"{w:08X}{sep}\n")

print(f"Generated {name}.coe  ({len(words)} words / {len(words)*4} bytes)")
EOF
}

build_coe bubble_sort
build_coe swap

echo "Done. Load the desired .coe into the IMEM Block Memory Generator."
