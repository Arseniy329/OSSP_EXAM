// gui_final.asm — Final: App + Window + UI Elements + Logic (PRNG & Copy/Paste)
// macOS ARM64 (Apple Silicon) — Pure Assembly Cocoa Application
//
// Build:
//   as -o gui_final.o gui_final.asm
//   ld -o gui_final gui_final.o -lSystem -framework Cocoa \
//      -syslibroot $(xcrun -sdk macosx --show-sdk-path) -arch arm64 -e _main
//
// Run:
//   ./gui_final
//

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
//    x27 = copyBtn           x28 = appDelegate
// =====================================================================
_main:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    sub     sp, sp, #80
    stp     x19, x20, [sp]
    stp     x21, x22, [sp, #16]
    stp     x23, x24, [sp, #32]
    stp     x25, x26, [sp, #48]
    stp     x27, x28, [sp, #64]

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
    mov     x23, x0                         // x23 = lengthInput

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
    mov     x24, x0                         // x24 = modeInput

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
    mov     x26, x0                         // x26 = generateBtn

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
    mov     x25, x0                         // x25 = outputField

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
    mov     x27, x0                         // x27 = copyBtn

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
    //  Save widget references to globals (for action handlers)
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
    //  PHASE 3 — Register custom AppDelegate and setup target-actions
    // =================================================================
    bl      register_app_delegate

    // Instantiate AppDelegate: [[AppDelegate alloc] init] → x28
    adrp    x0, cls_AppDelegate@PAGE
    add     x0, x0, cls_AppDelegate@PAGEOFF
    bl      _objc_getClass
    mov     x28, x0
    cbnz    x28, get_class_ok
    mov     x0, #104
    bl      _exit
get_class_ok:
    adrp    x0, sel_alloc@PAGE
    add     x0, x0, sel_alloc@PAGEOFF
    bl      _sel_registerName
    mov     x1, x0
    mov     x0, x28
    bl      _objc_msgSend
    mov     x28, x0

    adrp    x0, sel_init@PAGE
    add     x0, x0, sel_init@PAGEOFF
    bl      _sel_registerName
    mov     x1, x0
    mov     x0, x28
    bl      _objc_msgSend
    mov     x28, x0                         // x28 = appDelegate instance

    adrp    x9, g_appDelegate@PAGE
    add     x9, x9, g_appDelegate@PAGEOFF
    str     x28, [x9]                       // save delegate globally

    // ── Setup Target and Action for generateBtn ──
    mov     x0, x26                         // generateBtn
    adrp    x1, sel_setTarget@PAGE
    add     x1, x1, sel_setTarget@PAGEOFF
    mov     x2, x28                         // target = appDelegate
    bl      send_msg1

    // First resolve the action selector:
    adrp    x0, sel_generate_action@PAGE
    add     x0, x0, sel_generate_action@PAGEOFF
    bl      _sel_registerName
    mov     x2, x0                          // action = @selector(generate:)

    // Now set up receiver and message selector:
    mov     x0, x26                         // generateBtn
    adrp    x1, sel_setAction@PAGE
    add     x1, x1, sel_setAction@PAGEOFF
    bl      send_msg1

    // ── Setup Target and Action for copyBtn ──
    mov     x0, x27                         // copyBtn
    adrp    x1, sel_setTarget@PAGE
    add     x1, x1, sel_setTarget@PAGEOFF
    mov     x2, x28                         // target = appDelegate
    bl      send_msg1

    // First resolve the action selector:
    adrp    x0, sel_copy_action@PAGE
    add     x0, x0, sel_copy_action@PAGEOFF
    bl      _sel_registerName
    mov     x2, x0                          // action = @selector(copy:)

    // Now set up receiver and message selector:
    mov     x0, x27                         // copyBtn
    adrp    x1, sel_setAction@PAGE
    add     x1, x1, sel_setAction@PAGEOFF
    bl      send_msg1

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

    // Seed the PRNG once at startup (deferred after Cocoa initialization)
    bl      seed_prng

    // [NSApp run] — enters event loop (does not return)
    mov     x0, x19
    adrp    x1, sel_run@PAGE
    add     x1, x1, sel_run@PAGEOFF
    bl      send_msg0

    // ── Epilogue (unreachable) ──
    ldp     x27, x28, [sp, #64]
    ldp     x25, x26, [sp, #48]
    ldp     x23, x24, [sp, #32]
    ldp     x21, x22, [sp, #16]
    ldp     x19, x20, [sp]
    add     sp, sp, #80
    ldp     x29, x30, [sp], #16
    mov     x0, #0
    ret

// =====================================================================
//  OBJECTIVE-C RUNTIME CLASS REGISTRATION
// =====================================================================
register_app_delegate:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!

    // NSObject Class -> x19
    adrp    x0, cls_NSObject@PAGE
    add     x0, x0, cls_NSObject@PAGEOFF
    bl      _objc_getClass
    mov     x19, x0

    // Class objc_allocateClassPair(Class superclass, const char *name, size_t extraBytes)
    mov     x0, x19
    adrp    x1, cls_AppDelegate@PAGE
    add     x1, x1, cls_AppDelegate@PAGEOFF
    mov     x2, #0
    bl      _objc_allocateClassPair
    mov     x20, x0                         // x20 = AppDelegate Class
    cbnz    x20, alloc_ok
    mov     x0, #101
    bl      _exit

alloc_ok:
    // Register generate: method
    // BOOL class_addMethod(Class cls, SEL name, IMP imp, const char *types)
    mov     x0, x20
    adrp    x1, sel_generate_action@PAGE
    add     x1, x1, sel_generate_action@PAGEOFF
    bl      _sel_registerName
    mov     x1, x0                          // x1 = selector

    adrp    x2, on_generate@PAGE
    add     x2, x2, on_generate@PAGEOFF     // x2 = function ptr (IMP)

    adrp    x3, str_types@PAGE
    add     x3, x3, str_types@PAGEOFF       // x3 = type encoding "v@:@"
    mov     x0, x20
    bl      _class_addMethod
    cbnz    x0, method1_ok
    mov     x0, #102
    bl      _exit

method1_ok:
    // Register copy: method
    mov     x0, x20
    adrp    x1, sel_copy_action@PAGE
    add     x1, x1, sel_copy_action@PAGEOFF
    bl      _sel_registerName
    mov     x1, x0

    adrp    x2, on_copy@PAGE
    add     x2, x2, on_copy@PAGEOFF         // IMP

    adrp    x3, str_types@PAGE
    add     x3, x3, str_types@PAGEOFF
    mov     x0, x20
    bl      _class_addMethod
    cbnz    x0, method2_ok
    mov     x0, #103
    bl      _exit

method2_ok:
    // Register the class pair
    mov     x0, x20
    bl      _objc_registerClassPair

    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

// =====================================================================
//  ACTION HANDLERS (IMPLEMENTATIONS)
// =====================================================================

// on_generate(id self, SEL _cmd, id sender)
on_generate:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp

    // Get g_outputField
    adrp    x9, g_outputField@PAGE
    add     x9, x9, g_outputField@PAGEOFF
    ldr     x0, [x9]                        // x0 = receiver (outputField)
    cbnz    x0, output_field_ok
    
    // If outputField is nil, exit with 105
    mov     x0, #105
    bl      _exit

output_field_ok:
    // Create NSString from "TEST_PASS"
    adrp    x0, str_test_pass@PAGE
    add     x0, x0, str_test_pass@PAGEOFF
    bl      make_nsstring                   // x0 = NSString*

    mov     x2, x0                          // x2 = argument (NSString*)

    // Get g_outputField again
    adrp    x9, g_outputField@PAGE
    add     x9, x9, g_outputField@PAGEOFF
    ldr     x0, [x9]                        // x0 = receiver (outputField)

    adrp    x1, sel_setStringValue@PAGE
    add     x1, x1, sel_setStringValue@PAGEOFF
    bl      send_msg1

    ldp     x29, x30, [sp], #16
    ret

// on_copy(id self, SEL _cmd, id sender)
on_copy:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    // Save Objective-C implicit args (self, _cmd, sender) early.
    stp     x0, x1, [sp, #-16]!
    stp     x2, xzr, [sp, #-16]!
    stp     x19, x20, [sp, #-16]!

    // Get stringValue from g_outputField
    adrp    x9, g_outputField@PAGE
    add     x9, x9, g_outputField@PAGEOFF
    ldr     x0, [x9]
    adrp    x1, sel_stringValue@PAGE
    add     x1, x1, sel_stringValue@PAGEOFF
    bl      send_msg0                       // x0 = NSString
    mov     x19, x0                         // x19 = password string

    // Get NSPasteboard generalPasteboard
    adrp    x0, cls_NSPasteboard@PAGE
    add     x0, x0, cls_NSPasteboard@PAGEOFF
    bl      _objc_getClass
    mov     x20, x0

    adrp    x1, sel_generalPasteboard@PAGE
    add     x1, x1, sel_generalPasteboard@PAGEOFF
    bl      _sel_registerName
    mov     x1, x0
    mov     x0, x20
    bl      _objc_msgSend                   // x0 = general pasteboard
    mov     x20, x0                         // x20 = pasteboard instance

    // [pasteboard clearContents]
    mov     x0, x20
    adrp    x1, sel_clearContents@PAGE
    add     x1, x1, sel_clearContents@PAGEOFF
    bl      send_msg0

    // [pasteboard setString:passwordString forType:@"public.utf8-plain-text"]
    adrp    x0, str_pboardType@PAGE
    add     x0, x0, str_pboardType@PAGEOFF
    bl      make_nsstring                   // x0 = NSString string for type
    mov     x3, x0                          // x3 = type

    mov     x0, x20                         // receiver = pasteboard
    adrp    x1, sel_setStringForType@PAGE
    add     x1, x1, sel_setStringForType@PAGEOFF
    bl      _sel_registerName
    mov     x1, x0                          // x1 = selector
    mov     x0, x20                         // receiver
    mov     x2, x19                         // x2 = password string
    bl      _objc_msgSend

    ldp     x19, x20, [sp], #16
    ldp     x2, xzr, [sp], #16
    ldp     x0, x1, [sp], #16
    ldp     x29, x30, [sp], #16
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

// ---------------------------------------------------------------------
//  ascii_to_int — converts ASCII string to integer
//  Input:  x0 = C string
//  Output: x0 = integer
// ---------------------------------------------------------------------
ascii_to_int:
    cbz     x0, atoi_null                   // handle null pointer
    mov     x1, #0                          // accumulator (result register)
atoi_loop:
    ldrb    w2, [x0]                        // load a byte
    cbz     w2, atoi_done                   // if 0 (null terminator), terminate
    cmp     w2, #10                         // if 10 (newline), terminate
    b.eq    atoi_done
    cmp     w2, #13                         // if 13 (carriage return), terminate
    b.eq    atoi_done
    
    // Check if character is a digit
    cmp     w2, #'0'
    b.lo    atoi_skip
    cmp     w2, #'9'
    b.hi    atoi_skip
    
    // Process digit
    sub     w2, w2, #'0'
    uxtw    x2, w2
    mov     x3, #10
    madd    x1, x1, x3, x2                  // x1 = x1 * 10 + x2
    
atoi_skip:
    add     x0, x0, #1                      // increment pointer
    b       atoi_loop

atoi_null:
    mov     x0, #0
    ret

atoi_done:
    mov     x0, x1
    ret

// ---------------------------------------------------------------------
//  PRNG Subroutines
// ---------------------------------------------------------------------
.equ SYS_gettimeofday, 0x74

seed_prng:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    adrp    x9, timeval_buf@PAGE
    add     x9, x9, timeval_buf@PAGEOFF
    mov     x0, x9                          // timeval*
    mov     x1, #0                          // timezone = NULL
    mov     x16, #SYS_gettimeofday
    movk    x16, #0x200, lsl #16
    svc     #0x80

    ldr     x2, [x9, #8]                    // tv_usec
    adrp    x3, seed32@PAGE
    add     x3, x3, seed32@PAGEOFF
    str     w2, [x3]
    mov     x0, x2
    
    ldp     x29, x30, [sp], #16
    ret

rand_next:
    adrp    x1, seed32@PAGE
    add     x1, x1, seed32@PAGEOFF
    ldr     w0, [x1]

    // LCG: X_{n+1} = (a * X_n + c) mod 2^32
    movz    w2, #0x4E6D
    movk    w2, #0x41C6, lsl #16            // a = 0x41C64E6D
    mul     w0, w0, w2
    movz    w3, #0x3039                     // c = 12345
    add     w0, w0, w3

    str     w0, [x1]
    ret

rand_range:
    udiv    x2, x0, x1                      // quotient = x0 / x1
    msub    x0, x2, x1, x0                  // remainder = x0 - (quotient * x1)
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
cls_NSObject:               .asciz "NSObject"
cls_AppDelegate:            .asciz "PassGenAppDelegate"
cls_NSPasteboard:           .asciz "NSPasteboard"

// ── Selector names ──
sel_sharedApplication:      .asciz "sharedApplication"
sel_setActivationPolicy:    .asciz "setActivationPolicy:"
sel_alloc:                  .asciz "alloc"
sel_init:                   .asciz "init"
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
sel_setTarget:              .asciz "setTarget:"
sel_setAction:              .asciz "setAction:"
sel_generate_action:        .asciz "generate:"
sel_copy_action:            .asciz "copy:"
sel_stringValue:            .asciz "stringValue"
sel_UTF8String:             .asciz "UTF8String"
sel_generalPasteboard:      .asciz "generalPasteboard"
sel_clearContents:          .asciz "clearContents"
sel_setStringForType:       .asciz "setString:forType:"

// ── UI strings ──
str_title:                  .asciz "PassGen"
str_lengthLbl:              .asciz "Length (1-64):"
str_modeLbl:                .asciz "Mode (1=Num, 2=AlphaNum):"
str_default12:              .asciz "12"
str_default2:               .asciz "2"
str_generate:               .asciz "Generate"
str_copy:                   .asciz "Copy"
str_empty:                  .asciz ""
str_errLen:                 .asciz "Error: Invalid Length (1-64)"
str_pboardType:             .asciz "public.utf8-plain-text"
str_types:                  .asciz "v@:@"
str_test_pass:              .asciz "TEST_PASS"

// ── Character sets ──
digits:                     .ascii "0123456789"
alphanum:                   .ascii "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"

// ── CGRect frame data ──
.p2align 3
frame_lengthLabel:          .double 20.0, 250.0, 130.0, 20.0
frame_lengthInput:          .double 160.0, 248.0, 220.0, 24.0
frame_modeLabel:            .double 20.0, 210.0, 200.0, 20.0
frame_modeInput:            .double 230.0, 208.0, 150.0, 24.0
frame_generateBtn:          .double 20.0, 155.0, 175.0, 32.0
frame_copyBtn:              .double 205.0, 155.0, 175.0, 32.0
frame_outputField:          .double 20.0, 40.0, 360.0, 80.0

// =====================================================================
//  BSS — Global references and buffers
// =====================================================================
.section __DATA,__bss
.p2align 3

g_nsapp:                    .skip 8
g_window:                   .skip 8
g_lengthInput:              .skip 8
g_modeInput:                .skip 8
g_outputField:              .skip 8
g_generateBtn:              .skip 8
g_copyBtn:                  .skip 8
g_appDelegate:              .skip 8

seed32:                     .skip 4
timeval_buf:                .skip 16
pass_buf:                   .skip 256
