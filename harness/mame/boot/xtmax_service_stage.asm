bits 16
cpu 8086
org 0

start:
    push cs
    pop ds

    mov ax, 0xb800
    mov es, ax
    mov di, 480
    mov si, message

.print:
    lodsb
    or al, al
    jz .done
    mov es:[di], al
    mov byte es:[di+1], 0x1f
    add di, 2
    jmp .print

.done:
    retf

message:
    db "XTMAX SERVICE TOOL", 0
