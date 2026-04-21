// main.c
#include <stdio.h>
#include <stdlib.h>

// Declaramos la función que escribimos en Assembler. 
// Le pasamos 6 enteros largos "basura" y el 7mo es el valor real que nos importa.
extern long calcular_gini_asm(long a1, long a2, long a3, long a4, long a5, long a6, long gini_valor);

int main() {
    FILE *fp;
    char buffer[128];
    float gini_float = 0.0;

    printf("C: Iniciando programa. Solicitando dato a Python...\n");

    fp = popen("python3 -c 'from api_gini import obtener_gini_argentina; print(obtener_gini_argentina())'", "r");
    
    if (fp == NULL) {
        printf("C: Error al ejecutar Python.\n");
        return 1;
    }

    if (fgets(buffer, sizeof(buffer), fp) != NULL) {
        gini_float = strtof(buffer, NULL);
        printf("C: Recibido de Python el valor flotante: %f\n", gini_float);
    }
    pclose(fp);

    // Convertimos de flotante a entero
    long gini_entero = (long)gini_float;
    printf("C: Conversión a entero (previo a ASM) = %ld\n", gini_entero);

    // --- LLAMADA A ASSEMBLER ---
    // Pasamos 10, 20, 30, 40, 50 y 60 solo para saturar los 6 registros disponibles.
    // Nuestro 'gini_entero' es el 7mo argumento, por lo que viajará por la pila.
    long resultado_final = calcular_gini_asm(10, 20, 30, 40, 50, 60, gini_entero);
    
    printf("C: Resultado devuelto por Assembler (+1) = %ld\n", resultado_final);

    return 0;
}