# swap.s — swap two words in DMEM and verify
#
# DMEM base address: 0x00004000  (lui x1, 4 → x1 = 4 << 12 = 0x4000)
#
# Expected final register values:
#   x1 = 0x4000   x2 = 5   x3 = 3
#   x4 = 5        x5 = 3
#   x6 = 3        x7 = 5   (verify: mem[0x4000]=3, mem[0x4004]=5)
#
# Byte offset  Hex encoding  Instruction
# -----------  ------------  -----------

.section .text
.globl _start
_start:
    lui  x1,  4         # 0x00: 000040B7   x1 = 0x00004000
    addi x2,  x0, 5    # 0x04: 00500113   x2 = 5
    sw   x2,  0(x1)    # 0x08: 0020A023   mem[0x4000] = 5
    addi x3,  x0, 3    # 0x0C: 00300193   x3 = 3
    sw   x3,  4(x1)    # 0x10: 0030A223   mem[0x4004] = 3
    lw   x4,  0(x1)    # 0x14: 0000A203   x4 = mem[0x4000] = 5
    lw   x5,  4(x1)    # 0x18: 0040A283   x5 = mem[0x4004] = 3
    sw   x5,  0(x1)    # 0x1C: 0050A023   mem[0x4000] = x5 = 3  (swap)
    sw   x4,  4(x1)    # 0x20: 0040A223   mem[0x4004] = x4 = 5  (swap)
    lw   x6,  0(x1)    # 0x24: 0000A303   x6 = mem[0x4000] = 3  (verify)
    lw   x7,  4(x1)    # 0x28: 0040A383   x7 = mem[0x4004] = 5  (verify)
halt:
    jal  x0,  0        # 0x2C: 0000006F   halt — self-branch
