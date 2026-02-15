BITS 16
ORG 0x7C00

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    sti

    mov [BOOT_DRIVE], dl

    ; Load stage2 (16 sectors) from disk: sector 2..17 into 0000:8000
    mov byte [RETRY_COUNT], 3
.read_stage2:
    mov bx, 0x8000       ; ES:BX = 0000:8000
    mov ah, 0x02         ; read sectors
    mov al, 16           ; count
    mov ch, 0            ; cylinder
    mov dh, 0            ; head
    mov cl, 2            ; sector (starts at 1; sector 1 is boot)
    mov dl, [BOOT_DRIVE] ; drive
    int 0x13
    jnc .read_ok

    ; reset disk and retry
    mov ah, 0x00
    mov dl, [BOOT_DRIVE]
    int 0x13
    dec byte [RETRY_COUNT]
    jnz .read_stage2
    jmp disk_error

.read_ok:

    jmp 0x0000:0x8000    ; jump to stage2

disk_error:
    mov si, err
.e:
    lodsb
    test al, al
    jz $
    mov ah, 0x0E
    int 0x10
    jmp .e

BOOT_DRIVE db 0
RETRY_COUNT db 0
err db "DISK READ ERROR",0

times 510-($-$$) db 0
dw 0xAA55
