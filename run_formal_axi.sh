#!/usr/bin/env bash
# run_formal_axi.sh — Pipeline correctness checks with real AXI4-Lite memory.
#
# Uses wrapper_axi.sv + axi_abstract_slave.sv so the solver exercises the
# actual AXI4-Lite FSM (boot_delay, ARWAIT/RWAIT, branch_pending) rather than
# the free-variable shortcut used by the plain riscv-formal run.
#
# Prerequisites: sby (SymbiYosys), yosys, boolector, python3.
# riscv-formal must already be present at ../riscv-formal (run run_formal.sh
# once if it is not, since that script clones it).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORMAL_AXI="$SCRIPT_DIR/formal_axi"
CHECKS_DIR="$FORMAL_AXI/checks"
LOGS_DIR="$FORMAL_AXI/logs"
RISCV_FORMAL="$SCRIPT_DIR/../riscv-formal"

# ── colour codes ─────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { printf "  ${GREEN}OK${NC}   %s\n" "$1"; }
fail() { printf "  ${RED}FAIL${NC} %s  →  %s\n" "$1" "$2"; }
info() { printf "${YELLOW}==>  ${NC}%s\n" "$1"; }

# ── prerequisites ─────────────────────────────────────────────────────────────
check_tool() {
    if ! command -v "$1" &>/dev/null; then
        echo "ERROR: '$1' not found. Install it and re-run."
        exit 1
    fi
}
check_tool sby
check_tool yosys
check_tool python3

if [[ ! -d "$RISCV_FORMAL" ]]; then
    echo "ERROR: riscv-formal not found at $RISCV_FORMAL"
    echo "Run ./run_formal.sh once first — it clones riscv-formal automatically."
    exit 1
fi

# ── generate sby check files ──────────────────────────────────────────────────
info "Generating AXI check files ..."
python3 "$FORMAL_AXI/gen_axi_checks.py"

mkdir -p "$LOGS_DIR"

# ── collect sby files ─────────────────────────────────────────────────────────
mapfile -t SBY_FILES < <(find "$CHECKS_DIR" -maxdepth 1 -name "*.sby" | sort)

if [[ ${#SBY_FILES[@]} -eq 0 ]]; then
    echo "ERROR: No .sby files found in $CHECKS_DIR"
    exit 1
fi

TOTAL=${#SBY_FILES[@]}
PASSED=0
FAILED=0
FAILED_NAMES=()

info "Running $TOTAL AXI pipeline checks  (this may take a while) ..."
echo ""

# ── run each check ────────────────────────────────────────────────────────────
for sby_file in "${SBY_FILES[@]}"; do
    check_name="$(basename "$sby_file" .sby)"
    log_file="$LOGS_DIR/${check_name}.log"

    # sby is run from CHECKS_DIR so its work directories land there.
    if (cd "$CHECKS_DIR" && sby -f "${check_name}.sby") > "$log_file" 2>&1; then
        pass "$check_name"
        (( PASSED++ )) || true
    else
        reason="$(grep -m1 -E '^(FAIL|ERROR|Assert failed|UNKNOWN)' \
                  "$log_file" 2>/dev/null || echo "see log")"
        fail "$check_name" "$reason"
        FAILED_NAMES+=("$check_name")
        (( FAILED++ )) || true
    fi
done

# ── summary ───────────────────────────────────────────────────────────────────
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
printf "${GREEN}All AXI pipeline checks passed.${NC}\n"
