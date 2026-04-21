/* main2.c  —  invoca la función suma_stack() implementada en ASM pasándole argumentos por el stack (pila) */
#include <stdio.h>

/* 
 * A diferencia de la convención System V AMD64 estándar (que usa registros),
 * vamos a pasar los argumentos manualmente por la pila usando ensamblador en línea.
 */
extern long suma_stack(void); // Declaramos sin argumentos para manejarlo manualmente

int main(void) {
    long a = 10;
    long b = 25;
    long resultado;

    /* 
     * cdecl (C declaration) es la convención de llamadas clásica e histórica 
     * del lenguaje C. Define las reglas sobre cómo una función debe recibir 
     * sus argumentos y cómo interactúa con la pila (stack). 
     * Hacemos las operaciones a mano (emulando la convención cdecl):
     * 1. Hacemos push de B (segundo argumento)
     * 2. Hacemos push de A (primer argumento)
     * 3. Llamamos a suma_stack
     * 4. Limpiamos la pila sumando 16 bytes al %rsp (2 argumentos x 8 bytes)
     */
    __asm__ (
        "pushq %[b]\n\t"
        "pushq %[a]\n\t"
        "call suma_stack\n\t"
        "addq $16, %%rsp\n\t"
        : "=a" (resultado)          // El resultado quedará en %rax
        : [a] "r" (a), [b] "r" (b)  // Le damos a y b en registros cualquiera temporalmente
        : "memory"
    );

    /* Antes de esta línea poner breakpoint en GDB:
       el compilador preparó el entorno para el printf */
    printf("suma(%ld, %ld) = %ld\n", a, b, resultado);


    extern long suma_por_pila(long r1, long r2, long r3, long r4, long r5, long r6, long a, long b);
    long res_pila = suma_por_pila(0, 0, 0, 0, 0, 0, 10, 25);
    printf("suma_por_pila(10, 25) = %ld\n", res_pila);

    return 0;
}
