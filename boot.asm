%macro SEG_ASM 1 ; Type
    ; base = 0x0, limit = 0xfffff
    dw 0xffff ; lowest 16 bits of limit
    dw 0x0 ; lowest 16 bits of base
    db 0x0 ; bits 16-23 of base
    db 10010000b | (%1); first byte of flags. 
    ; bit 4: Descriptor type. 1 = code or data
    ; bits 5-6: privilege level: 0 for ring 0, the highest
    ; bits 7: segment present, 1 = yes

    db 11001111b ; 1111 = bits 16-19 of limit, rest are flags
    ; bit 4: "Available for use by system software". not sure
    ; bit 5: 64-bit code segment: I guess we set this if want to switch to long mode
    ; bit 6: Default operation size. 1 = 32-bit segment
    ; bit 7: granularity, 1 = multiplies limit by 4K = 0x1000, so segment spans 4 GB of memory
    db 0x0 ; bits 24-31 of base
%endmacro


; code segment is entry 1 in GDT, data segment is entry 2
%define SEG_KCODE 1  ; kernel Code
%define SEG_KDATA 2  ; kernel Data+Stack

use16

global start ; TODO: what does global do?

extern bootmain ; TODO: what does extern do? i believe bootmain is the function in the C code

start:
    cli ; disable interrupts

    ; zero out the segment registers
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax

    lgdt   [gdtdesc]

    ; switch to protected mode (see Intel system programming manual
    mov eax, cr0
    or al, 1
    mov cr0, eax

    jmp    (SEG_KCODE<<3):start32 
    ; segment descriptors are 8 bytes and the code entry is the second entry
    ; so that's why it's 8. this is also the only way to populate the CS register
    ; From xv6 notes: "Enabling protected mode does not immediately change how the processor translates logical to physical addresses; it is only when one loads a new value into a segment register that the processor reads the GDT and changes its internal segmentation settings. One cannot directly modify %cs, so instead the code executes an ljmp (far jump) instruction, which allows a code segment selector to be specified."

start32:
use32
    ; now we are in protected mode

    ; populate remaining segment registers with the data segment
    mov    eax, SEG_KDATA<<3
    mov    ds, eax
    mov    es, eax
    mov    ss, eax
    mov    fs, eax
    mov    gs, eax


    ; Something about clearing the screen
    mov edi, 0xb8000
    mov ecx, 80*25*2
    mov al, 0
    rep stosb


    ; TODO: figure out how the call works. how is the bootmain symbol visible to assembly?
    mov    esp, start
    call   bootmain


gdt:
    ; segment descriptors consist of 32-bit base, 20-bit limit, and some flags.

    ; null descriptor, required by CPU apparently?
    dq 0

    ; we set up 2 segment descriptors, one for code and one for data. 
    ; both have base=0x0, limit=0xfffff. they differ only in flags.

    ; code segment descriptor
    SEG_ASM 1010b ; (Table 3-1 in Intel manual). 1010 says code, execute/read

    ; data segment descriptor
    SEG_ASM 0010b ; (Table 3-1 in Intel manual). 0010 says data, read/write


; GDT descriptor. 6 bytes
gdtdesc:
    dw (gdtdesc - gdt - 1) ; GDT size
    dd gdt ; GDT address
