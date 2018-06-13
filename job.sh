#!/bin/bash
export PATH=/Soft/cuda/8.0.61/bin:$PATH
### Directivas para el gestor de colas
# Asegurar que el job se ejecuta en el directorio actual
#$ -cwd
# Asegurar que el job mantiene las variables de entorno del shell lamador
#$ -V
# Cambiar el nombre del job
#$ -N Quantization 
# Cambiar el shell
#$ -S /bin/bash

./cuda-quantization.exe subaru.bmp 1 80 8

#nvprof --print-gpu-trace --unified-memory-profiling off ./cuda-quantization.exe subaru.bmp 10 80 10


