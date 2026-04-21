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

Este repositorio contiene la resolución del Trabajo Práctico N° 2, cuyo objetivo es demostrar la integración de tres capas de abstracción en el desarrollo de software (Alto Nivel, Nivel Intermedio y Bajo Nivel) utilizando la obtención y procesamiento del Índice GINI de Argentina como caso de estudio.

Para evidenciar la evolución técnica del código y facilitar su corrección, el proyecto fue estructurado en dos etapas incrementales:
* **Parte 1:** Integración inicial entre Python (que actúa consumiendo la API REST) y C (compilado como una librería dinámica `.so`).
* **Parte 2:** Incorporación de la capa inferior en Ensamblador (x86-64), manipulación manual de memoria y conversión de tipos.

---

## Guía de Lectura del Repositorio

Para comprender la totalidad del flujo de trabajo, recomendamos explorar el repositorio en el siguiente orden:

1. **`Parte_1/`**: Contiene la implementación base. Revisar su archivo `README.md` para las instrucciones de compilación de la *shared library* y ejecución.
2. **`Parte_2/`**: Contiene la implementación avanzada uniendo C y ASM. Revisar su archivo `README.md` para el proceso de ensamblado y linkeo.
3. **`Parte_2/Stackframe.md`**: Documento detallado con la inspección empírica de la memoria utilizando GDB. **Este es el núcleo analítico del trabajo.**

*(Nota: Se recomienda leer la documentación de las carpetas mencionadas antes de pasar a la conclusión general).*

---

## Requisitos Previos (Generales)

Cada carpeta contiene el detalle de compilación específico de su etapa, pero a nivel general el sistema requiere:

* **Entorno:** Linux / WSL (Arquitectura x86-64).
* **Python 3:** Intérprete y gestor `pip` (Librería `requests` instalada).
* **Herramientas de compilación:** GCC y Binutils (`build-essential`, `as`).
* **Debugging:** GDB (Fundamental para la inspección de memoria documentada en la Parte 2).

---

## Conclusión General

El desarrollo de este trabajo práctico permitió consolidar de forma empírica los conceptos teóricos sobre la arquitectura x86-64 y la interacción directa entre lenguajes de distinto nivel de abstracción. A partir de la implementación dividida en fases, destacamos los siguientes hitos:

* **Interoperabilidad de Lenguajes:** Se logró establecer un puente estable y eficiente mediante la compilación de librerías compartidas (`.so`). Python delegó exitosamente el procesamiento numérico y el formateo a C, demostrando cómo los lenguajes de alto nivel pueden apoyarse en lenguajes nativos para acercarse al hardware sin perder la versatilidad web.
* **Dominio de la Convención de Llamadas:** La transición hacia la Parte 2 exigió un entendimiento estricto de la *System V AMD64 ABI*. La transferencia de datos de punto flotante (`double`) y la correcta captura de los retornos numéricos entre C y Ensamblador validaron nuestro control sobre la lógica de los registros y los tipos de datos (truncamiento vía `cvttsd2si`).
* **Transparencia del Stack Frame:** El análisis paso a paso documentado en `Stackframe.md` representa el logro técnico más importante del equipo. Mediante GDB, logramos "desnudar" el comportamiento implícito del procesador: evidenciamos cómo la instrucción `call` empuja la dirección de retorno a la pila, cómo el prólogo salvaguarda el contexto de la función llamadora (`pushq %rbp`), y comprobamos físicamente que los argumentos pasados por memoria residen en *offsets* predecibles.

En definitiva, este repositorio trasciende la simple operación aritmética de incrementar un número, convirtiéndose en una demostración comprobable de cómo los datos atraviesan el silicio, la memoria y las capas de software.
