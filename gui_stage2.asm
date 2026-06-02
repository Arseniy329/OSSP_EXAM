// gui_stage2.asm — Phase 2: App + Window + UI Elements
// macOS ARM64 (Apple Silicon) — Pure Assembly Cocoa Application
//
// Build:
//   as -o gui_stage2.o gui_stage2.asm
//   ld -o gui_stage2 gui_stage2.o -lSystem -framework Cocoa \
//      -syslibroot $(xcrun -sdk macosx --show-sdk-path) -arch arm64 -e _main
//
// Run:
//   ./gui_stage2

.section __TEXT,__text,regular,pure_instructions
.p2align 2
.globl _main

// =====================================================================
//  _main — Application entry point
//
//  Callee-saved register map:
//    x19 = NSApp             x20 = NSWindow
//    x21 = contentView       x22 = scratch (current widget)
//    x23 = lengthInput       x24 = modeInput
//    x25 = outputField       x26 = generateBtn
//    x27 = copyBtn           x28 = (unused, saved for alignment)
// =====================================================================
_main:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!
    stp     x23, x24, [sp, #-16]!
    stp     x25, x26, [sp, #-16]!
    stp     x27, x28, [sp, #-16]!

    // =================================================================
    //  PHASE 1 — NSApplication + NSWindow
    // =================================================================

    // ── [NSApplication sharedApplication] → x19 ──
    adrp    x0, cls_NSApplication@PAGE
    add     x0, x0, cls_NSApplication@PAGEOFF
    bl      _objc_getClass
    mov     x19, x0
    adrp    x0, sel_sharedApplication@PAGE
    add     x0, x0, sel_sharedApplication@PAGEOFF
    bl      _sel_registerName
    mov     x1, x0
    mov     x0, x19
    bl      _objc_msgSend
    mov     x19, x0                         // x19 = NSApp

    // ── [NSApp setActivationPolicy:Regular(0)] ──
    mov     x0, x19
    adrp    x1, sel_setActivationPolicy@PAGE
    add     x1, x1, sel_setActivationPolicy@PAGEOFF
    mov     x2, #0
    bl      send_msg1

    // ── [[NSWindow alloc] initWithContentRect:styleMask:backing:defer:] ──
    adrp    x0, cls_NSWindow@PAGE
    add     x0, x0, cls_NSWindow@PAGEOFF
    bl      _objc_getClass
    mov     x20, x0
    adrp    x0, sel_alloc@PAGE
    add     x0, x0, sel_alloc@PAGEOFF
    bl      _sel_registerName
    mov     x1, x0
    mov     x0, x20
    bl      _objc_msgSend
    mov     x20, x0                         // allocated window

    adrp    x0, sel_initWithContentRect@PAGE
    add     x0, x0, sel_initWithContentRect@PAGEOFF
    bl      _sel_registerName
    mov     x1, x0
    mov     x0, x20
    // CGRect(100, 100, 400, 300) — IEEE 754 doubles via x9 scratch
    movz    x9,  #0x4059, lsl #48           // 100.0
    fmov    d0, x9
    fmov    d1, x9
    movz    x9,  #0x4079, lsl #48           // 400.0
    fmov    d2, x9
    movz    x9,  #0x4072, lsl #48
    movk    x9,  #0xC000, lsl #32           // 300.0
    fmov    d3, x9
    mov     x2, #7                          // Titled|Closable|Miniaturizable
    mov     x3, #2                          // NSBackingStoreBuffered
    mov     x4, #0                          // defer = NO
    bl      _objc_msgSend
    mov     x20, x0                         // x20 = initialised NSWindow

    // ── [window setTitle:@"PassGen"] ──
    adrp    x0, str_title@PAGE
    add     x0, x0, str_title@PAGEOFF
    bl      make_nsstring
    mov     x2, x0
    mov     x0, x20
    adrp    x1, sel_setTitle@PAGE
    add     x1, x1, sel_setTitle@PAGEOFF
    bl      send_msg1

    // =================================================================
    //  PHASE 2 — UI Elements
    // =================================================================

    // ── [window contentView] → x21 ──
    mov     x0, x20
    adrp    x1, sel_contentView@PAGE
    add     x1, x1, sel_contentView@PAGEOFF
    bl      send_msg0
    mov     x21, x0                         // x21 = contentView

    // ─────────────────────────────────────────────────────────────────
    //  lengthLabel  — static label: "Length (1-64):"
    // ─────────────────────────────────────────────────────────────────
    adrp    x0, cls_NSTextField@PAGE
    add     x0, x0, cls_NSTextField@PAGEOFF
    adrp    x1, frame_lengthLabel@PAGE
    add     x1, x1, frame_lengthLabel@PAGEOFF
    bl      alloc_with_frame
    mov     x22, x0

    adrp    x0, str_lengthLbl@PAGE
    add     x0, x0, str_lengthLbl@PAGEOFF
    bl      make_nsstring
    mov     x2, x0
    mov     x0, x22
    adrp    x1, sel_setStringValue@PAGE
    add     x1, x1, sel_setStringValue@PAGEOFF
    bl      send_msg1

    mov     x0, x22
    bl      configure_as_label

    mov     x0, x21
    adrp    x1, sel_addSubview@PAGE
    add     x1, x1, sel_addSubview@PAGEOFF
    mov     x2, x22
    bl      send_msg1

    // ─────────────────────────────────────────────────────────────────
    //  lengthInput  — editable text field, default "12"
    // ─────────────────────────────────────────────────────────────────
    adrp    x0, cls_NSTextField@PAGE
    add     x0, x0, cls_NSTextField@PAGEOFF
    adrp    x1, frame_lengthInput@PAGE
    add     x1, x1, frame_lengthInput@PAGEOFF
    bl      alloc_with_frame
    mov     x22, x0
    mov     x23, x0                         // ★ save for Phase 3

    adrp    x0, str_default12@PAGE
    add     x0, x0, str_default12@PAGEOFF
    bl      make_nsstring
    mov     x2, x0
    mov     x0, x22
    adrp    x1, sel_setStringValue@PAGE
    add     x1, x1, sel_setStringValue@PAGEOFF
    bl      send_msg1

    mov     x0, x21
    adrp    x1, sel_addSubview@PAGE
    add     x1, x1, sel_addSubview@PAGEOFF
    mov     x2, x22
    bl      send_msg1

    // ─────────────────────────────────────────────────────────────────
    //  modeLabel  — static label: "Mode (1=Num, 2=AlphaNum):"
    // ─────────────────────────────────────────────────────────────────
    adrp    x0, cls_NSTextField@PAGE
    add     x0, x0, cls_NSTextField@PAGEOFF
    adrp    x1, frame_modeLabel@PAGE
    add     x1, x1, frame_modeLabel@PAGEOFF
    bl      alloc_with_frame
    mov     x22, x0

    adrp    x0, str_modeLbl@PAGE
    add     x0, x0, str_modeLbl@PAGEOFF
    bl      make_nsstring
    mov     x2, x0
    mov     x0, x22
    adrp    x1, sel_setStringValue@PAGE
    add     x1, x1, sel_setStringValue@PAGEOFF
    bl      send_msg1

    mov     x0, x22
    bl      configure_as_label

    mov     x0, x21
    adrp    x1, sel_addSubview@PAGE
    add     x1, x1, sel_addSubview@PAGEOFF
    mov     x2, x22
    bl      send_msg1

    // ─────────────────────────────────────────────────────────────────
    //  modeInput  — editable text field, default "2"
    // ─────────────────────────────────────────────────────────────────
    adrp    x0, cls_NSTextField@PAGE
    add     x0, x0, cls_NSTextField@PAGEOFF
    adrp    x1, frame_modeInput@PAGE
    add     x1, x1, frame_modeInput@PAGEOFF
    bl      alloc_with_frame
    mov     x22, x0
    mov     x24, x0                         // ★ save for Phase 3

    adrp    x0, str_default2@PAGE
    add     x0, x0, str_default2@PAGEOFF
    bl      make_nsstring
    mov     x2, x0
    mov     x0, x22
    adrp    x1, sel_setStringValue@PAGE
    add     x1, x1, sel_setStringValue@PAGEOFF
    bl      send_msg1

    mov     x0, x21
    adrp    x1, sel_addSubview@PAGE
    add     x1, x1, sel_addSubview@PAGEOFF
    mov     x2, x22
    bl      send_msg1

    // ─────────────────────────────────────────────────────────────────
    //  generateBtn  — "Generate" push button
    // ─────────────────────────────────────────────────────────────────
    adrp    x0, cls_NSButton@PAGE
    add     x0, x0, cls_NSButton@PAGEOFF
    adrp    x1, frame_generateBtn@PAGE
    add     x1, x1, frame_generateBtn@PAGEOFF
    bl      alloc_with_frame
    mov     x22, x0
    mov     x26, x0                         // ★ save for Phase 3

    adrp    x0, str_generate@PAGE
    add     x0, x0, str_generate@PAGEOFF
    bl      make_nsstring
    mov     x2, x0
    mov     x0, x22
    adrp    x1, sel_setTitle@PAGE
    add     x1, x1, sel_setTitle@PAGEOFF
    bl      send_msg1

    mov     x0, x22
    adrp    x1, sel_setBezelStyle@PAGE
    add     x1, x1, sel_setBezelStyle@PAGEOFF
    mov     x2, #1                          // NSBezelStyleRounded
    bl      send_msg1

    mov     x0, x21
    adrp    x1, sel_addSubview@PAGE
    add     x1, x1, sel_addSubview@PAGEOFF
    mov     x2, x22
    bl      send_msg1

    // ─────────────────────────────────────────────────────────────────
    //  outputField  — read-only, selectable, bezeled
    // ─────────────────────────────────────────────────────────────────
    adrp    x0, cls_NSTextField@PAGE
    add     x0, x0, cls_NSTextField@PAGEOFF
    adrp    x1, frame_outputField@PAGE
    add     x1, x1, frame_outputField@PAGEOFF
    bl      alloc_with_frame
    mov     x22, x0
    mov     x25, x0                         // ★ save for Phase 3

    // Clear the default text
    adrp    x0, str_empty@PAGE
    add     x0, x0, str_empty@PAGEOFF
    bl      make_nsstring
    mov     x2, x0
    mov     x0, x22
    adrp    x1, sel_setStringValue@PAGE
    add     x1, x1, sel_setStringValue@PAGEOFF
    bl      send_msg1

    // setEditable: NO
    mov     x0, x22
    adrp    x1, sel_setEditable@PAGE
    add     x1, x1, sel_setEditable@PAGEOFF
    mov     x2, #0
    bl      send_msg1

    // setSelectable: YES
    mov     x0, x22
    adrp    x1, sel_setSelectable@PAGE
    add     x1, x1, sel_setSelectable@PAGEOFF
    mov     x2, #1
    bl      send_msg1

    mov     x0, x21
    adrp    x1, sel_addSubview@PAGE
    add     x1, x1, sel_addSubview@PAGEOFF
    mov     x2, x22
    bl      send_msg1

    // ─────────────────────────────────────────────────────────────────
    //  copyBtn  — "Copy" push button
    // ─────────────────────────────────────────────────────────────────
    adrp    x0, cls_NSButton@PAGE
    add     x0, x0, cls_NSButton@PAGEOFF
    adrp    x1, frame_copyBtn@PAGE
    add     x1, x1, frame_copyBtn@PAGEOFF
    bl      alloc_with_frame
    mov     x22, x0
    mov     x27, x0                         // ★ save for Phase 3

    adrp    x0, str_copy@PAGE
    add     x0, x0, str_copy@PAGEOFF
    bl      make_nsstring
    mov     x2, x0
    mov     x0, x22
    adrp    x1, sel_setTitle@PAGE
    add     x1, x1, sel_setTitle@PAGEOFF
    bl      send_msg1

    mov     x0, x22
    adrp    x1, sel_setBezelStyle@PAGE
    add     x1, x1, sel_setBezelStyle@PAGEOFF
    mov     x2, #1                          // NSBezelStyleRounded
    bl      send_msg1

    mov     x0, x21
    adrp    x1, sel_addSubview@PAGE
    add     x1, x1, sel_addSubview@PAGEOFF
    mov     x2, x22
    bl      send_msg1

    // =================================================================
    //  Save widget references to globals (for Phase 3 action handlers)
    // =================================================================
    adrp    x9, g_nsapp@PAGE
    add     x9, x9, g_nsapp@PAGEOFF
    str     x19, [x9]

    adrp    x9, g_window@PAGE
    add     x9, x9, g_window@PAGEOFF
    str     x20, [x9]

    adrp    x9, g_lengthInput@PAGE
    add     x9, x9, g_lengthInput@PAGEOFF
    str     x23, [x9]

    adrp    x9, g_modeInput@PAGE
    add     x9, x9, g_modeInput@PAGEOFF
    str     x24, [x9]

    adrp    x9, g_outputField@PAGE
    add     x9, x9, g_outputField@PAGEOFF
    str     x25, [x9]

    adrp    x9, g_generateBtn@PAGE
    add     x9, x9, g_generateBtn@PAGEOFF
    str     x26, [x9]

    adrp    x9, g_copyBtn@PAGE
    add     x9, x9, g_copyBtn@PAGEOFF
    str     x27, [x9]

    // =================================================================
    //  SHOW AND RUN
    // =================================================================

    // [window center]
    mov     x0, x20
    adrp    x1, sel_center@PAGE
    add     x1, x1, sel_center@PAGEOFF
    bl      send_msg0

    // [window makeKeyAndOrderFront:nil]
    mov     x0, x20
    adrp    x1, sel_makeKeyAndOrderFront@PAGE
    add     x1, x1, sel_makeKeyAndOrderFront@PAGEOFF
    mov     x2, #0
    bl      send_msg1

    // [NSApp activateIgnoringOtherApps:YES]
    mov     x0, x19
    adrp    x1, sel_activate@PAGE
    add     x1, x1, sel_activate@PAGEOFF
    mov     x2, #1
    bl      send_msg1

    // [NSApp run] — enters event loop (does not return)
    mov     x0, x19
    adrp    x1, sel_run@PAGE
    add     x1, x1, sel_run@PAGEOFF
    bl      send_msg0

    // ── Epilogue (unreachable) ──
    ldp     x27, x28, [sp], #16
    ldp     x25, x26, [sp], #16
    ldp     x23, x24, [sp], #16
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    mov     x0, #0
    ret

// =====================================================================
//  HELPER SUBROUTINES
// =====================================================================

// ---------------------------------------------------------------------
//  make_nsstring — [NSString stringWithUTF8String:cstr]
//  Input:  x0 = C string pointer
//  Output: x0 = autoreleased NSString
// ---------------------------------------------------------------------
make_nsstring:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x20, x21, [sp, #-16]!

    mov     x20, x0                         // save C string
    adrp    x0, cls_NSString@PAGE
    add     x0, x0, cls_NSString@PAGEOFF
    bl      _objc_getClass
    mov     x21, x0                         // NSString class

    adrp    x0, sel_stringWithUTF8String@PAGE
    add     x0, x0, sel_stringWithUTF8String@PAGEOFF
    bl      _sel_registerName
    mov     x1, x0
    mov     x0, x21                         // class
    mov     x2, x20                         // C string
    bl      _objc_msgSend                   // → NSString

    ldp     x20, x21, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

// ---------------------------------------------------------------------
//  alloc_with_frame — [[class alloc] initWithFrame:rect]
//  Input:  x0 = class name C string
//          x1 = pointer to 4 doubles (x, y, w, h)
//  Output: x0 = initialised object
// ---------------------------------------------------------------------
alloc_with_frame:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x20, x21, [sp, #-16]!

    mov     x21, x1                         // save frame data ptr
    bl      _objc_getClass
    mov     x20, x0                         // class

    adrp    x0, sel_alloc@PAGE
    add     x0, x0, sel_alloc@PAGEOFF
    bl      _sel_registerName
    mov     x1, x0
    mov     x0, x20
    bl      _objc_msgSend
    mov     x20, x0                         // allocated object

    adrp    x0, sel_initWithFrame@PAGE
    add     x0, x0, sel_initWithFrame@PAGEOFF
    bl      _sel_registerName
    mov     x1, x0                          // @selector(initWithFrame:)
    mov     x0, x20                         // receiver
    ldp     d0, d1, [x21]                   // origin.x, origin.y
    ldp     d2, d3, [x21, #16]              // size.width, size.height
    bl      _objc_msgSend

    ldp     x20, x21, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

// ---------------------------------------------------------------------
//  send_msg0 — send ObjC message with 0 extra arguments
//  Input:  x0 = receiver, x1 = selector name (C string)
//  Output: x0 = result
// ---------------------------------------------------------------------
send_msg0:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x20, x21, [sp, #-16]!

    mov     x20, x0                         // save receiver
    mov     x0, x1                          // selector name
    bl      _sel_registerName
    mov     x1, x0                          // resolved SEL
    mov     x0, x20                         // receiver
    bl      _objc_msgSend

    ldp     x20, x21, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

// ---------------------------------------------------------------------
//  send_msg1 — send ObjC message with 1 extra argument
//  Input:  x0 = receiver, x1 = selector name (C string), x2 = arg
//  Output: x0 = result
// ---------------------------------------------------------------------
send_msg1:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x20, x21, [sp, #-16]!

    mov     x20, x0                         // save receiver
    mov     x21, x2                         // save argument
    mov     x0, x1                          // selector name
    bl      _sel_registerName
    mov     x1, x0                          // resolved SEL
    mov     x0, x20                         // receiver
    mov     x2, x21                         // argument
    bl      _objc_msgSend

    ldp     x20, x21, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

// ---------------------------------------------------------------------
//  configure_as_label — style NSTextField as a static label
//    setEditable:NO, setBezeled:NO, setDrawsBackground:NO
//  Input: x0 = NSTextField instance
// ---------------------------------------------------------------------
configure_as_label:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x20, x21, [sp, #-16]!

    mov     x20, x0                         // save widget

    mov     x0, x20
    adrp    x1, sel_setEditable@PAGE
    add     x1, x1, sel_setEditable@PAGEOFF
    mov     x2, #0
    bl      send_msg1

    mov     x0, x20
    adrp    x1, sel_setBezeled@PAGE
    add     x1, x1, sel_setBezeled@PAGEOFF
    mov     x2, #0
    bl      send_msg1

    mov     x0, x20
    adrp    x1, sel_setDrawsBackground@PAGE
    add     x1, x1, sel_setDrawsBackground@PAGEOFF
    mov     x2, #0
    bl      send_msg1

    ldp     x20, x21, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

// =====================================================================
//  DATA — Class names, selectors, UI strings, frame rectangles
// =====================================================================
.section __DATA,__data
.p2align 3

// ── Objective-C class names ──
cls_NSApplication:          .asciz "NSApplication"
cls_NSWindow:               .asciz "NSWindow"
cls_NSString:               .asciz "NSString"
cls_NSTextField:            .asciz "NSTextField"
cls_NSButton:               .asciz "NSButton"

// ── Selector names ──
sel_sharedApplication:      .asciz "sharedApplication"
sel_setActivationPolicy:    .asciz "setActivationPolicy:"
sel_alloc:                  .asciz "alloc"
sel_initWithContentRect:    .asciz "initWithContentRect:styleMask:backing:defer:"
sel_initWithFrame:          .asciz "initWithFrame:"
sel_stringWithUTF8String:   .asciz "stringWithUTF8String:"
sel_setTitle:               .asciz "setTitle:"
sel_setStringValue:         .asciz "setStringValue:"
sel_setEditable:            .asciz "setEditable:"
sel_setBezeled:             .asciz "setBezeled:"
sel_setDrawsBackground:     .asciz "setDrawsBackground:"
sel_setSelectable:          .asciz "setSelectable:"
sel_setBezelStyle:          .asciz "setBezelStyle:"
sel_contentView:            .asciz "contentView"
sel_addSubview:             .asciz "addSubview:"
sel_center:                 .asciz "center"
sel_makeKeyAndOrderFront:   .asciz "makeKeyAndOrderFront:"
sel_activate:               .asciz "activateIgnoringOtherApps:"
sel_run:                    .asciz "run"

// ── UI strings ──
str_title:                  .asciz "PassGen"
str_lengthLbl:              .asciz "Length (1-64):"
str_modeLbl:                .asciz "Mode (1=Num, 2=AlphaNum):"
str_default12:              .asciz "12"
str_default2:               .asciz "2"
str_generate:               .asciz "Generate"
str_copy:                   .asciz "Copy"
str_empty:                  .asciz ""

// ── CGRect frame data  (x, y, width, height — each a double) ──
//    Window content area is 400 × 300.  y = 0 is at the bottom.
//
//    y ≈ 250  ┌ Length label ──── Length input ──────────────┐
//    y ≈ 210  │ Mode label ────── Mode input ───────────────│
//    y ≈ 155  │ [ Generate ]            [ Copy ]            │
//    y ≈  40  │ ┌── output field (read-only, selectable) ──┐│
//    y ≈   0  └─┴──────────────────────────────────────────┴┘
//
.p2align 3
frame_lengthLabel:  .double 20.0, 250.0, 130.0, 20.0
frame_lengthInput:  .double 160.0, 248.0, 220.0, 24.0
frame_modeLabel:    .double 20.0, 210.0, 200.0, 20.0
frame_modeInput:    .double 230.0, 208.0, 150.0, 24.0
frame_generateBtn:  .double 20.0, 155.0, 175.0, 32.0
frame_copyBtn:      .double 205.0, 155.0, 175.0, 32.0
frame_outputField:  .double 20.0, 40.0, 360.0, 80.0

// =====================================================================
//  BSS — Global widget references (for Phase 3 action handlers)
// =====================================================================
.section __DATA,__bss
.p2align 3

g_nsapp:        .skip 8
g_window:       .skip 8
g_lengthInput:  .skip 8
g_modeInput:    .skip 8
g_outputField:  .skip 8
g_generateBtn:  .skip 8
g_copyBtn:      .skip 8
