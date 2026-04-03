; MROMD.COM — stream a linear memory range to XTMax ROM-dump ports (0x298–0x29A).
;
; Build: nasm -f bin -o MROMD.COM mameromd.asm
;
; Usage (DOS, from PSP command tail at 81h):
;   MROMD F000 0000 8000
;   MROMD C000 0000 2000
;
; All three fields are hex (segment, offset, byte length). Spaces separate fields.
; Requires XTMax firmware with dump FIFO at 0x298 and USB serial connected (DTR high).

        cpu 8086
        org 0x100

start:
        mov     si, 0x81
        call    skip_ws
        call    parse_hex16
        jc      exit_bad
        mov     es, ax                ; source segment

        call    skip_ws
        call    parse_hex16
        jc      exit_bad
        mov     bx, ax                ; offset in segment

        call    skip_ws
        call    parse_hex16
        jc      exit_bad
        mov     cx, ax                ; length in bytes
        or      cx, cx
        jz      exit_bad

        push    es
        pop     ds
        mov     si, bx

        mov     dx, 0x298             ; data OUT (must stay in DX for OUT)

.loop:
        push    cx
.wait_space:
        push    dx
        mov     dx, 0x299
        in      al, dx
        pop     dx
        cmp     al, 16
        jb      .wait_space
        lodsb
        out     dx, al
        pop     cx
        loop    .loop

        mov     dx, 0x29A
        xor     al, al
        out     dx, al

        mov     ax, 0x4C00
        int     0x21

exit_bad:
        mov     ax, 0x4C01
        int     0x21

; Skip spaces, tabs, CR at [ds:SI]; leave SI on first non-ws or terminator.
skip_ws:
        lodsb
        cmp     al, 13
        je      .end
        cmp     al, ' '
        je      skip_ws
        cmp     al, 9
        je      skip_ws
.end:
        dec     si
        ret

; Parse hex at [ds:SI] into AX; SI stops on first non-hex. CF on no digit consumed.
parse_hex16:
        push    bx
        push    cx
        xor     bx, bx
        xor     cx, cx                ; digit count
.more:
        lodsb
        cmp     al, 13
        je      .term
        cmp     al, ' '
        je      .term
        cmp     al, 0
        je      .term

        call    hex_digit
        jc      .bad_char
        add     bx, bx
        add     bx, bx
        add     bx, bx
        add     bx, bx
        or      bl, al
        inc     cx
        cmp     cx, 4
        ja      .overflow
        jmp     .more
.term:
        dec     si
        or      cx, cx
        jz      .fail
        mov     ax, bx
        clc
        pop     cx
        pop     bx
        ret
.bad_char:
        dec     si
        or      cx, cx
        jz      .fail
        mov     ax, bx
        clc
        pop     cx
        pop     bx
        ret
.overflow:
.fail:
        stc
        pop     cx
        pop     bx
        ret

; AL = char -> nibble in AL; CF if invalid
hex_digit:
        cmp     al, '0'
        jb      .bad
        cmp     al, '9'
        ja      .not_dec
        sub     al, '0'
        clc
        ret
.not_dec:
        or      al, 0x20
        cmp     al, 'a'
        jb      .bad
        cmp     al, 'f'
        ja      .bad
        sub     al, 'a' - 10
        clc
        ret
.bad:
        stc
        ret
