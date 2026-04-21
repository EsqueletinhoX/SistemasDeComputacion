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

1. **`Parte_1/`**: Contiene la implementación base. Revisar su archivo `README.md` para las instrucciones de compilación y ejecución.
2. **`Parte_2/`**: Contiene la implementación avanzada uniendo C y ASM. Revisar su archivo `README.md` para el proceso de ensamblado y linkeo.
3. **`Parte_2/Stackframe.md`**: Documento detallado con la inspección empírica de la memoria utilizando GDB.

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

El desarrollo de este trabajo práctico permitió consolidar de forma empírica los conceptos teóricos sobre la arquitectura x86-64 y la interacción directa entre lenguajes de distinto nivel de abstracción. A partir del desarrollo, destacamos los siguientes logros:

* Se logró integrar correctamente Python y C mediante librerías dinámicas (`.so`).
* Se comprendió y aplicó la convención de llamadas (System V AMD64) para el paso de datos de punto flotante.
* Se analizó el comportamiento del Stack Frame, los registros y el paso de parámetros en ejecución real usando GDB.
* Se validó el correcto truncamiento y conversión de tipos de datos a nivel de procesador.

### Punto clave

El verdadero valor de este trabajo no reside en la complejidad de la operación matemática, sino en la demostración práctica de:
* la integración de lenguajes de distinto nivel de abstracción.
* el análisis y manipulación de la memoria a bajo nivel.
* la comprensión absoluta del flujo de ejecución.
