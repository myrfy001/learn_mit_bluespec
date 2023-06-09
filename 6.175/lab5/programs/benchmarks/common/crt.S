# See LICENSE for license details.

#include "encoding.h"

#ifdef __riscv64
# define LREG ld
# define SREG sd
#else
# define LREG lw
# define SREG sw
#endif

  .text
  .align 6
user_trap_entry:
  j trap_entry

  .align 6
supervisor_trap_entry:
  j supervisor_trap_entry

  .align 6
hypervisor_trap_entry:
  j hypervisor_trap_entry

  .align 6
machine_trap_entry:
  j trap_entry

  .align 6
  .globl _start
_start:
  li  x1, 0
  li  x2, 0
  li  x3, 0
  li  x4, 0
  li  x5, 0
  li  x6, 0
  li  x7, 0
  li  x8, 0
  li  x9, 0
  li  x10,0
  li  x11,0
  li  x12,0
  li  x13,0
  li  x14,0
  li  x15,0
  li  x16,0
  li  x17,0
  li  x18,0
  li  x19,0
  li  x20,0
  li  x21,0
  li  x22,0
  li  x23,0
  li  x24,0
  li  x25,0
  li  x26,0
  li  x27,0
  li  x28,0
  li  x29,0
  li  x30,0
  li  x31,0

  # initialize global pointer
  la gp, _gp

  # init tp, make it 64B aligned
  la  tp, _end + 63
  and tp, tp, -64

  # allocate 128KB of stack + TLS for each thread
#define STKSHIFT 17
  csrr a0, mhartid
  sll a2, a0, STKSHIFT
  add tp, tp, a2
  add sp, a0, 1
  sll sp, sp, STKSHIFT
  add sp, sp, tp

  j _init

trap_entry:
  addi sp, sp, -272

  SREG x1, 8(sp)
  SREG x2, 16(sp)
  SREG x3, 24(sp)
  SREG x4, 32(sp)
  SREG x5, 40(sp)
  SREG x6, 48(sp)
  SREG x7, 56(sp)
  SREG x8, 64(sp)
  SREG x9, 72(sp)
  SREG x10, 80(sp)
  SREG x11, 88(sp)
  SREG x12, 96(sp)
  SREG x13, 104(sp)
  SREG x14, 112(sp)
  SREG x15, 120(sp)
  SREG x16, 128(sp)
  SREG x17, 136(sp)
  SREG x18, 144(sp)
  SREG x19, 152(sp)
  SREG x20, 160(sp)
  SREG x21, 168(sp)
  SREG x22, 176(sp)
  SREG x23, 184(sp)
  SREG x24, 192(sp)
  SREG x25, 200(sp)
  SREG x26, 208(sp)
  SREG x27, 216(sp)
  SREG x28, 224(sp)
  SREG x29, 232(sp)
  SREG x30, 240(sp)
  SREG x31, 248(sp)

  csrr a0, mcause
  csrr a1, mepc
  mv a2, sp
  jal handle_trap
  csrw mepc, a0

  LREG x1, 8(sp)
  LREG x2, 16(sp)
  LREG x3, 24(sp)
  LREG x4, 32(sp)
  LREG x5, 40(sp)
  LREG x6, 48(sp)
  LREG x7, 56(sp)
  LREG x8, 64(sp)
  LREG x9, 72(sp)
  LREG x10, 80(sp)
  LREG x11, 88(sp)
  LREG x12, 96(sp)
  LREG x13, 104(sp)
  LREG x14, 112(sp)
  LREG x15, 120(sp)
  LREG x16, 128(sp)
  LREG x17, 136(sp)
  LREG x18, 144(sp)
  LREG x19, 152(sp)
  LREG x20, 160(sp)
  LREG x21, 168(sp)
  LREG x22, 176(sp)
  LREG x23, 184(sp)
  LREG x24, 192(sp)
  LREG x25, 200(sp)
  LREG x26, 208(sp)
  LREG x27, 216(sp)
  LREG x28, 224(sp)
  LREG x29, 232(sp)
  LREG x30, 240(sp)
  LREG x31, 248(sp)

  addi sp, sp, 272
  mret

.section ".tdata.begin"
.globl _tdata_begin
_tdata_begin:

.section ".tdata.end"
.globl _tdata_end
_tdata_end:

.section ".tbss.end"
.globl _tbss_end
_tbss_end:
