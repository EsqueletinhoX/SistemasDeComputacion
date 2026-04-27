# Makefile - Desafio Final: Modo protegido
#
# Compila los tres bootloaders del desafio final y permite correrlos en QEMU.
#
# Uso:
#   make                 -> compila boot_pm.bin, boot_segmentos.bin, boot_readonly.bin
#   make run-pm          -> corre boot_pm.bin en QEMU
#   make run-segmentos   -> corre boot_segmentos.bin en QEMU
#   make run-readonly    -> corre boot_readonly.bin (con logueo de #GP / triple fault)
#   make debug-readonly  -> arranca QEMU detenido y esperando gdb en :1234
#   make clean

AS      := as --32
LD      := ld -m elf_i386
LDFLAGS := -T linker.ld --oformat binary
QEMU    := qemu-system-x86_64

BINS := boot_pm.bin boot_segmentos.bin boot_readonly.bin

.PHONY: all clean run-pm run-segmentos run-readonly debug-readonly

all: $(BINS)

%.o: %.s
	$(AS) $< -o $@

%.bin: %.o linker.ld
	$(LD) $(LDFLAGS) $< -o $@

run-pm: boot_pm.bin
	$(QEMU) -drive file=$<,format=raw,index=0,media=disk

run-segmentos: boot_segmentos.bin
	$(QEMU) -drive file=$<,format=raw,index=0,media=disk

# -no-reboot evita que QEMU se reinicie al producirse el triple fault,
# -d int,cpu_reset imprime las interrupciones y los resets en stderr.
run-readonly: boot_readonly.bin
	$(QEMU) -drive file=$<,format=raw,index=0,media=disk \
	        -no-reboot -no-shutdown -d int,cpu_reset

# Detiene la CPU al inicio y abre el stub de gdb en el puerto 1234.
debug-readonly: boot_readonly.bin
	$(QEMU) -drive file=$<,format=raw,index=0,media=disk \
	        -no-reboot -no-shutdown -d int,cpu_reset -s -S

clean:
	rm -f *.o *.bin
