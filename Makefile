CUDA_HOME   = /Soft/cuda/8.0.61

NVCC        = $(CUDA_HOME)/bin/nvcc
NVCC_FLAGS  = -O3 -Wno-deprecated-gpu-targets -I$(CUDA_HOME)/include -I$(CUDA_HOME)/sdk/CUDALibraries/common/inc
LD_FLAGS    = -Wno-deprecated-gpu-targets -lcudart -Xlinker -rpath,$(CUDA_HOME)/lib64 -I$(CUDA_HOME)/sdk/CUDALibraries/common/lib

EXEC        = cuda-quantization.exe
OBJC        = cuda-quantization.o bmp.o

EXE         = quantization.exe
OBJ         = quantization.o bmp.o

default: $(EXEC) $(EXE)

quantization: quantization.c
	gcc -o quantization.exe quantization.c bmp.c bmp.h -Wall
	
bmp.o: bmp.h bmp.c
	gcc -c bmp.c
	
quantization.o: quantization.c
	gcc -c quantization.c -Wall

cuda-quantization.o: cuda-quantization.cu
	$(NVCC) -c cuda-quantization.cu $(NVCC_FLAGS)

$(EXE): $(OBJ)
	gcc $(OBJ) -o $(EXE)

$(EXEC): $(OBJC) 
	$(NVCC) $(OBJC) -o $(EXEC)  $(LD_FLAGS)

clean:
	rm -rf *.o *.exe sortida.bmp Quantization.*
