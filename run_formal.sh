#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORMAL_DIR="$SCRIPT_DIR/formal"
RISCV_FORMAL_DIR="$SCRIPT_DIR/../riscv-formal"
# genchecks.py computes basedir=CWD/../.. so it must run from two levels
# deep inside riscv-formal (the standard cores/<name>/ layout).
STAGING_DIR="$RISCV_FORMAL_DIR/cores/riscv-osu-main"
CHECKS_DIR="$STAGING_DIR/checks"
LOGS_DIR="$FORMAL_DIR/logs"

# ── colour codes ────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { printf "  ${GREEN}OK${NC}   %s\n" "$1"; }
fail() { printf "  ${RED}FAIL${NC} %s  →  %s\n" "$1" "$2"; }
info() { printf "${YELLOW}==>  ${NC}%s\n" "$1"; }

# ── prerequisites ────────────────────────────────────────────────────────────
check_tool() {
    if ! command -v "$1" &>/dev/null; then
        echo "ERROR: '$1' not found. Install it and re-run."
        echo "  yosys / sby (symbiyosys) / bitwuzla or z3 are all required."
        exit 1
    fi
}
check_tool yosys
check_tool sby
check_tool python3

# ── clone riscv-formal if needed ─────────────────────────────────────────────
if [[ ! -d "$RISCV_FORMAL_DIR" ]]; then
    info "Cloning YosysHQ/riscv-formal ..."
    git clone --depth 1 https://github.com/YosysHQ/riscv-formal.git "$RISCV_FORMAL_DIR"
fi

# ── set up staging directory inside riscv-formal ─────────────────────────────
# genchecks.py reads checks.cfg from CWD and resolves basedir=CWD/../..
# so the staging dir must be two levels deep inside the riscv-formal tree.
info "Setting up staging directory ..."
mkdir -p "$STAGING_DIR"

# Symlink formal/checks.cfg so edits there are reflected immediately.
ln -sf "$FORMAL_DIR/checks.cfg" "$STAGING_DIR/checks.cfg"

# Symlink the formal wrapper.
ln -sf "$FORMAL_DIR/wrapper.sv" "$STAGING_DIR/wrapper.sv"

# Symlink RTL source files preserving subdirectory structure.
for rel in core_config.svh riscv_pkg.sv topmodule_RISCV.sv IFID_reg.sv IDEX_reg.sv EXMEM_reg.sv MEMWB_reg.sv \
           cu.sv forward.sv hazard_unit.sv; do
    ln -sf "$SCRIPT_DIR/$rel" "$STAGING_DIR/$rel"
done
for subdir in IF ID EX MEM WB; do
    mkdir -p "$STAGING_DIR/$subdir"
    for f in "$SCRIPT_DIR/$subdir"/*.sv; do
        [[ -f "$f" ]] && ln -sf "$f" "$STAGING_DIR/$subdir/$(basename "$f")"
    done
done

# ── generate .sby check files ────────────────────────────────────────────────
info "Generating check files from checks.cfg ..."
(
    cd "$STAGING_DIR"
    # genchecks.py writes the .sby files into a 'checks/' subdirectory
    python3 "$RISCV_FORMAL_DIR/checks/genchecks.py"
)

mkdir -p "$LOGS_DIR"

# ── collect .sby files ───────────────────────────────────────────────────────
mapfile -t SBY_FILES < <(find "$CHECKS_DIR" -maxdepth 1 -name "*.sby" | sort)

if [[ ${#SBY_FILES[@]} -eq 0 ]]; then
    echo "ERROR: No .sby files found in $CHECKS_DIR"
    exit 1
fi

TOTAL=${#SBY_FILES[@]}
PASSED=0
FAILED=0
FAILED_NAMES=()

info "Running $TOTAL checks  (this may take a while) ..."
echo ""

# ── run each check ────────────────────────────────────────────────────────────
for sby_file in "${SBY_FILES[@]}"; do
    check_name="$(basename "$sby_file" .sby)"
    log_file="$LOGS_DIR/${check_name}.log"

    # sby exits 0 on PASS, non-zero on FAIL/ERROR
    # Run from STAGING_DIR so relative paths in generated .sby files resolve correctly
    if (cd "$STAGING_DIR" && sby -f "checks/${check_name}.sby") > "$log_file" 2>&1; then
        pass "$check_name"
        (( PASSED++ )) || true
    else
        # Extract the first FAIL/ERROR line for a terse hint
        reason="$(grep -m1 -E '^(FAIL|ERROR|Assert failed|UNKNOWN)' "$log_file" 2>/dev/null || echo "see log")"
        fail "$check_name" "$reason"
        FAILED_NAMES+=("$check_name")
        (( FAILED++ )) || true
    fi
done

# ── summary ──────────────────────────────────────────────────────────────────
echo ""
echo "────────────────────────────────────────"
printf "  Passed : ${GREEN}%d${NC} / %d\n" "$PASSED" "$TOTAL"
printf "  Failed : ${RED}%d${NC} / %d\n"  "$FAILED" "$TOTAL"
echo "────────────────────────────────────────"

if [[ $FAILED -gt 0 ]]; then
    echo ""
    echo "Failed checks:"
    for name in "${FAILED_NAMES[@]}"; do
        printf "  ${RED}✗${NC}  %s\n" "$name"
        printf "     Log: %s\n" "$LOGS_DIR/${name}.log"
    done
    echo ""
    exit 1
fi

echo ""
printf "${GREEN}All checks passed.${NC}\n"
