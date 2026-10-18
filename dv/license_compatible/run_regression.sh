#!/usr/bin/env bash
# License-compatible directed regression for NX-AXI DMA.
# Does not use UVM, randomize, randcase, randsequence, or covergroups.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LC="$ROOT/dv/license_compatible"
SIM="$LC/sim"
LOGDIR="$SIM/logs"
QUESTA_HOME="${QUESTA_HOME:-/home/nitish/altera_pro/26.1_fe/questa_fe}"
export PATH="$QUESTA_HOME/bin:$PATH"
export SALT_LICENSE_SERVER="${SALT_LICENSE_SERVER:-/home/nitish/altera_pro/licenses/LR-194177_License.dat}"

mkdir -p "$LOGDIR"
cd "$LC"

TESTS=(
  reset_regs
  axil_rw
  direct_16b
  direct_64b
  direct_256b
  unaligned
  cross_4kb
  multi_channel
  arb_rr
  arb_fixed
  sg_chain
  irq
  err_zero_len
  err_unaligned_desc
  err_slverr_rd
  err_decerr_wr
  pause_resume
  abort
  ready_stall
  outstanding
  sg_deep
  abort_race
  cross_4kb_corner
)

if [[ "${1:-}" != "" && "${1:-}" != "all" ]]; then
  TESTS=("$1")
fi

echo "============================================================"
echo "NX-AXI license-compatible regression"
echo "QUESTA_HOME=$QUESTA_HOME"
echo "SALT_LICENSE_SERVER=$SALT_LICENSE_SERVER"
echo "============================================================"

rm -rf "$SIM/work"
vlib "$SIM/work"
vmap work "$SIM/work" >"$LOGDIR/vmap.log"

COMPILE_LOG="$LOGDIR/compile.log"
echo "[LC] Compiling..."
set +e
vlog -64 -sv -work work -f filelist.f -l "$COMPILE_LOG"
VLOG_RC=$?
set -e
if [[ $VLOG_RC -ne 0 ]]; then
  echo "[LC] COMPILE FAIL (see $COMPILE_LOG)"
  exit 1
fi
echo "[LC] COMPILE PASS"

OPT_LOG="$LOGDIR/opt.log"
echo "[LC] Elaborating..."
set +e
vopt -64 -work work nx_dma_lc_tb -o nx_dma_lc_tb_opt -l "$OPT_LOG"
VOPT_RC=$?
set -e
if [[ $VOPT_RC -ne 0 ]]; then
  echo "[LC] ELABORATE FAIL (see $OPT_LOG)"
  exit 1
fi
echo "[LC] ELABORATE PASS"

FAILS=0
PASSES=0
for t in "${TESTS[@]}"; do
  tlog="$LOGDIR/${t}.log"
  echo "[LC] RUN $t"
  set +e
  vsim -64 -c -lib work -dpicpppath /usr/bin/gcc nx_dma_lc_tb_opt \
    +LC_TEST="$t" \
    -do "run -all; quit -f" \
    -l "$tlog"
  RC=$?
  set -e
  if grep -q "\[LC\] SUITE PASS" "$tlog" && ! grep -q "\[LC\] SUITE FAIL" "$tlog"; then
    echo "  PASS $t"
    PASSES=$((PASSES+1))
  else
    echo "  FAIL $t  (rc=$RC, log=$tlog)"
    FAILS=$((FAILS+1))
  fi
done

echo "============================================================"
echo "[LC] REGRESSION pass=$PASSES fail=$FAILS"
if [[ $FAILS -ne 0 ]]; then
  echo "[LC] REGRESSION FAIL"
  exit 1
fi
echo "[LC] REGRESSION PASS"
exit 0
