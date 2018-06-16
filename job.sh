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

IMAGE = "subaru.bmp"

NITERATIONS = 10
SEED = 99
NCOLORS = 10 # max 12 (shared memory is 48k)

./cuda-quantization.exe IMAGE NITERATIONS SEED NCOLORS
./quantization.exe IMAGE NITERATIONS SEED NCOLORS

#nvprof --print-gpu-trace --unified-memory-profiling off ./cuda-quantization.exe subaru.bmp 10 80 10


