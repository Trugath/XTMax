bits 16
org 0x7c00

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00
    sti

    mov si, message

.print:
    lodsb
    test al, al
    jz .halt
    mov ah, 0x0e
    mov bh, 0x00
    mov bl, 0x07
    int 0x10
    jmp .print

.halt:
    hlt
    jmp .halt

message:
    db "XTMAX TEST BOOT", 0

times 510 - ($ - $$) db 0
dw 0xaa55
