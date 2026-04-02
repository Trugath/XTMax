bits 16
org 0x7c00

%define SRC_BUF 0x0600
%define DST_BUF 0x0800

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00
    sti
    cld

    mov ax, 0xa55a
    mov di, SRC_BUF
    mov cx, 256
    rep stosw

    mov ax, 0x0301
    xor bx, bx
    mov bx, SRC_BUF
    xor cx, cx
    mov cl, 2
    xor dx, dx
    mov dl, 0x80
    int 0x13
    jc write_fail

    xor ax, ax
    mov es, ax
    mov di, DST_BUF
    mov cx, 256
    rep stosw

    mov ax, 0x0201
    mov bx, DST_BUF
    xor cx, cx
    mov cl, 2
    xor dx, dx
    mov dl, 0x80
    int 0x13
    jc read_fail

    mov si, SRC_BUF
    mov di, DST_BUF
    mov cx, 256
    repe cmpsw
    jne mismatch

    mov si, ok_msg
    jmp print

write_fail:
    mov si, write_fail_msg
    jmp print

read_fail:
    mov si, read_fail_msg
    jmp print

mismatch:
    mov si, mismatch_msg

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
    db "XTMAX RW OK", 0
write_fail_msg:
    db "XTMAX RW WFAIL", 0
read_fail_msg:
    db "XTMAX RW RFAIL", 0
mismatch_msg:
    db "XTMAX RW MISMATCH", 0

times 510 - ($ - $$) db 0
dw 0xaa55
