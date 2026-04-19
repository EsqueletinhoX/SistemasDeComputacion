# Sistemas de Computación - Trabajo Práctico N° 2

Este proyecto es una implementación práctica que demuestra la integración de tres capas de abstracción en el desarrollo de software (Alto Nivel, Nivel Intermedio y Bajo Nivel) mediante la obtención y procesamiento del Índice GINI de Argentina.

**Nombres**  
_Baccino, Luca; Painenao, Juan Manuel; Alejandro R. Stangaferro;_  
**Claude's Interns**

**Facultad de Ciencias Exactas, Físicas y Naturales**  
**Sistemas de Computación**
**Profesores**
_Javier A. Jorge; Miguel A. Solinas;_
**2026**

## Descripción del Proyecto

El sistema está diseñado en tres capas distintas que interactúan entre sí utilizando las convenciones de llamadas de Linux x86-64:

1. **Capa Superior (Python):** Se encarga de la comunicación web. Consume la API pública del Banco Mundial para buscar el índice GINI más reciente de Argentina.
2. **Capa Intermedia (C):** Actúa como *wrapper*. Ejecuta el script de Python, captura el valor de coma flotante, lo convierte a un número entero y prepara el entorno para invocar al hardware.
3. **Capa Inferior (Ensamblador x86-64):** Recibe el dato entero e incrementa su valor en 1. Para forzar el uso de la memoria (Pila/Stack) y demostrar el manejo del *Stack Frame*, la rutina en C pasa 6 argumentos basura en los registros para que el valor real viaje obligatoriamente como el 7mo argumento a través de la pila.

---

## Requisitos Previos

Para compilar y ejecutar este proyecto, es necesario contar con las siguientes herramientas instaladas:

* **Python 3** y la librería `requests` (`sudo apt install python3-requests`)
* **GCC** con soporte multilib (`sudo apt install build-essential gcc-multilib g++-multilib`)
* **GDB** para la depuración y análisis de memoria (`sudo apt install gdb`)

---

## Compilación y Ejecución Paso a Paso

El desarrollo y prueba de este sistema se dividió en iteraciones para validar cada capa arquitectónica. A continuación, se detalla cómo ejecutar cada parte:

### Iteración 1: Validación de la Capa Superior
Antes de compilar el sistema completo, se puede verificar que la conexión con el Banco Mundial esté operativa ejecutando el script de Python de forma aislada.

1. Ejecutar en la terminal:
   ```bash
   python3 api_gini.py
   ```
   
   Resultado:

   ![Resultado de ejecutar la iteración 1](img/python_manual.png)

### Iteración 2: Integración de Capas (C + Assembler) y Ejecución

En esta etapa, vinculamos la capa intermedia escrita en C con la subrutina de bajo nivel en Assembler. El objetivo es procesar el dato obtenido por Python y realizar la operación aritmética final directamente en el procesador, manipulando el Stack Frame.

#### 1. Compilación del Sistema Completo
Utilizamos el compilador `gcc` para unir ambos códigos fuente. Agregamos el flag `-g` para incluir información de depuración, lo cual es fundamental para el posterior análisis en GDB.

Ejecutar el siguiente comando en la terminal:
```bash
gcc -g -o programa_gini main.c gini_asm.s
```
Al ejecutar el binario resultante, el programa realiza la llamada a Python, captura el valor flotante, realiza la conversión de tipos en C y ejecuta la lógica aritmética en Assembler.
```bash
./programa_gini
```

Salida de la terminal:

![Resultado de ejecutar la iteración 1](img/iteracion2.png)

### 2: Depuración y Comprobación del Stack Frame (GDB)
Para demostrar empíricamente el paso del séptimo argumento a través de la pila (cumpliendo con la convención de llamadas x86-64 en Linux), se inspeccionó el binario compilado con la herramienta GDB.

Comandos ejecutados en el depurador para aislar la función y observar la memoria:
```bash
gdb ./programa_gini
break calcular_gini_asm
run
stepi
stepi
x/4xg $rsp
```

Salida de la terminal:

![Resultado de ejecutar la iteración 1](img/iteracion2_2.png)

**Análisis de la memoria capturada:**
Al inspeccionar los bloques de 8 bytes a partir de la nueva cima de la pila (`%rsp`), se observa la estructura exacta del Stack Frame:

* **Primera dirección (`0x7fffffffd920`)**: Contiene el viejo `%rbp` (el "ancla" de `main`), guardado por la instrucción `pushq %rbp`.
* **Segunda dirección (a 8 bytes, implícita al lado de la primera)**: Contiene la dirección de retorno a la función `main` (`0x...52ed`).
* **Tercera dirección (`0x7fffffffd930`)**: A exactamente 16 bytes del RBP actual, se encuentra el valor `0x2a` (42 en decimal). Esto confirma que, al saturar los 6 registros de propósito general, el 7mo argumento viajó correctamente por la memoria hacia la subrutina.
