###############################################################################
# boot_pm.s
#
# Bootloader minimo que pasa de modo real (16 bits) a modo protegido (32 bits),
# escrito en ensamblador GAS sin usar macros.
#
# Pasos:
#   1) Deshabilitar interrupciones (cli).
#   2) Habilitar la linea A20 via Fast A20 Gate (puerto 0x92).
#   3) Cargar la GDT (null + code + data) con lgdt.
#   4) Activar el bit PE (bit 0) del registro CR0.
#   5) Far jump a codigo de 32 bits para limpiar el pipeline y cargar CS.
#   6) Ya en modo protegido, cargar DS/ES/FS/GS/SS con el selector de datos.
#   7) Escribir el mensaje en la VGA (framebuffer 0xB8000).
#
# Compilacion:
#   as --32 boot_pm.s -o boot_pm.o
#   ld -m elf_i386 -T linker.ld --oformat binary boot_pm.o -o boot_pm.bin
#
# Ejecucion:
#   qemu-system-x86_64 -drive file=boot_pm.bin,format=raw,index=0,media=disk
###############################################################################

.code16
.section .text
.global _start

_start:
    cli                             # 1) deshabilitar interrupciones

    # 2) Habilitar A20 (Fast A20 Gate, puerto 0x92, bit 1 = 1)
    inb     $0x92, %al
    orb     $0x02, %al
    outb    %al, $0x92

    # 3) Cargar la GDT
    lgdt    gdt_descriptor

    # 4) Activar PE (bit 0 de CR0)
    movl    %cr0, %eax
    orl     $0x1, %eax
    movl    %eax, %cr0

    # 5) Far jump a 32 bits. 0x08 es el selector del segmento de codigo
    #    (indice 1 de la GDT, TI=0, RPL=0).
    ljmp    $0x08, $pm_start


###############################################################################
# Codigo de 32 bits (modo protegido)
###############################################################################
.code32
pm_start:
    # 6) Cargar registros de segmento de datos con el selector 0x10
    #    (indice 2 de la GDT, TI=0, RPL=0).
    movw    $0x10, %ax
    movw    %ax, %ds
    movw    %ax, %es
    movw    %ax, %fs
    movw    %ax, %gs
    movw    %ax, %ss
    movl    $0x90000, %esp          # stack en 0x90000

    # 7) Imprimir el mensaje en VGA (texto modo, 80x25, 0xB8000)
    movl    $0xB8000, %edi          # destino: framebuffer
    movl    $msg, %esi              # origen: cadena

print_loop:
    movb    (%esi), %al
    testb   %al, %al
    jz      hang
    movb    %al, (%edi)             # caracter
    movb    $0x1F, 1(%edi)          # atributo: blanco sobre azul
    incl    %esi
    addl    $2, %edi
    jmp     print_loop

hang:
    hlt
    jmp     hang


###############################################################################
# Datos
###############################################################################
msg:
    .asciz  "MODO PROTEGIDO OK - Hola desde 32 bits"


###############################################################################
# GDT (Global Descriptor Table)
#
# Cada descriptor ocupa 8 bytes con el siguiente layout:
#   word  : limit[0:15]
#   word  : base[0:15]
#   byte  : base[16:23]
#   byte  : access  -> P|DPL|S|E|DC|RW|A
#   byte  : flags|limit[16:19] -> G|D|L|AVL|limit_high
#   byte  : base[24:31]
###############################################################################
.align 8
gdt_start:

    # Descriptor 0: NULL (obligatorio)
    .quad   0

    # Descriptor 1 (selector 0x08): CODIGO
    # base=0x00000000, limit=0xFFFFF (con G=1 -> 4 GiB)
    # access = 0x9A  (P=1, DPL=00, S=1, E=1 codigo, DC=0, R=1, A=0)
    # flags  = 0xC   (G=1 4KiB, D=1 32 bits, L=0, AVL=0)
    .word   0xFFFF                  # limit[0:15]
    .word   0x0000                  # base[0:15]
    .byte   0x00                    # base[16:23]
    .byte   0x9A                    # access
    .byte   0xCF                    # flags(0xC)|limit[16:19]=0xF
    .byte   0x00                    # base[24:31]

    # Descriptor 2 (selector 0x10): DATOS
    # base=0x00000000, limit=0xFFFFF (con G=1 -> 4 GiB)
    # access = 0x92  (P=1, DPL=00, S=1, E=0 datos, DC=0, W=1, A=0)
    # flags  = 0xC
    .word   0xFFFF
    .word   0x0000
    .byte   0x00
    .byte   0x92
    .byte   0xCF
    .byte   0x00

gdt_end:

gdt_descriptor:
    .word   gdt_end - gdt_start - 1 # limite (tamanio - 1)
    .long   gdt_start               # base lineal de la GDT


###############################################################################
# Padding hasta 510 bytes y firma de booteo 0xAA55
###############################################################################
.fill 510 - (. - _start), 1, 0
.word 0xAA55
