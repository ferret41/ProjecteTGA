#include <time.h>
#include <stdio.h>
#include <stdlib.h>
extern "C" {
    #include "bmp.h"
}

typedef struct Color {
    unsigned int r, g, b;
} Color;

#define THREADS 1024

void CheckCudaError(char sms[], int line) {
  cudaError_t error;
 
  error = cudaGetLastError();
  if (error) {
    printf("(ERROR) %s - %s in %s at line %d\n", sms, cudaGetErrorString(error), __FILE__, line);
    exit(EXIT_FAILURE);
  }
}

int square(int value) {
    return value * value;
}

void display_means(Color means[], int N_colors) {
    int i;
    for (i = 0; i < N_colors; ++i) {
        fprintf(stderr, "mean %d:  ", i);
        fprintf(stderr, "r: %d, ", means[i].r);
        fprintf(stderr, "g: %d, ", means[i].g);
        fprintf(stderr, "b: %d\n", means[i].b);
        
    }
    fprintf(stderr, "\n");
}

void display_assigns(int assigns[], int Size) {
    int i;
    for (i = 0; i < Size; ++i) {
        fprintf(stderr, "%d:  %d\n", i, assigns[i]);
    }
}

void init_means(Color means[], unsigned char *im, int Size_row, int N_colors, int Size) {
    int r;
    int i;
    for (i = 0; i < N_colors; ++i) {
        r = rand() % Size;
        int index = (r*3/Size_row) * Size_row + ((r*3)%Size_row);
        means[i].r = im[index+2];
        means[i].g = im[index+1];
        means[i].b = im[index];
    }
}

void find_best_mean_seq(Color means[], int assigns[], unsigned char *im, int N, int ncolors, int Size_row) {
    int i;
    for (i = 0; i < N; ++i) {
        int j;
        int index = (i*3/Size_row) * Size_row + ((i*3)%Size_row);
        int dist_min = -1;
        int dist_act, assign;
        for (j = 0; j < ncolors; ++j) {
            dist_act = (im[index+2] - means[j].r)*(im[index+2] - means[j].r) + (im[index+1] - means[j].g)*(im[index+1] - means[j].g) + (im[index] - means[j].b)*(im[index] - means[j].b);
            if (dist_min == -1 || dist_act < dist_min) {
                dist_min = dist_act;
                assign = j;  
            }
        }
        assigns[i] = assign;
    }
}

__global__ void find_best_mean_par(Color means[], int assigns[], unsigned char *im, int N, int ncolors, int Size_row) {
    int id = blockIdx.x * blockDim.x + threadIdx.x;
    if (id < N) {
        int j;
        int index = (id*3/Size_row) * Size_row + ((id*3)%Size_row);
        int dist_min = -1;
        int dist_act, assign;
        for (j = 0; j < ncolors; ++j) {
            dist_act = (im[index+2] - means[j].r)*(im[index+2] - means[j].r) + (im[index+1] - means[j].g)*(im[index+1] - means[j].g) + (im[index] - means[j].b)*(im[index] - means[j].b);
            if (dist_min == -1 || dist_act < dist_min) {
                dist_min = dist_act;
                assign = j;  
            }
        }
        assigns[id] = assign;
    }
}

void divide_sums_by_counts_seq(Color means_host[], int N_colors, Color new_means[], int counts[]) {
    int i;
    for (i = 0; i < N_colors; ++i) {
        //Turn 0/0 into 0/1 to avoid zero division.
        if(counts[i] == 0) counts[i] = 1;
        means_host[i].r = new_means[i].r / counts[i];
        means_host[i].g = new_means[i].g / counts[i];
        means_host[i].b = new_means[i].b / counts[i];
    }
}

__global__ void divide_sums_by_counts_par(Color means_device[], int N_colors, Color new_means[], int counts[]) {
    int id = blockIdx.x * blockDim.x + threadIdx.x;
    if (id < N_colors) {
        //Turn 0/0 into 0/1 to avoid zero division.
        if(counts[id] == 0) counts[id] = 1;
        means_device[id].r = new_means[id].r / counts[id];
        means_device[id].g = new_means[id].g / counts[id];
        means_device[id].b = new_means[id].b / counts[id];
    }
}

void sum_up_and_count_points_seq(Color new_means[], int assigns[], unsigned char *im, int counts[], int Size_row, int Size) {
    int i;
    for (i = 0; i < Size; ++i) {
        int index = (i*3/Size_row) * Size_row + ((i*3)%Size_row);
        int imeans = assigns[i];
        new_means[imeans].r += im[index+2];
        new_means[imeans].g += im[index+1];
        new_means[imeans].b += im[index];
        counts[imeans] += 1;
    }
    
}

__global__ void sum_up_and_count_points_par(Color new_means[], int assigns[], unsigned char *im, int counts[],
            int Size_row, int Size, int N_colors) {
     
    extern __shared__ Color shared[];
    
    int *s_counts = (int *) shared; //matrix
    Color *s_new_means = N_colors * sizeof(int) + shared; //matrix
    
    unsigned int tid = threadIdx.x;
    unsigned int id = blockIdx.x*blockDim.x + threadIdx.x;
    
    //inicialitzar 
    for (int j = 0; j < N_colors; ++j) {
        
        if (j == assigns[id]) {
            int index = (id*3/Size_row) * Size_row + ((id*3)%Size_row);
            s_new_means[tid*N_colors + j].r = im[index+2];
            s_new_means[tid*N_colors + j].g = im[index+1];
            s_new_means[tid*N_colors + j].b = im[index];
            s_counts[tid*N_colors + j] = 1;
        }
        else {
            s_new_means[tid*N_colors + j].r = 0;
            s_new_means[tid*N_colors + j].g = 0;
            s_new_means[tid*N_colors + j].b = 0;
            s_counts[tid*N_colors + j] = 0;
        }
    }
    __syncthreads();
    
    //reduccio
    unsigned int s;
    for(s=1; s < blockDim.x; s *= 2) { 
        if (tid % (2*s) == 0) {
            for (int j = 0; j < N_colors; ++j) {
                
                s_new_means[tid*N_colors + j].r += s_new_means[(tid + s)*N_colors + j].r;
                s_new_means[tid*N_colors + j].g += s_new_means[(tid + s)*N_colors + j].g;
                s_new_means[tid*N_colors + j].b += s_new_means[(tid + s)*N_colors + j].b;
                
                s_counts[tid*N_colors + j] += s_counts[(tid + s)*N_colors + j];
            }
        }
        __syncthreads(); 
    }
    __syncthreads();
    //copiar valors:
    if (tid == 0) {
       for (int j = 0; j < N_colors; ++j) {
            new_means[j].r = s_new_means[j].r;
            new_means[j].g = s_new_means[j].g;
            new_means[j].b = s_new_means[j].b;
            counts[j] = s_counts[j];
        } 
    }
    new_means[0].r = 99;
}

__global__ void findandsum(Color means[],Color new_means[], int assigns[], unsigned char *im, int counts[],
    int Size_row, int Size, int ncolors) {
    int id = blockIdx.x * blockDim.x + threadIdx.x;
    if (id < Size) {
		int j;
        int index = (id*3/Size_row) * Size_row + ((id*3)%Size_row);
        int dist_min = -1;
        int dist_act, assign;
        for (j = 0; j < ncolors; ++j) {
            dist_act = (im[index+2] - means[j].r)*(im[index+2] - means[j].r) + (im[index+1] - means[j].g)*(im[index+1] - means[j].g) + (im[index] - means[j].b)*(im[index] - means[j].b);
            if (dist_min == -1 || dist_act < dist_min) {
                dist_min = dist_act;
                assign = j;  
            }
        }
        assigns[id] = assign;
        
        atomicAdd(&new_means[assign].r, im[index+2]);
        atomicAdd(&new_means[assign].g, im[index+1]);
        atomicAdd(&new_means[assign].b, im[index]);
        atomicAdd(&counts[assign], 1);
    }
    
}

void assign_colors_seq(Color means[], int assigns[], unsigned char *im, int Size_row, int Size) {
    int i;
    for (i = 0; i < Size; ++i) {
        int index = (i*3/Size_row) * Size_row + ((i*3)%Size_row);
        im[index]=means[assigns[i]].b;
        im[index + 1]=means[assigns[i]].g;
        im[index + 2]=means[assigns[i]].r;  
    }
}

__global__ void assign_colors_par(Color means[], int assigns[], unsigned char *im, int Size_row, int Size) {
    int id = blockIdx.x * blockDim.x + threadIdx.x;
    if (id < Size) {
        int index = (id*3/Size_row) * Size_row + ((id*3)%Size_row);
        im[index]=means[assigns[id]].b;
        im[index + 1]=means[assigns[id]].g;
        im[index + 2]=means[assigns[id]].r;  
    }
}

int main(int c, char *v[])
{
    int N_colors;
    if (c < 4 || c > 5) {
        fprintf(stderr, "usage: %s ppm_file n_iterations seed n_colors\n", v[0]);
        return -1;
    }
    
    else if (c == 4) N_colors = 16;
    else if (c == 5) N_colors = atoi(v[4]) ? : 16;
    
    //read image:
    bmpInfoHeader infoHeader;
    unsigned char *im_host = LoadBMP(v[1], &infoHeader);
    
    //init variables:
    float elapsedTime;
    int N_iterations = atoi(v[2]);
    int Size_row = ((infoHeader.width*3 + 3) / 4) * 4;
    int width = infoHeader.width;
    int height = infoHeader.height;
    int Size = width * height;
    
    //init seed
    srand(atoi(v[3])); 
    
    //obtenir memoria HOST:
    Color *means_host;
    means_host = (Color*) malloc(N_colors*sizeof(Color));
    
    //inicialitzar means:
    init_means(means_host, im_host, Size_row, N_colors, Size);
    
    //cuda events:
    cudaEvent_t start, stop;
    cudaEventCreate(&start);
    cudaEventCreate(&stop);
    
    
    //START RECORD!!
    cudaEventRecord(start, 0);

    //init grid, block, nThreads:
    unsigned int nBlocks, nBlocksMeans, nThreads;
    nThreads = THREADS;
    nBlocks = (Size + nThreads - 1)/nThreads;

    ///dim3 dimGrid(nBlocks, 1, 1);
    dim3 dimGrid(1, 1, 1); ///EDIT!!!!!!!!!!!!!
    dim3 dimBlock(nThreads, 1, 1);
    
    nBlocksMeans = (N_colors + nThreads - 1)/nThreads;

    dim3 dimGridMeans(nBlocksMeans, 1, 1);
  
    //obtenir memoria DEVICE:
    Color *means_device;
    Color *new_means;
    int *counts;
    
    int *assigns;
    unsigned char *im_device;
    
    
    cudaMalloc((Color**)&means_device, N_colors*sizeof(Color));
    cudaMalloc((Color**)&new_means, N_colors*sizeof(Color));
    cudaMalloc((int**)&counts, N_colors * sizeof (int));
    
    cudaMalloc((int**)&assigns, Size*sizeof(int));
    cudaMalloc((unsigned char**)&im_device, infoHeader.imgsize* sizeof(unsigned char));
    CheckCudaError((char *) "Obtener Memoria en el device", __LINE__);
    
    //copiar dades al device:
    cudaMemcpy(im_device, im_host, infoHeader.imgsize * sizeof(unsigned char), cudaMemcpyHostToDevice);
    cudaMemcpy(means_device, means_host, N_colors*sizeof(Color), cudaMemcpyHostToDevice);
    CheckCudaError((char *) "Copiar Datos Host --> Device", __LINE__);
    
    //shared memory size:
    int sh_mem_size = THREADS * (N_colors * sizeof (int)  + Size * sizeof (Color));
    //executem k means:
    
    int it;
    for (it = 0; it < N_iterations; ++it) {
        
        //set counts and new_means to 0
        cudaMemset (counts, 0, sizeof (int) * N_colors);
        cudaMemset (new_means, 0, sizeof (Color) * N_colors);
        
        //for each pixel find the best mean.
        find_best_mean_par<<<dimGrid, dimBlock>>>(means_device, assigns, im_device, Size, N_colors, Size_row);
        
        cudaDeviceSynchronize();
        
        //Sum up and count points for each cluster.
        sum_up_and_count_points_par<<<dimGrid, dimBlock, sh_mem_size>>>(new_means, assigns, im_device, counts, Size_row, Size, N_colors);
        
        cudaMemcpy(means_host, new_means, N_colors * sizeof(Color), cudaMemcpyDeviceToHost);
        display_means(means_host, N_colors);
        cudaDeviceSynchronize();
        
        /*
		findandsum<<<dimGrid, dimBlock>>>(means_device,new_means, assigns, im_device, counts, Size_row, Size, N_colors);
		cudaDeviceSynchronize();
       */
        
        
        //Divide sums by counts to get new centroids.
        //divide_sums_by_counts_par<<<dimGridMeans, dimBlock>>>(means_device, N_colors, new_means, counts);
        
        cudaDeviceSynchronize();
        
        
        
    }
    
    //assignem colors:
    assign_colors_par<<<dimGrid, dimBlock>>>(means_device, assigns, im_device, Size_row, Size);
    
    //copy to host:
    cudaMemcpy(im_host, im_device, infoHeader.imgsize * sizeof(unsigned char), cudaMemcpyDeviceToHost);
    
    
    //STOP RECORD!!
    cudaEventRecord(stop, 0);
    cudaEventSynchronize(stop);
    cudaEventElapsedTime(&elapsedTime, start, stop);
    
    //save image
    SaveBMP("sortida.bmp", &infoHeader, im_host);
    DisplayInfo("sortida.bmp", &infoHeader);
    
    int bytes_read_written = 2 * infoHeader.imgsize* sizeof(unsigned char) + //leer imagen y copiarla
                             N_iterations * (                                //en cada iteracion se hace:
                                sizeof (int) * 2 * N_colors +                   //leer y modificar counts
                                sizeof (Color) * N_colors +                     //leer y modificar medias
                                Size * 2 * sizeof(int) +                        //leer y modificar las asignaciones
                                Size * 3 * sizeof (unsigned char)               //leer datos de imagen
                             );       
    
    printf("\Quantization CUDA\n");
    printf("Image Size: %d\n", Size);
    printf("nThreads: %d\n", nThreads);
    printf("nBlocks: %d\n", nBlocks);
    printf("Tiempo Total %4.6f ms\n", elapsedTime);
    printf("Ancho de Banda %4.3f GB/s\n", (bytes_read_written) / (1000000 * elapsedTime));

    cudaEventDestroy(start);
    cudaEventDestroy(stop);    
    
    //alliberar memoria HOST:
    free(im_host);
    free(means_host);
    
    //alliberar memoria DEVICE:
    cudaFree(means_device);
    cudaFree(new_means);
    cudaFree(assigns);
    cudaFree(im_device);
    cudaFree(counts);
    return 0;
}
