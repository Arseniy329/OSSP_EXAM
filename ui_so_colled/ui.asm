// ui.asm — I/O, TUI formatting, strings, and buffers
// macOS ARM64 (Apple Silicon)
//
// Layout: data → length equates → code
// The data section is placed first so that label-difference .equ constants
// are resolved before the text section references them.

// ── Syscall base numbers (0x2000000 class applied via movk) ──
.equ SYS_write, 4
.equ SYS_read,  3

// ── Buffer sizing constants ──
.equ INPUT_BUF_SIZE, 64
.equ PASS_BUF_SIZE,  256

// ── Exported symbols ──
.globl draw_banner
.globl print_prompt_len
.globl print_prompt_mode
.globl print_prompt_out
.globl print_err_len
.globl print_err_mode
.globl print_color_reset
.globl print_string
.globl read_string
.globl ascii_to_int

.globl input_buf
.globl mode_buf
.globl pass_buf
.globl digits
.globl alphanum

// =====================================================================
//  DATA — strings with embedded ANSI escape sequences
// =====================================================================
.section __DATA,__data
.p2align 3

// ── Banner: clear screen + bold-cyan bordered title ──
banner_str:
    .byte   0x1b                            // ESC
    .ascii  "[2J"                           // clear entire screen
    .byte   0x1b
    .ascii  "[H"                            // cursor to home (1,1)
    .byte   0x1b
    .ascii  "[1;36m"                        // bold cyan
    .ascii  "\n"
    .ascii  "  +==========================================+\n"
    .ascii  "  |                                          |\n"
    .ascii  "  |          PASSWORD GENERATOR v1.0         |\n"
    .ascii  "  |            macOS ARM64 Edition           |\n"
    .ascii  "  |                                          |\n"
    .ascii  "  +==========================================+\n"
    .byte   0x1b
    .ascii  "[0m"                           // reset
    .ascii  "\n"
banner_str_end:

// ── Length prompt (bold yellow) ──
prompt_len_str:
    .byte   0x1b
    .ascii  "[1;33m"
    .ascii  "  Enter password length (1-64): "
    .byte   0x1b
    .ascii  "[0m"
prompt_len_str_end:

// ── Mode prompt (bold yellow) ──
prompt_mode_str:
    .byte   0x1b
    .ascii  "[1;33m"
    .ascii  "  Select mode [1] Digits [2] AlphaNum: "
    .byte   0x1b
    .ascii  "[0m"
prompt_mode_str_end:

// ── Output prefix (bold green — no reset; password text follows) ──
prompt_out_str:
    .byte   0x1b
    .ascii  "[1;32m"
    .ascii  "\n  >> Your password: "
prompt_out_str_end:

// ── Color reset + newline (printed after the password) ──
color_reset_str:
    .byte   0x1b
    .ascii  "[0m"
    .ascii  "\n\n"
color_reset_str_end:

// ── Length error (bold red) ──
err_len_str:
    .ascii  "\n"
    .byte   0x1b
    .ascii  "[1;31m"
    .ascii  "  [!] Error: Length must be between 1 and 64.\n"
    .byte   0x1b
    .ascii  "[0m"
    .ascii  "\n"
err_len_str_end:

// ── Mode error (bold red) ──
err_mode_str:
    .ascii  "\n"
    .byte   0x1b
    .ascii  "[1;31m"
    .ascii  "  [!] Error: Mode must be 1 or 2.\n"
    .byte   0x1b
    .ascii  "[0m"
    .ascii  "\n"
err_mode_str_end:

// ── Character sets ──
digits:     .ascii  "0123456789"
digits_end:
alphanum:   .ascii  "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
alphanum_end:

// ── Pre-computed string lengths (same-section label arithmetic) ──
.equ BANNER_LEN,       banner_str_end      - banner_str
.equ PROMPT_LEN_LEN,   prompt_len_str_end  - prompt_len_str
.equ PROMPT_MODE_LEN,  prompt_mode_str_end - prompt_mode_str
.equ PROMPT_OUT_LEN,   prompt_out_str_end  - prompt_out_str
.equ COLOR_RESET_LEN,  color_reset_str_end - color_reset_str
.equ ERR_LEN_LEN,      err_len_str_end     - err_len_str
.equ ERR_MODE_LEN,     err_mode_str_end    - err_mode_str

// =====================================================================
//  BSS — uninitialised buffers
// =====================================================================
.section __DATA,__bss
.p2align 3

input_buf:  .skip   INPUT_BUF_SIZE
mode_buf:   .skip   INPUT_BUF_SIZE
pass_buf:   .skip   PASS_BUF_SIZE

// =====================================================================
//  TEXT — subroutines
// =====================================================================
.section __TEXT,__text,regular,pure_instructions
.p2align 2

// =====================================================================
//  draw_banner — clears screen and prints the colored title banner
//  Clobbers: x0-x2, x16
// =====================================================================
draw_banner:
    adrp    x0, banner_str@PAGE
    add     x0, x0, banner_str@PAGEOFF
    mov     x1, #BANNER_LEN
    b       print_string                    // tail-call

// =====================================================================
//  print_prompt_len — prints the yellow "enter length" prompt
// =====================================================================
print_prompt_len:
    adrp    x0, prompt_len_str@PAGE
    add     x0, x0, prompt_len_str@PAGEOFF
    mov     x1, #PROMPT_LEN_LEN
    b       print_string

// =====================================================================
//  print_prompt_mode — prints the yellow "select mode" prompt
// =====================================================================
print_prompt_mode:
    adrp    x0, prompt_mode_str@PAGE
    add     x0, x0, prompt_mode_str@PAGEOFF
    mov     x1, #PROMPT_MODE_LEN
    b       print_string

// =====================================================================
//  print_prompt_out — prints the green password output prefix
// =====================================================================
print_prompt_out:
    adrp    x0, prompt_out_str@PAGE
    add     x0, x0, prompt_out_str@PAGEOFF
    mov     x1, #PROMPT_OUT_LEN
    b       print_string

// =====================================================================
//  print_err_len — prints the red length-error message
// =====================================================================
print_err_len:
    adrp    x0, err_len_str@PAGE
    add     x0, x0, err_len_str@PAGEOFF
    mov     x1, #ERR_LEN_LEN
    b       print_string

// =====================================================================
//  print_err_mode — prints the red mode-error message
// =====================================================================
print_err_mode:
    adrp    x0, err_mode_str@PAGE
    add     x0, x0, err_mode_str@PAGEOFF
    mov     x1, #ERR_MODE_LEN
    b       print_string

// =====================================================================
//  print_color_reset — prints ANSI reset sequence + newline
// =====================================================================
print_color_reset:
    adrp    x0, color_reset_str@PAGE
    add     x0, x0, color_reset_str@PAGEOFF
    mov     x1, #COLOR_RESET_LEN
    b       print_string

// =====================================================================
//  print_string — write a string to stdout
//  Args:     x0 = pointer to string, x1 = byte count
//  Clobbers: x0-x2, x16
// =====================================================================
print_string:
    mov     x2, x1                          // count
    mov     x1, x0                          // buffer
    mov     x0, #1                          // fd = stdout
    mov     x16, #SYS_write
    movk    x16, #0x200, lsl #16            // 0x2000000 class
    svc     #0x80
    ret

// =====================================================================
//  read_string — read from stdin, strip trailing newline
//  Args:     x0 = buffer pointer, x1 = max byte count
//  Returns:  x0 = bytes read (excluding newline)
//  Clobbers: x0-x4, x9-x10, x16
// =====================================================================
read_string:
    mov     x9, x0                          // save buffer ptr
    mov     x10, x1                         // save max length
    mov     x2, x1                          // count
    mov     x1, x0                          // buffer
    mov     x0, #0                          // fd = stdin
    mov     x16, #SYS_read
    movk    x16, #0x200, lsl #16
    svc     #0x80

    mov     x3, x0                          // bytes read
    cbz     x3, rs_done
    mov     x1, x9                          // restore buffer ptr
    mov     x4, #0                          // scan index
rs_scan:
    ldrb    w2, [x1, x4]
    cmp     w2, #10                         // '\n'
    b.ne    rs_next
    mov     w2, #0
    strb    w2, [x1, x4]                    // replace newline with NUL
    mov     x3, x4
    b       rs_done
rs_next:
    add     x4, x4, #1
    cmp     x4, x3
    b.lo    rs_scan

    // No newline found — NUL-terminate if space permits.
    cmp     x3, x10
    b.hs    rs_done
    mov     w2, #0
    strb    w2, [x1, x3]
rs_done:
    mov     x0, x3
    ret

// =====================================================================
//  ascii_to_int — convert a decimal ASCII string to an integer
//  Args:     x0 = pointer to NUL/newline-terminated digit string
//  Returns:  x0 = unsigned integer value
//  Clobbers: x0-x3
// =====================================================================
ascii_to_int:
    mov     x1, #0                          // accumulator
a2i_loop:
    ldrb    w2, [x0], #1
    cbz     w2, a2i_done
    cmp     w2, #10                         // '\n'
    b.eq    a2i_done
    cmp     w2, #'0'
    b.lo    a2i_done
    cmp     w2, #'9'
    b.hi    a2i_done
    sub     w2, w2, #'0'
    mov     x3, #10
    mul     x1, x1, x3
    add     x1, x1, x2
    b       a2i_loop
a2i_done:
    mov     x0, x1
    ret
