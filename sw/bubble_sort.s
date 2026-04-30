# =============================================================================
# bubble_sort.s — RV32I Bubble Sort
# =============================================================================
# Sorts 8 unsigned words stored in DMEM, then loads the sorted values back
# into registers so you can read them from the debug port or an ILA.
#
# Memory map assumption (match your Vivado Address Editor):
#   IMEM base : 0x0000   (PC starts here)
#   DMEM base : 0x4000   (lui immediate = 0x10)
#
# Input  (written at runtime): [4, 7, 2, 8, 1, 6, 3, 5]
# Output (sorted ascending)  : [1, 2, 3, 4, 5, 6, 7, 8]
#
# Register values at halt — verify these in Vivado:
#   a1 = 1   a2 = 2   a3 = 3   a4 = 4
#   a5 = 5   a6 = 6   a7 = 7   a0 = 8
# =============================================================================

.section .text
.globl _start
_start:

# -----------------------------------------------------------------------------
# 1. Store unsorted array into DMEM
#    s0 = DMEM base address (preserved for the whole program)
# -----------------------------------------------------------------------------
    lui  s0, 0x4           # s0 = 0x00010000

    li   t0, 4
    sw   t0,  0(s0)        # dmem[0x10000] = 4

    li   t0, 7
    sw   t0,  4(s0)        # dmem[0x10004] = 7

    li   t0, 2
    sw   t0,  8(s0)        # dmem[0x10008] = 2

    li   t0, 8
    sw   t0, 12(s0)        # dmem[0x1000C] = 8

    li   t0, 1
    sw   t0, 16(s0)        # dmem[0x10010] = 1

    li   t0, 6
    sw   t0, 20(s0)        # dmem[0x10014] = 6

    li   t0, 3
    sw   t0, 24(s0)        # dmem[0x10018] = 3

    li   t0, 5
    sw   t0, 28(s0)        # dmem[0x1001C] = 5

# -----------------------------------------------------------------------------
# 2. Bubble sort
#
#    s0 = array base  (0x00010000, constant)
#    s1 = i           (outer loop counter)
#    s2 = j           (inner loop counter)
#    a0 = N           (element count = 8)
#    t0 = N-1
#    t1 = N-1-i       (inner loop limit for this pass)
#    t2 = j*4         (byte offset)
#    t3 = &array[j]
#    t4 = array[j]
#    t5 = array[j+1]
# -----------------------------------------------------------------------------
    li   s1, 0             # i = 0
    li   a0, 8             # N = 8

outer:
    addi t0, a0, -1        # t0 = N-1 = 7
    bge  s1, t0, done      # if i >= 7: sort complete

    li   s2, 0             # j = 0
    sub  t1, t0, s1        # t1 = N-1-i  (number of comparisons this pass)

inner:
    bge  s2, t1, next_i    # if j >= N-1-i: next outer pass

    slli t2, s2, 2         # t2 = j * 4
    add  t3, s0, t2        # t3 = base + j*4  =  &array[j]
    lw   t4, 0(t3)         # t4 = array[j]
    lw   t5, 4(t3)         # t5 = array[j+1]

    ble  t4, t5, no_swap   # array[j] <= array[j+1]: already in order

    sw   t5, 0(t3)         # array[j]   = array[j+1]
    sw   t4, 4(t3)         # array[j+1] = array[j]

no_swap:
    addi s2, s2, 1         # j++
    j    inner

next_i:
    addi s1, s1, 1         # i++
    j    outer

# -----------------------------------------------------------------------------
# 3. Load sorted values into registers for verification
#    s0 still = 0x00010000
#
#    Expected at halt:
#      a1=1  a2=2  a3=3  a4=4  a5=5  a6=6  a7=7  a0=8
# -----------------------------------------------------------------------------
done:
    lw   a1,  0(s0)        # sorted[0]  →  expect 1
    lw   a2,  4(s0)        # sorted[1]  →  expect 2
    lw   a3,  8(s0)        # sorted[2]  →  expect 3
    lw   a4, 12(s0)        # sorted[3]  →  expect 4
    lw   a5, 16(s0)        # sorted[4]  →  expect 5
    lw   a6, 20(s0)        # sorted[5]  →  expect 6
    lw   a7, 24(s0)        # sorted[6]  →  expect 7
    lw   a0, 28(s0)        # sorted[7]  →  expect 8

halt:
    j    halt              # spin — inspect registers here
