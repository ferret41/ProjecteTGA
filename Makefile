quantization: quantization.c
	gcc -o quantization.x quantization.c bmp.c bmp.h -Wall
	
clean:
	rm -f quantization.x sortida.bmp
