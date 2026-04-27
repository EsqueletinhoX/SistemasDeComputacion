###############################################################################
# boot_segmentos.s
#
# Bootloader que pasa a modo protegido usando dos descriptores con bases
# distintas, demostrando "espacios de memoria diferenciados" para codigo y
# datos.
#
#   Codigo (selector 0x08): base = 0x00000000, limit = 4 GiB
#   Datos  (selector 0x10): base = 0x00010000, limit = 4 GiB
#
# Como base_DS != base_CS, el offset 0 de DS NO apunta al mismo lugar que el
# offset 0 de CS. En este programa:
#   - El codigo ejecuta con CS:base=0  -> la instruccion "X" en la imagen
#     queda en la direccion fisica donde realmente esta cargada (0x7C00 + ...).
#   - Los datos se acceden con DS:base=0x10000 -> el mensaje se copia
#     previamente a la direccion fisica 0x10000 y se lee con DS:0.
#
# Para escribir en la VGA (fisica 0xB8000) usamos el offset relativo a DS:
#   offset_DS = 0xB8000 - 0x10000 = 0xA8000
#
# Compilacion:
#   as --32 boot_segmentos.s -o boot_segmentos.o
#   ld -m elf_i386 -T linker.ld --oformat binary boot_segmentos.o -o boot_segmentos.bin
#
# Ejecucion:
#   qemu-system-x86_64 -drive file=boot_segmentos.bin,format=raw,index=0,media=disk
###############################################################################

.code16
.section .text
.global _start

_start:
    cli

    # Asegurar segmentos en real mode
    xorw    %ax, %ax
    movw    %ax, %ds
    movw    %ax, %ss
    movw    $0x7C00, %sp

    # ----------------------------------------------------------------
    # Copiar el mensaje de [DS:msg_data] a la direccion fisica 0x10000
    # usando rep movsb. ES:DI = 0x1000:0000 -> fisica 0x10000.
    # ----------------------------------------------------------------
    movw    $0x1000, %ax
    movw    %ax, %es
    movw    $msg_data, %si          # origen (DS=0, SI = direccion lineal)
    xorw    %di, %di                # destino offset 0 en ES
    movw    $msg_len, %cx
    cld
    rep movsb

    # ----------------------------------------------------------------
    # Habilitar A20
    # ----------------------------------------------------------------
    inb     $0x92, %al
    orb     $0x02, %al
    outb    %al, $0x92

    # ----------------------------------------------------------------
    # Cargar GDT, activar PE y far jump
    # ----------------------------------------------------------------
    lgdt    gdt_descriptor

    movl    %cr0, %eax
    orl     $0x1, %eax
    movl    %eax, %cr0

    ljmp    $0x08, $pm_start


###############################################################################
# Codigo de 32 bits
###############################################################################
.code32
pm_start:
    # DS apunta al segmento de datos cuya base es 0x10000
    movw    $0x10, %ax
    movw    %ax, %ds
    movw    %ax, %es
    movw    %ax, %fs
    movw    %ax, %gs
    movw    %ax, %ss
    movl    $0x90000, %esp

    # Leer desde DS:0 (fisica 0x10000, donde copiamos el mensaje)
    xorl    %esi, %esi
    # Escribir a DS:0xA8000 (fisica 0x10000 + 0xA8000 = 0xB8000, VGA)
    movl    $0xA8000, %edi

print_loop:
    movb    (%esi), %al
    testb   %al, %al
    jz      hang
    movb    %al, (%edi)
    movb    $0x2F, 1(%edi)          # blanco sobre verde
    incl    %esi
    addl    $2, %edi
    jmp     print_loop

hang:
    hlt
    jmp     hang


###############################################################################
# Datos del mensaje (en la imagen del bootloader, copiados a 0x10000 al iniciar)
###############################################################################
msg_data:
    .asciz  "DOS DESCRIPTORES - codigo y datos en espacios distintos"
msg_end:
.equ msg_len, msg_end - msg_data


###############################################################################
# GDT con dos descriptores con BASES DIFERENTES
###############################################################################
.align 8
gdt_start:
    # Null
    .quad   0

    # Codigo (selector 0x08): base = 0x00000000
    .word   0xFFFF                  # limit[0:15]
    .word   0x0000                  # base[0:15]
    .byte   0x00                    # base[16:23]
    .byte   0x9A                    # access (codigo, ejecutable, leible)
    .byte   0xCF                    # flags G=1 D=1 | limit[16:19]=F
    .byte   0x00                    # base[24:31]

    # Datos (selector 0x10): base = 0x00010000  <-- BASE DISTINTA
    .word   0xFFFF                  # limit[0:15]
    .word   0x0000                  # base[0:15]   = 0x0000
    .byte   0x01                    # base[16:23]  = 0x01    -> base = 0x00010000
    .byte   0x92                    # access (datos, escribible)
    .byte   0xCF                    # flags G=1 D=1 | limit[16:19]=F
    .byte   0x00                    # base[24:31]
gdt_end:

gdt_descriptor:
    .word   gdt_end - gdt_start - 1
    .long   gdt_start


.fill 510 - (. - _start), 1, 0
.word 0xAA55
