bits 16
org 0x7c00

%define MMAN_BASE 0x260

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00
    sti

    mov dx, MMAN_BASE + 0
    mov al, 0x10
    out dx, al
    mov dx, MMAN_BASE + 1
    xor al, al
    out dx, al

    mov dx, MMAN_BASE + 2
    mov al, 0x20
    out dx, al
    mov dx, MMAN_BASE + 3
    xor al, al
    out dx, al

    mov dx, MMAN_BASE + 10
    xor al, al
    out dx, al
    mov dx, MMAN_BASE + 11
    mov al, 0xE0
    out dx, al
    mov dx, MMAN_BASE + 12
    mov al, 0x04
    out dx, al

    mov ax, 0xE000
    mov es, ax
    mov byte [es:0], 0x11

    mov ax, 0xE400
    mov es, ax
    mov byte [es:0], 0x22

    mov dx, MMAN_BASE + 0
    mov al, 0x20
    out dx, al
    mov dx, MMAN_BASE + 1
    xor al, al
    out dx, al

    mov ax, 0xE000
    mov es, ax
    cmp byte [es:0], 0x22
    jne fail

    mov dx, MMAN_BASE + 2
    mov al, 0x10
    out dx, al
    mov dx, MMAN_BASE + 3
    xor al, al
    out dx, al

    mov ax, 0xE400
    mov es, ax
    cmp byte [es:0], 0x11
    jne fail

    mov si, ok_msg
    jmp print

fail:
    mov si, fail_msg

print:
    lodsb
    test al, al
    jz halt
    mov ah, 0x0e
    mov bh, 0x00
    mov bl, 0x07
    int 0x10
    jmp print

halt:
    hlt
    jmp halt

ok_msg:
    db "XTMAX EMS OK", 0
fail_msg:
    db "XTMAX EMS FAIL", 0

times 510 - ($ - $$) db 0
dw 0xaa55
