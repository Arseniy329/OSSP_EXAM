// prng.asm — PRNG seeding and random number generation
// macOS ARM64 (Apple Silicon)

.section __TEXT,__text,regular,pure_instructions
.p2align 2

// ── Syscall base number (0x2000000 class applied via movk) ──
.equ SYS_gettimeofday, 0x74

// ── Exported symbols ──
.globl seed_prng
.globl rand_next
.globl rand_range

// =====================================================================
//  seed_prng — seed the LCG from gettimeofday's tv_usec field
//  Returns:  x0 = seed value
//  Clobbers: x0-x3, x9, x16
// =====================================================================
seed_prng:
    adrp    x9, timeval_buf@PAGE
    add     x9, x9, timeval_buf@PAGEOFF
    mov     x0, x9                          // timeval *
    mov     x1, #0                          // timezone = NULL
    mov     x16, #SYS_gettimeofday
    movk    x16, #0x200, lsl #16            // 0x2000000 class
    svc     #0x80

    ldr     x2, [x9, #8]                   // tv_usec
    adrp    x3, seed32@PAGE
    add     x3, x3, seed32@PAGEOFF
    str     w2, [x3]
    mov     x0, x2
    ret

// =====================================================================
//  rand_next — advance the LCG and return the next value
//  LCG: X_{n+1} = (a * X_n + c) mod 2^32
//        a = 0x41C64E6D,  c = 12345
//  Returns:  x0 = next 32-bit random value
//  Clobbers: x0-x3
// =====================================================================
rand_next:
    adrp    x1, seed32@PAGE
    add     x1, x1, seed32@PAGEOFF
    ldr     w0, [x1]

    movz    w2, #0x4E6D
    movk    w2, #0x41C6, lsl #16            // a = 0x41C64E6D
    mul     w0, w0, w2
    movz    w3, #0x3039                     // c = 12345
    add     w0, w0, w3

    str     w0, [x1]
    ret

// =====================================================================
//  rand_range — reduce a random value to [0, N)
//  Args:     x0 = random value, x1 = N (upper bound, exclusive)
//  Returns:  x0 = random % N
//  Clobbers: x0-x2
// =====================================================================
rand_range:
    udiv    x2, x0, x1                      // quotient
    msub    x0, x2, x1, x0                  // remainder
    ret

// =====================================================================
//  BSS — PRNG internal state
// =====================================================================
.section __DATA,__bss
.p2align 3

seed32:       .skip 4
timeval_buf:  .skip 16
