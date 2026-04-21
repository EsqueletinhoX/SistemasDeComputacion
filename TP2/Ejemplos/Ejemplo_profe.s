# suma2.s  —  función suma_stack(long a, long b) en AT&T syntax pasados por la pila (stack)
# Convención personalizada por stack:
#   16(%rbp) = 1er argumento (a)
#   24(%rbp) = 2do argumento (b)
#   %rax = valor de retorno

    .section .text
    .globl  suma_stack       # exportar símbolo para el linker
    .type   suma_stack, @function

suma_stack:
    # Prólogo — preparamos el stack frame
    pushq   %rbp
    movq    %rsp, %rbp
    
    # Aquí el mapa de la pila (stack frame) es:
    # 24(%rbp) -> 2do argumento (b)
    # 16(%rbp) -> 1er argumento (a)
    #  8(%rbp) -> Dirección de retorno (puesta por la instrucción 'call')
    #  0(%rbp) -> Valor original de rbp (puesto en el prólogo)
    
    movq    16(%rbp), %rax   # rax = a  (Cargamos desde la pila)
    addq    24(%rbp), %rax   # rax = a + b (Cargamos el otro argumento desde la pila)

    # Epílogo — restauramos el estado anterior
    popq    %rbp
    ret                   # retorna; el caller lee %rax

    .size   suma_stack, .-suma_stack
