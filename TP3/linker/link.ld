SECTIONS
{
    /* The BIOS loads the bootloader at 0x7c00 */
    . = 0x7c00;
    .text :
    {
        __start = .;
        *(.text)
        /* Place the magic boot bytes at 510 */
        . = 0x1FE;
        SHORT(0xAA55)
    }
}