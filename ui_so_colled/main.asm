// main.asm — Entry point and application logic for the password generator
// macOS ARM64 (Apple Silicon)

.section __TEXT,__text,regular,pure_instructions
.p2align 2
.globl _start

// ── Syscall base number (0x2000000 class applied via movk) ──
.equ SYS_exit, 1

// ── Application constants ──
.equ INPUT_BUF_SIZE, 64
.equ MAX_PASS_LEN,   64
.equ DIGITS_LEN,     10
.equ ALPHANUM_LEN,   62

// =====================================================================
//  _start — program entry
//
//  Register allocation across the generation loop:
//    x19 = remaining characters to generate (count-down)
//    x20 = current write pointer into pass_buf
//    x21 = selected mode (1 or 2)
//    x22 = base pointer of the chosen character set
//    x23 = length of the chosen character set
//    x24 = original requested password length
//    x25 = base pointer of pass_buf (constant)
// =====================================================================
_start:
    // ── 1. Draw the TUI banner ──
    bl      draw_banner

    // ── 2. Prompt for password length ──
    bl      print_prompt_len

    adrp    x0, input_buf@PAGE
    add     x0, x0, input_buf@PAGEOFF
    mov     x1, #INPUT_BUF_SIZE
    bl      read_string

    adrp    x0, input_buf@PAGE
    add     x0, x0, input_buf@PAGEOFF
    bl      ascii_to_int

    cmp     x0, #1
    b.lo    invalid_length
    cmp     x0, #MAX_PASS_LEN
    b.hi    invalid_length
    mov     x19, x0                         // save length as loop counter
    mov     x24, x0                         // preserve original length

    // ── 3. Prompt for character-set mode ──
    bl      print_prompt_mode

    adrp    x0, mode_buf@PAGE
    add     x0, x0, mode_buf@PAGEOFF
    mov     x1, #INPUT_BUF_SIZE
    bl      read_string

    adrp    x0, mode_buf@PAGE
    add     x0, x0, mode_buf@PAGEOFF
    bl      ascii_to_int

    cmp     x0, #1
    b.eq    mode_ok
    cmp     x0, #2
    b.ne    invalid_mode
mode_ok:
    mov     x21, x0                         // save mode

    // ── 4. Seed the PRNG ──
    bl      seed_prng

    // ── 5. Select character set based on mode ──
    adrp    x22, digits@PAGE
    add     x22, x22, digits@PAGEOFF
    mov     x23, #DIGITS_LEN
    cmp     x21, #1
    b.eq    charset_ready
    adrp    x22, alphanum@PAGE
    add     x22, x22, alphanum@PAGEOFF
    mov     x23, #ALPHANUM_LEN
charset_ready:

    // ── 6. Initialise password buffer pointer ──
    adrp    x25, pass_buf@PAGE
    add     x25, x25, pass_buf@PAGEOFF
    mov     x20, x25

    // ── 7. Generate password characters ──
gen_loop:
    cbz     x19, gen_done
    bl      rand_next
    mov     x1, x23                         // charset length
    bl      rand_range
    ldrb    w2, [x22, x0]                   // pick character
    strb    w2, [x20], #1                   // store & advance
    subs    x19, x19, #1
    b.ne    gen_loop

gen_done:
    // ── 8. Print the result ──
    bl      print_prompt_out                // green prefix

    mov     x0, x25                         // pass_buf base
    mov     x1, x24                         // password length
    bl      print_string

    bl      print_color_reset               // reset colour + newline
    b       exit_now

    // ── Error handlers ──
invalid_length:
    bl      print_err_len
    b       exit_now

invalid_mode:
    bl      print_err_mode

    // ── Clean exit ──
exit_now:
    mov     x0, #0                          // exit status = 0
    mov     x16, #SYS_exit
    movk    x16, #0x200, lsl #16            // 0x2000000 class
    svc     #0x80
