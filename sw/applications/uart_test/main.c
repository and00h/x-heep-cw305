// Remember to build this app with make app COMPILER_FLAGS=-Os 
#include "syscalls.h"
#include <stdio.h>

int main(){
    while (1) {
        int data = getchar();
        putchar(data);
    }
    return 0;
}