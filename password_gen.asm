.section __TEXT,__text,regular,pure_instructions
.p2align 2
.globl _start

// Darwin AArch64 syscall base numbers (0x2000000 class applied via movk).
.equ SYS_exit, 1
.equ SYS_read, 3
.equ SYS_write, 4
.equ SYS_gettimeofday, 0x74

// Buffer sizing constants.
.equ INPUT_BUF_SIZE, 64
.equ PASS_BUF_SIZE, 256
.equ MAX_PASS_LEN, 64

_start:
    // Prompt for password length.
    adrp x0, prompt_len@PAGE
    add x0, x0, prompt_len@PAGEOFF
    mov x1, #PROMPT_LEN_LEN
    bl print_string

    // Read length input.
    adrp x0, input_buf@PAGE
    add x0, x0, input_buf@PAGEOFF
    mov x1, #INPUT_BUF_SIZE
    bl read_string

    // Convert length string to integer.
    adrp x0, input_buf@PAGE
    add x0, x0, input_buf@PAGEOFF
    bl atoi
    cmp x0, #1
    b.lo invalid_length
    cmp x0, #MAX_PASS_LEN
    b.hi invalid_length
    adrp x1, length_val@PAGE
    add x1, x1, length_val@PAGEOFF
    str x0, [x1]

    // Prompt for character set mode.
    adrp x0, prompt_mode@PAGE
    add x0, x0, prompt_mode@PAGEOFF
    mov x1, #PROMPT_MODE_LEN
    bl print_string

    // Read mode input.
    adrp x0, mode_buf@PAGE
    add x0, x0, mode_buf@PAGEOFF
    mov x1, #INPUT_BUF_SIZE
    bl read_string

    // Convert mode string to integer.
    adrp x0, mode_buf@PAGE
    add x0, x0, mode_buf@PAGEOFF
    bl atoi
    cmp x0, #1
    b.eq mode_ok
    cmp x0, #2
    b.ne invalid_mode
mode_ok:
    adrp x1, mode_val@PAGE
    add x1, x1, mode_val@PAGEOFF
    str x0, [x1]

    // Seed PRNG from time.
    bl seed_prng

    // Load desired password length.
    adrp x2, length_val@PAGE
    add x2, x2, length_val@PAGEOFF
    ldr x19, [x2]               // loop counter
    mov x24, x19                // preserve original length

    // Select character set and max range based on mode.
    adrp x2, mode_val@PAGE
    add x2, x2, mode_val@PAGEOFF
    ldr x21, [x2]

    adrp x22, digits@PAGE
    add x22, x22, digits@PAGEOFF
    mov x23, #DIGITS_LEN
    cmp x21, #1
    b.eq charset_ready
    adrp x22, alphanum@PAGE
    add x22, x22, alphanum@PAGEOFF
    mov x23, #ALPHANUM_LEN
charset_ready:

    // Initialize password buffer pointer.
    adrp x25, pass_buf@PAGE
    add x25, x25, pass_buf@PAGEOFF
    mov x20, x25

gen_loop:
    cbz x19, gen_done
    bl rand_next
    mov x1, x23                 // max range
    bl rand_range
    ldrb w2, [x22, x0]
    strb w2, [x20], #1
    subs x19, x19, #1
    b.ne gen_loop

gen_done:
    // Append newline and print result.
    mov w2, #10
    strb w2, [x20]

    adrp x0, prompt_out@PAGE
    add x0, x0, prompt_out@PAGEOFF
    mov x1, #PROMPT_OUT_LEN
    bl print_string

    mov x0, x25
    add x1, x24, #1              // length + newline
    bl print_string
    b exit_now

invalid_length:
    adrp x0, err_len@PAGE
    add x0, x0, err_len@PAGEOFF
    mov x1, #ERR_LEN_LEN
    bl print_string
    b exit_now

invalid_mode:
    adrp x0, err_mode@PAGE
    add x0, x0, err_mode@PAGEOFF
    mov x1, #ERR_MODE_LEN
    bl print_string

exit_now:
    // Clean exit.
    mov x0, #0                   // exit status = 0
    mov x16, #SYS_exit           // syscall number (base)
    movk x16, #0x200, lsl #16   // apply 0x2000000 class
    svc #0x80                    // invoke kernel

// print_string
// Args: x0 = pointer, x1 = length
// Clobbers: x0-x2, x16
print_string:
    mov x2, x1                  // count
    mov x1, x0                  // buffer
    mov x0, #1                  // fd = stdout
    mov x16, #SYS_write
    movk x16, #0x200, lsl #16
    svc #0x80
    ret

// read_string
// Args: x0 = buffer, x1 = max length
// Returns: x0 = bytes read (excluding newline if present)
// Clobbers: x0-x4, x9-x10, x16
read_string:
    mov x9, x0                  // save buffer pointer
    mov x10, x1                 // save max length
    mov x2, x1                  // count
    mov x1, x0                  // buffer
    mov x0, #0                  // fd = stdin
    mov x16, #SYS_read
    movk x16, #0x200, lsl #16
    svc #0x80

    mov x3, x0                  // bytes read
    cbz x3, read_string_done
    mov x1, x9                  // restore buffer pointer
    mov x4, #0                  // index
read_string_scan:
    ldrb w2, [x1, x4]
    cmp w2, #10                 // '\n'
    b.ne read_string_next
    mov w2, #0
    strb w2, [x1, x4]
    mov x3, x4
    b read_string_done
read_string_next:
    add x4, x4, #1
    cmp x4, x3
    b.lo read_string_scan

    // If no newline, NUL-terminate when there is space.
    cmp x3, x10
    b.hs read_string_done
    mov w2, #0
    strb w2, [x1, x3]
read_string_done:
    mov x0, x3
    ret

// atoi
// Args: x0 = pointer to ASCII digits
// Returns: x0 = integer value
// Clobbers: x0-x3
atoi:
    mov x1, #0
atoi_loop:
    ldrb w2, [x0], #1
    cbz w2, atoi_done
    cmp w2, #10                 // '\n'
    b.eq atoi_done
    cmp w2, #'0'
    b.lo atoi_done
    cmp w2, #'9'
    b.hi atoi_done
    sub w2, w2, #'0'
    mov x3, #10
    mul x1, x1, x3
    add x1, x1, x2
    b atoi_loop
atoi_done:
    mov x0, x1
    ret

// seed_prng
// Args: none
// Returns: x0 = new seed value
// Clobbers: x0-x3, x9, x16
seed_prng:
    adrp x9, timeval_buf@PAGE
    add x9, x9, timeval_buf@PAGEOFF
    mov x0, x9                  // timeval*
    mov x1, #0                  // timezone = NULL
    mov x16, #SYS_gettimeofday
    movk x16, #0x200, lsl #16
    svc #0x80

    ldr x2, [x9, #8]            // tv_usec
    adrp x3, seed32@PAGE
    add x3, x3, seed32@PAGEOFF
    str w2, [x3]
    mov x0, x2
    ret

// rand_next
// Args: none
// Returns: x0 = next random value
// Clobbers: x0-x3
rand_next:
    adrp x1, seed32@PAGE
    add x1, x1, seed32@PAGEOFF
    ldr w0, [x1]

    // LCG: X_{n+1} = (a * X_n + c) mod 2^32
    movz w2, #0x4E6D
    movk w2, #0x41C6, lsl #16   // a = 0x41C64E6D
    mul w0, w0, w2
    movz w3, #0x3039            // c = 12345
    add w0, w0, w3

    str w0, [x1]
    ret

// rand_range
// Args: x0 = random value, x1 = max N
// Returns: x0 = random % N
// Clobbers: x0-x2
rand_range:
    udiv x2, x0, x1             // quotient = x0 / x1
    msub x0, x2, x1, x0         // remainder = x0 - (quotient * x1)
    ret

.section __DATA,__data
.p2align 3

// Character sets.
digits:     .ascii "0123456789"
digits_end:
lowercase:  .ascii "abcdefghijklmnopqrstuvwxyz"
uppercase:  .ascii "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
alphanum:   .ascii "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
alphanum_end:

// UI prompt strings (NUL-terminated).
prompt_len:  .asciz "Enter length: "
prompt_len_end:
prompt_mode: .asciz "Select mode (1-Digits, 2-AlphaNum): "
prompt_mode_end:
prompt_out:  .asciz "Your password: "
prompt_out_end:
err_len:     .asciz "Error: Length must be between 1 and 64.\n"
err_len_end:
err_mode:    .asciz "Error: Mode must be 1 or 2.\n"
err_mode_end:

.equ PROMPT_LEN_LEN,  prompt_len_end - prompt_len - 1
.equ PROMPT_MODE_LEN, prompt_mode_end - prompt_mode - 1
.equ PROMPT_OUT_LEN,  prompt_out_end - prompt_out - 1
.equ ERR_LEN_LEN,     err_len_end - err_len - 1
.equ ERR_MODE_LEN,    err_mode_end - err_mode - 1
.equ DIGITS_LEN,      digits_end - digits
.equ ALPHANUM_LEN,    alphanum_end - alphanum

.section __DATA,__bss
.p2align 3

// Uninitialized buffers and state.
input_buf: .skip INPUT_BUF_SIZE
mode_buf:  .skip INPUT_BUF_SIZE
pass_buf:  .skip PASS_BUF_SIZE
seed32:    .skip 4
length_val: .skip 8
mode_val:   .skip 8
timeval_buf: .skip 16