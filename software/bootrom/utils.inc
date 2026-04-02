;
; Display a string.
; in:  AX = string pointer
; out: AX = <TRASH>
;
print_string:
    push ds
    push si
    mov si, ax
    mov ax, cs
    mov ds, ax
    cld
.loop:
    lodsb
    or al, al
    jz .done
    call print_char
    jmp .loop
.done:
    pop si
    pop ds
    ret

;
; Display a 16-bit value in hex.
; in:  AX = value
; out: AX = <TRASH>
;
%if %isdef(AS_COM_PROGRAM) || %isdef(DEBUG) || %isdef(DEBUG_IO) || %isdef(EXTRA_DEBUG)
print_hex:
    push ds
    push cx
    push dx
    push si
    mov dx, ax
    mov ax, cs
    mov ds, ax
.nibble1:
    mov si, dx
    mov cl, 12
    shr si, cl
    and si, 0xf
    mov al, [hex_map+si]
    call print_char
.nibble2:
    mov si, dx
    mov cl, 8
    shr si, cl
    and si, 0xf
    mov al, [hex_map+si]
    call print_char
.nibble3:
    mov si, dx
    mov cl, 4
    shr si, cl
    and si, 0xf
    mov al, [hex_map+si]
    call print_char
.nibble4:
    mov si, dx
    and si, 0xf
    mov al, [hex_map+si]
    call print_char
    pop si
    pop dx
    pop cx
    pop ds
    ret
%endif

;
; Display a single character on the active text page.
; This avoids BIOS INT 10h teletype calls, which can blank some CGA-era systems.
; in:  AL = character
; out: AX = <TRASH>
;
print_char:
    push ds
    push es
    push bx
    push cx
    push dx
    push di
    mov bx, 0x40
    mov ds, bx
    mov bl, [0x49]          ; current video mode
    cmp bl, 7               ; monochrome text
    je .text_mode
    cmp bl, 4               ; CGA text modes 0-3
    jb .text_mode
    jmp .done
.text_mode:
    mov bl, [0x62]          ; active page
    xor bh, bh
    shl bx, 1
    mov dx, [bx+0x50]       ; page cursor: DH=row, DL=column
    cmp al, 0x0d
    je .carriage_return
    cmp al, 0x0a
    je .line_feed
    push ax
    xor di, di
    xor ax, ax
    mov al, dh
    mov bl, [0x4a]          ; columns
    mul bl                  ; row * columns
    mov di, ax
    xor ax, ax
    mov al, dl
    add di, ax
    shl di, 1               ; character cell is 2 bytes
    mov cx, [0x4e]          ; active page offset in regen buffer
    add di, cx
    mov ax, 0xb800
    cmp byte [0x49], 7
    jne .segment_ready
    mov ax, 0xb000
.segment_ready:
    mov es, ax
    pop ax
    mov es:[di], al
    mov byte es:[di+1], 0x07
    inc dl
    mov bl, [0x4a]
    cmp dl, bl
    jb .store_cursor
    xor dl, dl
    inc dh
    jmp .clamp_row
.carriage_return:
    xor dl, dl
    jmp .store_cursor
.line_feed:
    inc dh
.clamp_row:
    cmp dh, 25
    jb .store_cursor
    mov dh, 24
    xor dl, dl
.store_cursor:
    mov bl, [0x62]          ; active page
    xor bh, bh
    shl bx, 1
    mov [bx+0x50], dx       ; update BIOS cursor position for active page
.done:
    pop di
    pop dx
    pop cx
    pop bx
    pop es
    pop ds
    ret

%if %isdef(AS_COM_PROGRAM) || %isdef(DEBUG) || %isdef(DEBUG_IO) || %isdef(EXTRA_DEBUG)
hex_map db '0123456789ABCDEF'
%endif

%if %isdef(EXTRA_DEBUG) || %isdef(AS_COM_PROGRAM)
dump_regs:
    push ax
    mov ax, registers_msg
    call print_string
    pop ax
    push ax
    call print_hex
    mov ax, space
    call print_string
    mov ax, bx
    call print_hex
    mov ax, space
    call print_string
    mov ax, cx
    call print_hex
    mov ax, space
    call print_string
    mov ax, dx
    call print_hex
    mov ax, space
    call print_string
    mov ax, ds
    call print_hex
    mov ax, space
    call print_string
    mov ax, si
    call print_hex
    mov ax, space
    call print_string
    mov ax, es
    call print_hex
    mov ax, space
    call print_string
    mov ax, di
    call print_hex
    mov ax, space
    call print_string
    mov ax, bp
    call print_hex
    mov ax, space
    call print_string
    pushf
    pop ax
    call print_hex
    mov ax, space
    call print_string
    mov ax, newline
    call print_string
    pop ax
    ret

registers_msg   db ' AX   BX   CX   DX   DS   SI   ES   DI   BP  FLAGS', 0xD, 0xA, 0
%endif

colon           db ':', 0
space           db ' ', 0
newline         db 0xD, 0xA, 0
