CUDA_HOME   = /Soft/cuda/8.0.61

NVCC        = $(CUDA_HOME)/bin/nvcc
NVCC_FLAGS  = -O3 -Wno-deprecated-gpu-targets -I$(CUDA_HOME)/include -I$(CUDA_HOME)/sdk/CUDALibraries/common/inc
LD_FLAGS    = -Wno-deprecated-gpu-targets -lcudart -Xlinker -rpath,$(CUDA_HOME)/lib64 -I$(CUDA_HOME)/sdk/CUDALibraries/common/lib

EXEC        = cuda-quantization.exe
OBJC        = cuda-quantization.o bmp.o

EXEC2        = cuda-quantization_v2.exe
OBJC2        = cuda-quantization_v2.o bmp.o

EXEC3        = cuda-quantization_v3.exe
OBJC3        = cuda-quantization_v3.o bmp.o

EXE         = quantization.exe
OBJ         = quantization.o bmp.o

default: $(EXEC) $(EXEC2) $(EXEC3) $(EXE)

quantization: quantization.c
	gcc -o quantization.exe quantization.c bmp.c bmp.h -Wall
	
bmp.o: bmp.h bmp.c
	gcc -c bmp.c
	
quantization.o: quantization.c
	gcc -c quantization.c -Wall

cuda-quantization.o: cuda-quantization.cu
	$(NVCC) -c cuda-quantization.cu $(NVCC_FLAGS)
	
cuda-quantization_v2.o: cuda-quantization_v2.cu
	$(NVCC) -c cuda-quantization_v2.cu $(NVCC_FLAGS)
	
cuda-quantization_v3.o: cuda-quantization_v3.cu
	$(NVCC) -c cuda-quantization_v3.cu $(NVCC_FLAGS)

$(EXE): $(OBJ)
	gcc $(OBJ) -o $(EXE)

$(EXEC): $(OBJC) 
	$(NVCC) $(OBJC) -o $(EXEC)  $(LD_FLAGS)

$(EXEC2): $(OBJC2) 
	$(NVCC) $(OBJC2) -o $(EXEC2)  $(LD_FLAGS)
	
$(EXEC3): $(OBJC3) 
	$(NVCC) $(OBJC3) -o $(EXEC3)  $(LD_FLAGS)

clean:
	rm -rf *.o *.exe sortida.bmp Quantization.*
