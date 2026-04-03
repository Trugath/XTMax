bits 16
cpu 8086
org 0

%define BDA_SEGMENT         0x40
%define LOAD_SEGMENT        0x0000
%define BOOT_SECTOR_OFFSET  0x7c00
%define STATUS_ROW          12

start:
    push cs
    pop ds

menu_loop:
    call draw_menu
    call read_key_upper
    cmp al, 'C'
    je continue_boot
    cmp al, 0x1b
    je continue_boot
    cmp al, 0x0d
    je continue_boot
    cmp al, 'S'
    je boot_sd
    cmp al, 'F'
    je boot_floppy
    cmp al, 'D'
    je sd_diagnostic
    call show_invalid_choice
    jmp menu_loop

continue_boot:
    retf

boot_sd:
    mov dl, 0x80
    call boot_selected_drive
    jmp menu_loop

boot_floppy:
    xor dl, dl
    call boot_selected_drive
    jmp menu_loop

sd_diagnostic:
    mov dl, 0x80
    call run_boot_diagnostic
    jmp menu_loop

boot_selected_drive:
    call read_boot_sector
    jc .read_failed
    cmp word [BOOT_SECTOR_OFFSET + 510], 0xaa55
    jne .bad_signature
    jmp LOAD_SEGMENT:BOOT_SECTOR_OFFSET
.read_failed:
    mov si, boot_read_failed_msg
    call show_status
    ret
.bad_signature:
    mov si, boot_signature_failed_msg
    call show_status
    ret

run_boot_diagnostic:
    call read_boot_sector
    jc .read_failed
    cmp word [BOOT_SECTOR_OFFSET + 510], 0xaa55
    jne .bad_signature
    mov si, diag_ok_msg
    call show_status
    ret
.read_failed:
    mov si, diag_read_failed_msg
    call show_status
    ret
.bad_signature:
    mov si, diag_signature_failed_msg
    call show_status
    ret

read_boot_sector:
    push ax
    push bx
    push cx
    push dx
    push ds
    push es
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov bx, BOOT_SECTOR_OFFSET
    mov ax, 0x0201
    mov cx, 1
    xor dh, dh
    int 0x13
    pop es
    pop ds
    pop dx
    pop cx
    pop bx
    pop ax
    ret

draw_menu:
    mov dh, 2
    mov dl, 0
    mov cx, 12
    call clear_rows

    mov dh, 2
    mov dl, 0
    mov si, title_msg
    call write_text

    mov dh, 4
    mov dl, 0
    mov si, option_sd_msg
    call write_text

    mov dh, 5
    mov dl, 0
    mov si, option_floppy_msg
    call write_text

    mov dh, 6
    mov dl, 0
    mov si, option_diag_msg
    call write_text

    mov dh, 7
    mov dl, 0
    mov si, option_continue_msg
    call write_text

    mov dh, 9
    mov dl, 0
    mov si, hint_msg
    call write_text

    mov dh, STATUS_ROW
    mov dl, 0
    mov cx, 1
    call clear_rows
    ret

show_status:
    push si
    mov dh, STATUS_ROW
    mov dl, 0
    mov cx, 2
    call clear_rows
    pop si
    mov dh, STATUS_ROW
    mov dl, 0
    call write_text
    mov dh, STATUS_ROW + 1
    mov dl, 0
    mov si, any_key_msg
    call write_text
    call wait_for_key
    ret

show_invalid_choice:
    mov si, invalid_choice_msg
    call show_status
    ret

wait_for_key:
    xor ah, ah
    int 0x16
    ret

read_key_upper:
    xor ah, ah
    int 0x16
    cmp al, 'a'
    jb .done
    cmp al, 'z'
    ja .done
    and al, 0xdf
.done:
    ret

clear_rows:
    push ax
    push bx
    push cx
    push dx
    push si
    mov si, blank_row
.next_row:
    push cx
    call write_text
    pop cx
    inc dh
    loop .next_row
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

write_text:
    push ax
    push bx
    push cx
    push dx
    push di
    push es
    push si
    call compute_text_pointer
    cld
.loop:
    lodsb
    or al, al
    jz .done
    cmp al, 0x0d
    je .done
    cmp al, 0x0a
    je .done
    mov es:[di], al
    mov byte es:[di + 1], 0x07
    add di, 2
    jmp .loop
.done:
    pop si
    pop es
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

compute_text_pointer:
    push ax
    push bx
    push cx
    push ds
    push dx
    mov ax, BDA_SEGMENT
    mov ds, ax
    mov bl, [0x49]
    mov ax, 0xb800
    cmp bl, 7
    jne .segment_ready
    mov ax, 0xb000
.segment_ready:
    mov es, ax
    xor ax, ax
    mov al, dh
    mov bl, [0x4a]
    mul bl
    mov di, ax
    xor ax, ax
    mov al, dl
    add di, ax
    shl di, 1
    mov cx, [0x4e]
    add di, cx
    pop dx
    pop ds
    pop cx
    pop bx
    pop ax
    ret

title_msg:
    db 'XTMAX SERVICE TOOL', 0
option_sd_msg:
    db 'S  Boot from XTMax SD now', 0
option_floppy_msg:
    db 'F  Boot from floppy drive A', 0
option_diag_msg:
    db 'D  SD boot-sector diagnostic', 0
option_continue_msg:
    db 'C  Continue normal BootROM flow', 0
hint_msg:
    db 'ESC or ENTER also continue', 0
diag_ok_msg:
    db 'SD boot sector looks bootable', 0
diag_read_failed_msg:
    db 'SD read failed', 0
diag_signature_failed_msg:
    db 'SD boot signature missing', 0
boot_read_failed_msg:
    db 'Boot read failed', 0
boot_signature_failed_msg:
    db 'Boot signature missing', 0
invalid_choice_msg:
    db 'Unknown choice', 0
any_key_msg:
    db 'Press any key to return', 0
blank_row:
    times 80 db ' '
    db 0
