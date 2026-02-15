BITS 16
ORG 0x8000

start:
    sti                     ; allow interrupts so HLT can wake properly
    mov [BOOT_DRIVE], dl

    ; Set 80x25 text mode
    mov ax, 0x0003
    int 0x10

    ; Clear screen (scroll up whole window)
    mov ax, 0x0600
    mov bh, 0x07
    mov cx, 0x0000
    mov dx, 0x184F
    int 0x10

    ; Draw taskbar on last row (row 24)
    call draw_taskbar

    ; Print centered boot banner
    call show_banner

    ; Load kernel (stub)
    call load_kernel_stub

    ; Print prompt
    mov si, prompt
    call print_string

main_loop:
    ; Non-blocking keyboard check
    mov ah, 0x01
    int 0x16
    jz .idle                 ; no key available

    xor ax, ax
    int 0x16                 ; read key (AL=ascii, AH=scancode)

    cmp al, 13               ; Enter
    je .enter
    cmp al, 8                ; Backspace
    je .backspace
    cmp al, 0
    je main_loop             ; ignore non-ascii keys

    ; printable char -> echo
    call put_char
    jmp main_loop

.idle:
    hlt                      ; yield CPU until next interrupt
    jmp main_loop

.enter:
    call newline
    mov si, prompt
    call print_string
    jmp main_loop

.backspace:
    call do_backspace
    jmp main_loop

; -------------------------
; Text output helpers
; -------------------------

put_char:
    ; Write char AL at cursor with attribute (green-ish on black)
    mov ah, 0x09
    mov bh, 0x00
    mov bl, [CUR_ATTR]       ; attribute
    mov cx, 1
    int 0x10

    ; advance cursor
    mov ah, 0x03
    mov bh, 0
    int 0x10                 ; DH=row, DL=col
    inc dl
    cmp dl, 80
    jb .set
    call newline
    ret
.set:
    mov ah, 0x02
    mov bh, 0
    int 0x10
    ret

newline:
    mov ah, 0x03
    mov bh, 0
    int 0x10
    inc dh
    mov dl, 0
    ; keep typing area above taskbar (row 24 reserved)
    cmp dh, 24
    jb .ok
    call scroll_up
    mov dh, 23
.ok:
    mov ah, 0x02
    mov bh, 0
    int 0x10
    ret

do_backspace:
    ; If at col 0, do nothing (simple)
    mov ah, 0x03
    mov bh, 0
    int 0x10
    cmp dl, 0
    jne .move_left
    cmp dh, 0
    je .done
    dec dh
    mov dl, 79
    mov ah, 0x02
    mov bh, 0
    int 0x10
    jmp .erase
.move_left:
    dec dl
    mov ah, 0x02
    mov bh, 0
    int 0x10

    ; overwrite with space
.erase:
    mov al, ' '
    mov ah, 0x09
    mov bh, 0
    mov bl, [CUR_ATTR]
    mov cx, 1
    int 0x10

    ; cursor stays where it is (already moved back)
.done:
    ret

print_string:
    lodsb
    test al, al
    jz .done
    call put_char
    jmp print_string
.done:
    ret

draw_taskbar:
    ; Put cursor at row 24 col 0
    mov ah, 0x02
    mov bh, 0
    mov dh, 24
    mov dl, 0
    int 0x10

    ; Fill entire row with spaces using a different color
    mov al, ' '
    mov ah, 0x09
    mov bh, 0
    mov bl, 0x1F            ; white on blue-ish
    mov cx, 80
    int 0x10

    ; Write label
    mov ah, 0x02
    mov bh, 0
    mov dh, 24
    mov dl, 1
    int 0x10
    mov al, [CUR_ATTR]
    push ax
    mov byte [CUR_ATTR], 0x1F
    mov si, task
    call print_string
    pop ax
    mov [CUR_ATTR], al

    ; Return cursor to row 0 col 0
    mov ah, 0x02
    mov bh, 0
    mov dh, 0
    mov dl, 0
    int 0x10
    ret

show_banner:
    mov al, [CUR_ATTR]
    push ax
    mov byte [CUR_ATTR], 0x0F

    ; Center banner on row 0
    mov ah, 0x02
    mov bh, 0
    mov dh, 0
    mov dl, BANNER_COL
    int 0x10

    mov si, banner
    call print_string

    ; Move cursor to row 1 col 0 for prompt/messages
    mov ah, 0x02
    mov bh, 0
    mov dh, 1
    mov dl, 0
    int 0x10

    pop ax
    mov [CUR_ATTR], al
    ret

scroll_up:
    ; Scroll typing area (rows 0-23) up by one line
    mov ah, 0x06
    mov al, 1
    mov bh, [CUR_ATTR]
    mov cx, 0x0000
    mov dx, 0x174F
    int 0x10
    ret

load_kernel_stub:
    ; Placeholder loader: adjust sector/layout as the image evolves
    mov si, loadmsg
    call print_string
    call newline

    mov ax, KERNEL_SEG
    mov es, ax
    xor bx, bx

    mov ah, 0x02
    mov al, KERNEL_SECTORS
    mov ch, 0
    mov dh, 0
    mov cl, KERNEL_SECTOR
    mov dl, [BOOT_DRIVE]
    int 0x13
    jnc .ok

    mov si, loadfail
    call print_string
    call newline
.ok:
    ret

prompt db "void> ",0
task   db " VoidOS   [VoidCMD]   [Files]   [Settings] ",0
banner db "VoidOS (C) 2026",0
loadmsg  db "Loading kernel...",0
loadfail db "Kernel load failed.",0

BOOT_DRIVE db 0
CUR_ATTR   db 0x0A

BANNER_LEN    equ 15
BANNER_COL    equ 32
KERNEL_SEG    equ 0x1000
KERNEL_SECTOR equ 18
KERNEL_SECTORS equ 32
