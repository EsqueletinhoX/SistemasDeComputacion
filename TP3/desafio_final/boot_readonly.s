###############################################################################
# boot_readonly.s
#
# Variante de boot_pm.s donde el descriptor de DATOS se marca como SOLO LECTURA
# (access byte = 0x90 en vez de 0x92). Despues de pasar a modo protegido el
# programa intenta ESCRIBIR un byte usando ese segmento. La escritura debe
# disparar una excepcion #GP (General Protection Fault, vector 13).
#
# Como NO hay IDT instalada, la CPU no encuentra handler para #GP, intenta
# entrar a #DF, tampoco lo encuentra, y produce un TRIPLE FAULT que reinicia
# el procesador. En QEMU se observa la maquina virtual reiniciandose en bucle
# o cerrando el monitor (segun la version).
#
# Para verificar con gdb:
#   Terminal 1:  qemu-system-x86_64 -drive file=boot_readonly.bin,format=raw \
#                                   -no-reboot -no-shutdown -d int,cpu_reset \
#                                   -s -S
#   Terminal 2:  gdb -ex "target remote :1234" \
#                    -ex "set architecture i8086"
#       (gdb) b *0x7C00            # primer byte del bootloader
#       (gdb) c                    # corre hasta el comienzo
#       (gdb) si                   # avanzar instruccion por instruccion
#       (gdb) info registers
#       Cuando se ejecuta el "movb %al, (%edi)" sobre el segmento read-only,
#       la CPU genera #GP. Con -d int,cpu_reset QEMU loguea por consola la
#       interrupcion 0x0D (GP) seguida del CPU reset por triple fault.
#
# Compilacion:
#   as --32 boot_readonly.s -o boot_readonly.o
#   ld -m elf_i386 -T linker.ld --oformat binary boot_readonly.o -o boot_readonly.bin
###############################################################################

.code16
.section .text
.global _start

_start:
    cli

    inb     $0x92, %al
    orb     $0x02, %al
    outb    %al, $0x92

    lgdt    gdt_descriptor

    movl    %cr0, %eax
    orl     $0x1, %eax
    movl    %eax, %cr0

    ljmp    $0x08, $pm_start


.code32
pm_start:
    movw    $0x10, %ax              # selector de DATOS (read-only)
    movw    %ax, %ds
    movw    %ax, %es
    movw    %ax, %fs
    movw    %ax, %gs
    movw    %ax, %ss
    movl    $0x90000, %esp

    # Primero escribimos algo legitimo (lectura) para confirmar que llegamos
    # a 32 bits. Imprime "RO" en la VGA antes de la falla.
    movl    $0xB8000, %edi
    movb    $'R', (%edi)
    movb    $0x4F, 1(%edi)
    movb    $'O', 2(%edi)
    movb    $0x4F, 3(%edi)

    # ----------------------------------------------------------------
    # Intento de escritura sobre el segmento de datos READ-ONLY.
    # La escritura usa DS implicitamente (0x10 -> descriptor read-only).
    # Esto debe disparar #GP. Sin IDT -> triple fault -> reset.
    # ----------------------------------------------------------------
    movl    $target, %edi           # cualquier direccion DENTRO del segmento RO
falla:
    movb    $0xFF, (%edi)           # <-- aca dispara #GP

    # No deberiamos llegar nunca a esta linea
    hlt
    jmp     falla


###############################################################################
# Datos
###############################################################################
target:
    .byte   0x00                    # byte que intentaremos modificar


###############################################################################
# GDT con segmento de DATOS READ-ONLY (access = 0x90)
###############################################################################
.align 8
gdt_start:
    .quad   0

    # Codigo
    .word   0xFFFF
    .word   0x0000
    .byte   0x00
    .byte   0x9A
    .byte   0xCF
    .byte   0x00

    # Datos READ-ONLY
    # access = 0x90 = 1 00 1 0000
    #   P=1 DPL=00 S=1 E=0(datos) DC=0 W=0(no escribible) A=0
    .word   0xFFFF
    .word   0x0000
    .byte   0x00
    .byte   0x90                    # <-- RW=0  => read-only
    .byte   0xCF
    .byte   0x00
gdt_end:

gdt_descriptor:
    .word   gdt_end - gdt_start - 1
    .long   gdt_start


.fill 510 - (. - _start), 1, 0
.word 0xAA55
