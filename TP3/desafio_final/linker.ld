/*
 * linker.ld - Script para los bootloaders del desafio final.
 *
 * Coloca todo el contenido en la direccion 0x7C00, que es donde la BIOS
 * carga el primer sector del disco al detectar la firma 0xAA55.
 */

ENTRY(_start)

SECTIONS
{
    . = 0x7C00;

    .text : {
        *(.text)
        *(.data)
        *(.rodata*)
        *(.bss)
    }
}
