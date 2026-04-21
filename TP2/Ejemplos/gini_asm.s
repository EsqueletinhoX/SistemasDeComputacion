# gini_asm.s
.global calcular_gini_asm
.text

calcular_gini_asm:
    # --- PRÓLOGO DE LA FUNCIÓN ---
    # Guardamos el "ancla" del main (el viejo RBP) en la cima de la pila.
    pushq %rbp
    # Actualizamos el RBP para que apunte a nuestra nueva cima. 
    # Aquí cortamos lazos con el marco de main y creamos el nuestro.
    movq %rsp, %rbp

    # --- CUERPO DE LA FUNCIÓN ---
    # Los argumentos 1 al 6 quedaron en los registros.
    # El 7mo argumento quedó en la pila. 
    # Sabiendo que el RBP viejo (8 bytes) y la dirección de retorno (8 bytes) 
    # están apilados, nuestro 7mo argumento se encuentra exactamente a 16 bytes del RBP.
    
    movq 16(%rbp), %rax    # Traemos el 7mo argumento (nuestro GINI) desde la memoria al registro RAX
    incq %rax              # Incrementamos en 1 el valor de RAX

    # --- EPÍLOGO DE LA FUNCIÓN ---
    # Restauramos el estado previo de la pila para poder volver sano y salvo al main
    popq %rbp
    ret