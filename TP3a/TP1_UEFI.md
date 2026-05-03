# Trabajo Práctico 1 — Exploración del entorno UEFI y la Shell

**Objetivo:** explorar cómo UEFI abstrae el hardware y gestiona la configuración del sistema antes de cargar el sistema operativo, usando la UEFI Shell sobre QEMU + OVMF.

> Nota previa: a diferencia del TP3 (donde escribimos un MBR de 512 bytes y arrancamos en modo real legacy), acá no estamos programando nada. Lo que se hace es **observar** desde la consola interactiva del firmware UEFI cómo está organizado el entorno antes de cargar un SO.

---

## Setup

Todos los comandos siguientes se ejecutan dentro de la **UEFI Shell**, que se levanta arrancando QEMU con el firmware OVMF (la implementación abierta de UEFI):

```bash
qemu-system-x86_64 -m 512 -bios /usr/share/ovmf/OVMF.fd -net none
```

- `-m 512`: asigna 512 MB de RAM a la VM.
- `-bios /usr/share/ovmf/OVMF.fd`: en lugar de la BIOS legacy de QEMU, carga el firmware UEFI provisto por el paquete `ovmf`.
- `-net none`: deshabilita la placa de red virtual (no la necesitamos para el TP).

Como no se le da ningún disco al QEMU, el firmware UEFI no encuentra ningún SO para arrancar, agota el `BootOrder` y cae directamente al **UEFI Interactive Shell**, donde aparece el prompt `Shell>`.

> Si tu OVMF no abre la Shell directamente sino el "Boot Manager", entrá manualmente con: **Boot Manager → EFI Internal Shell**.

---

## 1.1 Arranque en el entorno virtual

A diferencia del BIOS legacy, que tras el POST simplemente leía los primeros 512 bytes del primer disco (el MBR) y saltaba a `0x7C00`, **UEFI es un mini-sistema operativo en sí mismo**: tiene gestor de memoria, drivers cargables, una consola, una shell, variables persistentes en NVRAM, una pila de red, e incluso un sistema de archivos FAT como ciudadano de primera. Antes de entregar el control al SO, todo eso ya está corriendo.

**Comando:**

```
qemu-system-x86_64 -m 512 -bios /usr/share/ovmf/OVMF.fd -net none
```

**Qué deberías observar:**

1. Una pantalla negra inicial con el logo TianoCore.
2. Mensajes del firmware enumerando dispositivos (PCI bus, mapping de file systems, intentos de boot fallidos).
3. El prompt final de la UEFI Shell: `Shell>`.

**Captura sugerida:** `img/11_uefi_shell.png` — la pantalla con el prompt `Shell>` y los mensajes de inicialización arriba.

---

## 1.2 Exploración de Dispositivos (Handles y Protocolos)

UEFI no usa letras de unidad fijas (como `C:` en Windows) ni interrupciones predefinidas (como `int 0x13` para disco en BIOS). En su lugar mantiene una **base de datos interna** donde:

- Un **handle** es un identificador opaco (un número) que representa "algo" en el sistema: un disco, una placa de red, una consola, una imagen .efi cargada, etc.
- Un **protocolo** es una interfaz de software bien definida (estructura con punteros a funciones) que ese handle implementa. Por ejemplo `EFI_BLOCK_IO_PROTOCOL` para acceder a bloques de un disco, `EFI_SIMPLE_FILE_SYSTEM_PROTOCOL` para acceder a archivos, `EFI_GRAPHICS_OUTPUT_PROTOCOL` para la pantalla.

Cada protocolo está identificado por un **GUID** único. Cuando el firmware o un driver quiere usar un dispositivo, no toca registros del hardware: pide al firmware "dame el handle que implementa el protocolo XYZ" y obtiene una estructura con punteros a funciones que abstraen el hardware real.

### Comandos a ejecutar dentro de la UEFI Shell

```
Shell> map
Shell> FS0:
FS0:\> ls
FS0:\> exit             (volvemos al prompt Shell> )
Shell> dh -b
```

#### `map`

Lista los **mappings** entre nombres lógicos (`FS0:`, `BLK0:`, `BLK1:`, etc.) y los protocolos/dispositivos detectados. En una VM sin disco real vas a ver algo así:

```
Mapping table
      BLK0: Alias(s):
          PciRoot(0x0)/Pci(0x1,0x0)/Floppy(0x0)
      BLK1: Alias(s):
          PciRoot(0x0)/Pci(0x1,0x1)/Ata(0x0)
      ...
```

Las cadenas largas (`PciRoot(0x0)/Pci(...)/Ata(...)`) son **device paths**: una representación canónica de cómo llegar al dispositivo desde la raíz del bus PCI. Esa misma sintaxis es la que usa UEFI para identificar dispositivos en variables como `Boot####`.

#### `FS0:` y `ls`

`FS0:` cambia el "directorio actual" al primer file system detectado (típicamente la partición ESP de un disco real, o el ramdisk de OVMF en QEMU). `ls` lista los archivos y directorios.

En una VM sin disco probablemente recibas un error tipo "Map FS0 not found"; en ese caso saltá esta parte. Si OVMF montó algo, vas a ver carpetas como `EFI\BOOT\` y archivos `.efi`.

#### `dh -b`

`dh` (= _dump handle_) lista todos los handles activos del sistema y los protocolos que cada uno implementa. La opción `-b` hace _break_ cada pantalla (hay decenas de handles, sin esto sale todo de corrido).

Un volcado típico se ve así:

```
Handle dump
   1: Image(DXE Core)
   2: ImageDevicePath(...)
   3: PcdProtocol
   4: SimpleTextOutput SimpleTextInput
   5: BlockIo DiskIo PartitionInfo SimpleFileSystem
   ...
```

Cada línea es un handle (número). A la derecha aparecen los nombres simbólicos de los protocolos que ese handle expone. Notar que un mismo handle puede implementar muchos protocolos a la vez (por ejemplo, un handle de disco implementa `BlockIo`, `DiskIo` y, si tiene partición FAT, también `SimpleFileSystem`).

**Captura sugerida:** `img/12_dh_b.png` — al menos una página del `dh -b` donde se vean varios handles con sus protocolos.

---

### Pregunta de Razonamiento 1

> Al ejecutar `map` y `dh`, vemos protocolos e identificadores en lugar de puertos de hardware fijos. ¿Cuál es la ventaja de **seguridad y compatibilidad** de este modelo frente al antiguo BIOS?

**Respuesta:**

En el modelo BIOS, el código que quería usar el hardware tenía dos caminos: o llamaba interrupciones predefinidas (`int 0x10` para video, `int 0x13` para disco) que asumían comportamientos fijos del firmware, o tocaba directamente puertos de I/O y direcciones de memoria conocidas (`0x3F8` para serie, `0xB8000` para texto VGA). Esto trajo dos problemas que UEFI resuelve con el modelo de _handles + protocolos_.

**Compatibilidad.** El BIOS atornillaba el contrato a la convención del PC IBM original: discos por `int 0x13`, hasta 4 particiones primarias, geometría CHS, MBR de 512 bytes, etc. Cuando aparecieron tecnologías nuevas (USB, SATA, NVMe, GPT, Secure Boot) la BIOS tuvo que ir parchando con módulos como CSM y limitaciones cada vez más artificiales. UEFI, en cambio, define una **interfaz abstracta** (el protocolo) y deja el _cómo_ implementarla al driver del hardware concreto. Un disco SATA, uno NVMe y uno USB **exponen el mismo `EFI_BLOCK_IO_PROTOCOL`**: el bootloader y el SO los consumen igual sin saber qué hay debajo. Soportar un nuevo bus es escribir un driver que produzca ese protocolo, no rehacer la convención.

**Seguridad.** Tres ventajas concretas:

1. **No hay acceso directo al hardware.** Un programa UEFI no toca puertos: tiene que pedirle al firmware un handle y usar el protocolo. El firmware media todos los accesos y puede aplicar políticas (rechazar, auditar, etc.).
2. **Identidad fuerte por GUID.** Cada protocolo tiene un GUID de 128 bits. Dos protocolos con la misma "intención" (ej. `BlockIo` vs `BlockIo2`) son distinguibles sin ambigüedad. En la BIOS, dos vendors podían sobrecargar la misma `int 0x10` con comportamientos distintos.
3. **Cadena de confianza criptográfica.** UEFI define _Secure Boot_, donde cada imagen `.efi` (drivers y bootloader) viene firmada y el firmware verifica la firma antes de cargarla. Las imágenes ejecutadas pasan a producir nuevos handles y nuevos protocolos en una _base de datos auditable_; si alguien intentara inyectar un driver no firmado, el firmware se niega a cargarlo y nunca aparece en `dh`. Con la BIOS, cualquier código que se ejecutara desde `0x7C00` tenía privilegio total sin ninguna verificación.

En síntesis: el BIOS asumía hardware fijo con acceso directo y sin verificación; UEFI introduce una capa de indirección (handle → protocolo) que es a la vez **portable** (los consumidores no dependen del hardware concreto) y **autenticada** (el firmware controla qué entra a la base de datos).

---

## 1.3 Análisis de Variables Globales (NVRAM)

UEFI mantiene una "base de datos" de variables persistentes guardadas en una memoria no volátil (NVRAM, normalmente la misma SPI flash que aloja el firmware). Cada variable tiene:

- Un **nombre** (string).
- Un **GUID de vendor** que la agrupa por dueño (las variables del estándar UEFI viven bajo `EFI_GLOBAL_VARIABLE_GUID`, las de Microsoft bajo otro GUID, etc.).
- **Atributos**: si es no-volátil (`NV`), accesible en boot services (`BS`), accesible en runtime (`RT`), si requiere autenticación, etc.
- Un **valor** binario.

La fase del firmware encargada de leer estas variables y decidir qué arrancar se llama **BDS** (Boot Device Selection).

### Comandos

```
Shell> dmpstore
Shell> set TestSeguridad "Hola UEFI"
Shell> set -v
```

#### `dmpstore`

Vuelca todas las variables UEFI accesibles desde la Shell. Vas a ver un montón de entradas; las más interesantes para el TP son las que arrancan con `Boot` (mayúscula): `Boot0000`, `Boot0001`, ..., `BootOrder`, `BootCurrent`, `BootNext`, `Timeout`. También aparecen variables de plataforma (`PlatformLang`, `Lang`), de Secure Boot (`PK`, `KEK`, `db`, `dbx`), etc.

Cada entrada de `dmpstore` muestra GUID + nombre + atributos + dump hexadecimal del contenido. Los `Boot####` son estructuras `EFI_LOAD_OPTION` que contienen la descripción legible y el _device path_ del archivo `.efi` a ejecutar.

#### `set TestSeguridad "Hola UEFI"`

Crea una variable **de la Shell** (no de la NVRAM persistente UEFI) llamada `TestSeguridad`. Es una variable temporal que vive solo mientras la Shell está corriendo. Se usa acá únicamente para mostrar cómo se manipulan variables desde la consola.

> Aclaración: las variables que crea `set` en la Shell **no se guardan en NVRAM**. Para crear una variable UEFI persistente desde Shell hay que usar `setvar` (no es parte del TP, pero está bueno saberlo).

#### `set -v`

Lista todas las variables del entorno de la Shell (las creadas con `set`). Vas a ver `TestSeguridad = Hola UEFI` y otras variables como `path`, `cwd`, `efishellver`, etc.

**Captura sugerida:** `img/13_dmpstore_boot.png` (con scroll mostrando alguna variable `Boot####` y `BootOrder`) y `img/13_set_v.png` (mostrando `TestSeguridad`).

---

### Pregunta de Razonamiento 2

> Observando las variables `Boot####` y `BootOrder`, ¿cómo determina el Boot Manager la secuencia de arranque?

**Respuesta:**

El Boot Manager de UEFI se comporta como un mini-bootloader configurable cuyo estado vive en NVRAM. Las dos variables clave son:

- **`Boot####`** (donde `####` es un número hexadecimal de cuatro dígitos: `Boot0000`, `Boot0001`, `Boot0002`, …). Cada una es **una entrada de arranque**. Su contenido es una estructura `EFI_LOAD_OPTION` con:
  - una descripción legible (_"Windows Boot Manager"_, _"ubuntu"_, _"UEFI Shell"_, _"UEFI QEMU HARDDISK"_, …),
  - un _device path_ que indica dónde está el archivo `.efi` a ejecutar (por ejemplo `HD(1,GPT,...)/\EFI\Microsoft\Boot\bootmgfw.efi`),
  - atributos (activa/inactiva, oculta, etc.) y opcionalmente argumentos a pasar al `.efi`.
- **`BootOrder`**: un array ordenado de IDs `Boot####`. Por ejemplo, un valor de `0001 0000 0003` significa "intentá Boot0001 primero; si falla, Boot0000; si también falla, Boot0003".

El Boot Manager, en cada arranque, hace lo siguiente:

1. **Lee `BootOrder`** desde NVRAM.
2. **Itera** los IDs en ese orden.
3. Para cada ID, **lee la `Boot####`** correspondiente y resuelve el _device path_: el firmware recorre handles/protocolos para localizar el archivo `.efi` indicado.
4. Si el archivo existe y supera Secure Boot (firma válida cuando está activado), **lo carga y ejecuta**. La entrada usada queda registrada en `BootCurrent`.
5. Si el archivo no se encuentra o falla, **pasa al siguiente ID** de `BootOrder`.
6. Si se agotan todas las entradas sin éxito, cae al **default boot behavior** (típicamente, ejecutar `\EFI\BOOT\BOOTX64.EFI` de cada FS detectado), o, como en nuestro QEMU sin disco, abre el **UEFI Shell**.

Hay además variables auxiliares que ajustan el flujo:

- **`BootCurrent`**: la pone el firmware en cada boot indicando qué `Boot####` se terminó usando (útil para que el SO sepa cómo arrancó).
- **`BootNext`**: si está seteada, **se usa una sola vez** ignorando `BootOrder`, y luego el firmware la borra. Es lo que usan utilidades como `efibootmgr --bootnext` para "el próximo arranque, entrá a Windows" sin cambiar el orden permanente.
- **`Timeout`**: segundos a esperar antes de arrancar la primera entrada (durante esos segundos el usuario puede entrar al menú).

Lo importante conceptualmente es que **toda la política de arranque es declarativa y vive en NVRAM**: las entradas son "qué archivo ejecutar y dónde está", el orden es una lista, y editando esas variables (con `efibootmgr` desde Linux, `bcdedit` desde Windows, o `bcfg` desde la propia Shell) se reconfigura el booteo sin tocar el firmware.

---

## 1.4 Footprinting de Memoria y Hardware

Antes de entregar el control al SO, el firmware ya descubrió todo el hardware y armó una "foto" del sistema. Esta sección consulta tres vistas de esa foto: el mapa de memoria, los dispositivos PCI y los drivers cargados.

### Comandos

```
Shell> memmap -b
Shell> pci -b
Shell> drivers -b
```

(`-b` hace pausa cada pantalla. La salida real es larga.)

#### `memmap`

Imprime el **mapa de memoria UEFI**: una tabla con cada región de RAM y qué tipo de uso tiene. Las columnas típicas son `Type`, `Start`, `End`, `# Pages`, `Attributes`. Los tipos relevantes:

| Tipo                    | Significado                                                                 |
| ----------------------- | --------------------------------------------------------------------------- |
| `Available` / `Conventional` | RAM libre, el SO la puede usar.                                       |
| `LoaderCode` / `LoaderData`  | Código y datos cargados por el bootloader (vida hasta `ExitBootServices`). |
| `BootServicesCode/Data`     | Código y datos del firmware que se _liberan_ al salir de Boot Services.   |
| **`RuntimeServicesCode`** | **Código del firmware que sigue vivo después que el SO toma control.**    |
| **`RuntimeServicesData`** | Datos del firmware que sobreviven al `ExitBootServices`.                  |
| `ACPIReclaim`           | Tablas ACPI; el SO puede reusar la RAM una vez parseadas.                   |
| `ACPINVS`               | Datos ACPI no volátiles, el SO no debe tocar.                               |
| `MMIO` / `MMIOPortSpace`| Regiones mapeadas a hardware (no es RAM real).                              |

Lo importante: hay regiones que **el firmware se reserva para sí mismo** y siguen activas mientras el SO corre. Esa es la base de la pregunta 3.

#### `pci -b`

Lista todos los dispositivos del bus PCI (y PCIe) que el firmware enumeró: bridges, controlador SATA, USB, video, NIC, etc. Cada línea muestra `Bus`, `Device`, `Function`, `Vendor ID`, `Device ID` y una descripción corta. Es la versión UEFI del `lspci` de Linux.

#### `drivers -b`

Lista los drivers UEFI cargados, con su versión y a cuántos handles están attacheados. Drivers típicos en QEMU/OVMF: `Generic Disk I/O`, `Partition Driver`, `FAT File System`, `PCI Bus Driver`, `PciHostBridge`, `BIOS Video Driver`, `EHCI/XHCI USB`, etc.

**Captura sugerida:** `img/14_memmap.png` con al menos una región **`RuntimeServicesCode`** visible, y una de `pci -b` y otra de `drivers -b`.

---

### Pregunta de Razonamiento 3

> En el mapa de memoria (`memmap`), existen regiones marcadas como `RuntimeServicesCode`. ¿Por qué estas áreas son un objetivo principal para los desarrolladores de malware (Bootkits)?

**Respuesta:**

UEFI separa sus servicios en dos grupos según cuándo están vivos:

- **Boot Services**: solo disponibles _antes_ de que el SO llame `ExitBootServices()`. Una vez que el SO toma el control, todo ese código y sus datos pueden ser liberados.
- **Runtime Services**: **siguen disponibles después de `ExitBootServices`**, durante toda la ejecución del SO. Son funciones como `GetVariable` / `SetVariable` (lectura y escritura de variables NVRAM, incluidas las `Boot####` que vimos arriba), `GetTime` / `SetTime` (RTC), `ResetSystem`, `QueryCapsuleCapabilities`, etc.

El código que implementa esos Runtime Services vive precisamente en las regiones marcadas **`RuntimeServicesCode`** del `memmap`. El SO mapea esa memoria en su espacio virtual, y cuando necesita una de esas funciones, salta al firmware. Es decir: **es código del firmware ejecutándose dentro del contexto del SO, con privilegio máximo, mientras el sistema está corriendo**.

Eso lo vuelve un objetivo idealizado para los _bootkits_ por cinco razones que se combinan:

1. **Persistencia inmune al disco.** El código de los Runtime Services se carga desde la SPI flash de la motherboard en cada arranque. Reformatear el disco, reinstalar Windows, cambiar la SSD: nada de eso lo borra. Solo borra el bootkit reflashear el firmware.
2. **Privilegio máximo y previo al SO.** Ejecuta antes que cualquier antivirus o EDR. Para el momento en que el SO terminó de cargar, el bootkit ya tomó las decisiones que quería tomar (ej. desactivar verificaciones, modificar el kernel en vuelo, plantar drivers).
3. **Invisibilidad para el SO.** Los antivirus convencionales escanean el disco y la RAM "de su lado"; muy pocos inspeccionan las páginas de `RuntimeServicesCode`, porque están marcadas como pertenecientes al firmware y son código que el SO no controla.
4. **Punto de pivot a las llamadas del SO al firmware.** Como los Runtime Services son la única vía estándar para que el SO lea/escriba variables NVRAM, cambie la hora, etc., un atacante que controla `RuntimeServicesCode` puede **interceptar y mentirle al SO**: por ejemplo, hacer que `GetVariable("BootOrder")` devuelva un orden distinto al real, o que `GetVariable` filtre las variables con cierto nombre, o devolver firmas válidas falsificadas. El SO no tiene forma de detectar la mentira porque la única "fuente de verdad" es ese mismo código.
5. **Sobreviven a reinstalaciones del SO.** El bootkit modifica la imagen del firmware en SPI flash; en cada arranque siguiente, el firmware vuelve a copiarse a esas páginas de `RuntimeServicesCode` _ya infectadas_. El SO ve un sistema "limpio" según sus propias herramientas, pero el firmware no lo es.

Casos reales que apuntaron exactamente a este vector:

- **LoJax** (2018, ESET): primer bootkit UEFI _in-the-wild_, atribuido a APT28. Modificaba el firmware SPI para mantener persistencia.
- **MosaicRegressor** (2020, Kaspersky): inyectaba un driver UEFI que escribía un payload en disco en cada boot.
- **BlackLotus** (2023): primer bootkit UEFI público que **bypassea Secure Boot** en Windows 11 actualizado, abusando de la vulnerabilidad CVE-2022-21894 ("Baton Drop"). Persiste como driver UEFI cargado durante DXE y, como tal, vive en regiones `RuntimeServicesCode`/`BootServicesCode`.

En síntesis, `RuntimeServicesCode` es atractivo porque combina **persistencia por hardware** + **privilegio anterior al SO** + **invisibilidad relativa** + **rol de _broker_ obligatorio entre el SO y la NVRAM**. La defensa práctica pasa por Secure Boot bien configurado (con la lista `dbx` de revocaciones al día), Boot Guard / hardware root of trust del CPU, mediciones TPM y, sobre todo, mantener el firmware actualizado.

---

## Bibliografía

- UEFI Specification 2.10, capítulos 2 (_Overview_), 3 (_Boot Manager_), 7 (_Services — Boot Services_) y 8 (_Services — Runtime Services_). https://uefi.org/specifications
- TianoCore EDK II / OVMF: https://github.com/tianocore/edk2
- ESET Research, "LoJax: First UEFI rootkit found in the wild". https://www.welivesecurity.com/2018/09/27/lojax-first-uefi-rootkit-found-wild-courtesy-sednit-group/
- ESET Research, "BlackLotus UEFI bootkit: Myth confirmed" (2023). https://www.welivesecurity.com/2023/03/01/blacklotus-uefi-bootkit-myth-confirmed/
- Microsoft Docs, "UEFI firmware and drivers". https://learn.microsoft.com/windows-hardware/drivers/bringup/uefi-firmware
