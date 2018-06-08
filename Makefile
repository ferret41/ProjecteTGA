CUDA_HOME   = /Soft/cuda/8.0.61

NVCC        = $(CUDA_HOME)/bin/nvcc
NVCC_FLAGS  = -O3 -Wno-deprecated-gpu-targets -I$(CUDA_HOME)/include -I$(CUDA_HOME)/sdk/CUDALibraries/common/inc
LD_FLAGS    = -Wno-deprecated-gpu-targets -lcudart -Xlinker -rpath,$(CUDA_HOME)/lib64 -I$(CUDA_HOME)/sdk/CUDALibraries/common/lib
EXE	        = cuda-quantization.exe
OBJ	        = cuda-quantization.o bmp.o

default: $(EXE) quantization

quantization: quantization.c
	gcc -o quantization.exe quantization.c bmp.c bmp.h -Wall
	
bmp.o: bmp.h bmp.c
	gcc -c bmp.c

cuda-quantization.o: cuda-quantization.cu
	$(NVCC) -c cuda-quantization.cu $(NVCC_FLAGS)

$(EXE): $(OBJ) 
	$(NVCC) $(OBJ) -o $(EXE)  $(LD_FLAGS)
	rm -rf *.o

clean:
	rm -rf *.o $(EXE) quantization.exe sortida.bmp
