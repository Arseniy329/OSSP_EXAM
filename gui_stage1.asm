// gui_stage1.asm — Phase 1: Basic Cocoa App Lifecycle & Window
// macOS ARM64 (Apple Silicon) — Pure Assembly Cocoa Application
//
// Build:
//   as -o gui_stage1.o gui_stage1.asm
//   ld -o gui_stage1 gui_stage1.o -lSystem -framework Cocoa \
//      -syslibroot $(xcrun -sdk macosx --show-sdk-path) -arch arm64 -e _main
//
// Run:
//   ./gui_stage1

.section __TEXT,__text,regular,pure_instructions
.p2align 2
.globl _main

// =====================================================================
//  _main — Application entry point
//
//  Callee-saved register allocation:
//    x19 = NSApp        (shared NSApplication instance)
//    x20 = NSWindow     (main window)
//    x21 = scratch      (reused for class refs / temporary objects)
//    x22 = (saved for frame alignment; unused)
// =====================================================================
_main:
    // ── Prologue: save non-volatile registers ──
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!

    // =================================================================
    //  1. [NSApplication sharedApplication]
    // =================================================================
    adrp    x0, cls_NSApplication@PAGE
    add     x0, x0, cls_NSApplication@PAGEOFF
    bl      _objc_getClass                  // → x0 = NSApplication class
    mov     x19, x0

    adrp    x0, sel_sharedApplication@PAGE
    add     x0, x0, sel_sharedApplication@PAGEOFF
    bl      _sel_registerName               // → x0 = @selector(sharedApplication)
    mov     x1, x0                          // x1 = selector
    mov     x0, x19                         // x0 = class (receiver)
    bl      _objc_msgSend
    mov     x19, x0                         // x19 = NSApp instance

    // =================================================================
    //  2. [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular]
    //     Regular (0) — shows in Dock, can own the menu bar.
    // =================================================================
    adrp    x0, sel_setActivationPolicy@PAGE
    add     x0, x0, sel_setActivationPolicy@PAGEOFF
    bl      _sel_registerName
    mov     x1, x0                          // selector
    mov     x0, x19                         // NSApp
    mov     x2, #0                          // NSApplicationActivationPolicyRegular
    bl      _objc_msgSend

    // =================================================================
    //  3. [[NSWindow alloc] init...]
    // =================================================================
    // ── 3a. [NSWindow alloc] ──
    adrp    x0, cls_NSWindow@PAGE
    add     x0, x0, cls_NSWindow@PAGEOFF
    bl      _objc_getClass
    mov     x20, x0                         // x20 = NSWindow class

    adrp    x0, sel_alloc@PAGE
    add     x0, x0, sel_alloc@PAGEOFF
    bl      _sel_registerName
    mov     x1, x0
    mov     x0, x20
    bl      _objc_msgSend
    mov     x20, x0                         // x20 = allocated (uninitialised) window

    // ── 3b. [window initWithContentRect:styleMask:backing:defer:] ──
    //
    //  ARM64 objc_msgSend register layout for this call:
    //    x0  = receiver   (allocated window)
    //    x1  = selector
    //  Floating-point file (CGRect — 4 × CGFloat = 4 × double):
    //    d0  = origin.x   (100.0)
    //    d1  = origin.y   (100.0)
    //    d2  = size.width  (400.0)
    //    d3  = size.height (300.0)
    //  Integer file (remaining arguments):
    //    x2  = styleMask   (NSUInteger)
    //    x3  = backing     (NSBackingStoreType)
    //    x4  = defer       (BOOL)
    //
    adrp    x0, sel_initWithContentRect@PAGE
    add     x0, x0, sel_initWithContentRect@PAGEOFF
    bl      _sel_registerName
    mov     x1, x0                          // x1 = selector
    mov     x0, x20                         // x0 = receiver

    // IEEE 754 double-precision constants, loaded via general-purpose
    // scratch register x9 then bit-copied into FP registers with FMOV.
    //
    //   100.0  = 0x4059_0000_0000_0000
    //   400.0  = 0x4079_0000_0000_0000
    //   300.0  = 0x4072_C000_0000_0000
    movz    x9,  #0x4059, lsl #48
    fmov    d0, x9                          // origin.x  = 100.0
    fmov    d1, x9                          // origin.y  = 100.0
    movz    x9,  #0x4079, lsl #48
    fmov    d2, x9                          // width     = 400.0
    movz    x9,  #0x4072, lsl #48
    movk    x9,  #0xC000, lsl #32
    fmov    d3, x9                          // height    = 300.0

    // Style mask: Titled (1) | Closable (2) | Miniaturizable (4) = 7
    mov     x2, #7
    mov     x3, #2                          // NSBackingStoreBuffered
    mov     x4, #0                          // defer = NO
    bl      _objc_msgSend
    mov     x20, x0                         // x20 = initialised NSWindow

    // =================================================================
    //  4. [window setTitle:@"PassGen"]
    //     Build an NSString from a C string, then set it as the title.
    // =================================================================
    adrp    x0, cls_NSString@PAGE
    add     x0, x0, cls_NSString@PAGEOFF
    bl      _objc_getClass
    mov     x21, x0                         // x21 = NSString class

    adrp    x0, sel_stringWithUTF8String@PAGE
    add     x0, x0, sel_stringWithUTF8String@PAGEOFF
    bl      _sel_registerName
    mov     x1, x0                          // selector
    mov     x0, x21                         // NSString class
    adrp    x2, str_title@PAGE
    add     x2, x2, str_title@PAGEOFF       // C string "PassGen"
    bl      _objc_msgSend
    mov     x21, x0                         // x21 = @"PassGen" NSString

    adrp    x0, sel_setTitle@PAGE
    add     x0, x0, sel_setTitle@PAGEOFF
    bl      _sel_registerName
    mov     x1, x0
    mov     x0, x20                         // window
    mov     x2, x21                         // title
    bl      _objc_msgSend

    // =================================================================
    //  5. [window center]
    // =================================================================
    adrp    x0, sel_center@PAGE
    add     x0, x0, sel_center@PAGEOFF
    bl      _sel_registerName
    mov     x1, x0
    mov     x0, x20
    bl      _objc_msgSend

    // =================================================================
    //  6. [window makeKeyAndOrderFront:nil]
    // =================================================================
    adrp    x0, sel_makeKeyAndOrderFront@PAGE
    add     x0, x0, sel_makeKeyAndOrderFront@PAGEOFF
    bl      _sel_registerName
    mov     x1, x0
    mov     x0, x20                         // window
    mov     x2, #0                          // sender = nil
    bl      _objc_msgSend

    // =================================================================
    //  7. [NSApp activateIgnoringOtherApps:YES]
    //     Ensures the window is brought to the foreground immediately.
    // =================================================================
    adrp    x0, sel_activate@PAGE
    add     x0, x0, sel_activate@PAGEOFF
    bl      _sel_registerName
    mov     x1, x0
    mov     x0, x19                         // NSApp
    mov     x2, #1                          // YES
    bl      _objc_msgSend

    // =================================================================
    //  8. [NSApp run]  — enters the Cocoa event loop (does not return)
    // =================================================================
    adrp    x0, sel_run@PAGE
    add     x0, x0, sel_run@PAGEOFF
    bl      _sel_registerName
    mov     x1, x0
    mov     x0, x19                         // NSApp
    bl      _objc_msgSend

    // ── Epilogue (unreachable — [NSApp run] never returns) ──
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    mov     x0, #0
    ret

// =====================================================================
//  DATA — C strings for ObjC class names, selectors, and UI text
// =====================================================================
.section __DATA,__data
.p2align 3

// ── Objective-C class names ──
cls_NSApplication:          .asciz "NSApplication"
cls_NSWindow:               .asciz "NSWindow"
cls_NSString:               .asciz "NSString"

// ── Selector names ──
sel_sharedApplication:      .asciz "sharedApplication"
sel_setActivationPolicy:    .asciz "setActivationPolicy:"
sel_alloc:                  .asciz "alloc"
sel_initWithContentRect:    .asciz "initWithContentRect:styleMask:backing:defer:"
sel_stringWithUTF8String:   .asciz "stringWithUTF8String:"
sel_setTitle:               .asciz "setTitle:"
sel_center:                 .asciz "center"
sel_makeKeyAndOrderFront:   .asciz "makeKeyAndOrderFront:"
sel_activate:               .asciz "activateIgnoringOtherApps:"
sel_run:                    .asciz "run"

// ── UI strings ──
str_title:                  .asciz "PassGen"
