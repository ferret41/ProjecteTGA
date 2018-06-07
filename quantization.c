#include <time.h>
#include <stdio.h>
#include <stdlib.h>
#include "bmp.h"

typedef struct Color {
  unsigned char r, g, b;
} Color;

int square(int value) {
  return value * value;
}

int squared_l2_distance(Color first, Color second) {
  return square(first.r - second.r) +
    square(first.g - second.g) + 
    square(first.b - second.b);
}
/*
DataFrame k_means(const DataFrame& data, size_t k, size_t number_of_iterations) {
  static random_device seed;
  static mt19937 random_number_generator(seed());
  uniform_int_distribution<size_t> indices(0, data.size() - 1);

  // Pick centroids as random points from the dataset.
  DataFrame means(k);
  for (auto& cluster : means) {
    cluster = data[indices(random_number_generator)];
  }

  vector<size_t> assignments(data.size());
  for (size_t iteration = 0; iteration < number_of_iterations; ++iteration) {
    // Find assignments.
    for (size_t point = 0; point < data.size(); ++point) {
      double best_distance = numeric_limits<double>::max();
      size_t best_cluster = 0;
      for (size_t cluster = 0; cluster < k; ++cluster) {
        const double distance =
            squared_l2_distance(data[point], means[cluster]);
        if (distance < best_distance) {
          best_distance = distance;
          best_cluster = cluster;
        }
      }
      assignments[point] = best_cluster;
    }

    // Sum up and count points for each cluster.
    DataFrame new_means(k);
    vector<size_t> counts(k, 0);
    for (size_t point = 0; point < data.size(); ++point) {
      const auto cluster = assignments[point];
      new_means[cluster].r += data[point].r;
      new_means[cluster].g += data[point].g;
      new_means[cluster].b += data[point].b;
      counts[cluster] += 1;
    }

    // Divide sums by counts to get new centroids.
    for (size_t cluster = 0; cluster < k; ++cluster) {
      // Turn 0/0 into 0/1 to avoid zero division.
      const auto count = max<size_t>(1, counts[cluster]);
      means[cluster].r = new_means[cluster].r / count;
      means[cluster].g = new_means[cluster].g / count;
      means[cluster].b = new_means[cluster].b / count;
    }
  }

  return means;
}*/

//http://www.goldsborough.me/c++/python/cuda/2017/09/10/20-32-46-exploring_k-means_in_python,_c++_and_cuda/

int size, width, height, size_row;

int getIndexColor(unsigned char *im, int index) {
  
    int i = (index*3/size_row);
    int j = ((index*3)%size_row);
   return i * size_row + j;
}

void execute_k_means(Color means[], int assigns[], unsigned char *im, int ncolors, int N_iterations) {
  int it;
  for (it = 0; it < N_iterations; ++it) {
    int i;
    for (i = 0; i < size; ++i) {
      int j;
      int index = getIndexColor(im, i);
      int dist_min = -1;
      int dist_act, assign;
      for (j = 0; j < ncolors; ++j) {
          dist_act = square(im[index+2] - means[j].r) + square(im[index+1] - means[j].g) + square(im[index] - means[j].b);
          if (dist_min == -1 || dist_act < dist_min) {
              dist_min = dist_act;
              assign = j;  
          }
      }
      assigns[i] = assign;
    }
    
    
    
    // Sum up and count points for each cluster.
    Color new_means[ncolors];
    int *counts = malloc (sizeof (int) * ncolors);
    memset (counts, 0, sizeof (int) * ncolors);
    for (i = 0; i < size; ++i) {
      int imeans = assigns[i];
      int index = getIndexColor(im, i);
      new_means[imeans].r += im[index+2];
      new_means[imeans].g += im[index+1];
      new_means[imeans].b += im[index];
      counts[imeans] += 1;
    }
  }
}

void init_means(Color means[], int ncolors, unsigned char *im) {
    srand(time(NULL));
    int r;
    int i;
    for (i = 0; i < ncolors; ++i) {
        r = rand() % size;
        int index = getIndexColor(im, r);
        means[i].r = im[index+2];
        means[i].g = im[index+1];
        means[i].b = im[index];
    }
}

void assign_colors(Color means[], unsigned char *im, int ncolors) {
  int i;
  for (i = 0; i < size; ++i) {
    int j;
    int index = getIndexColor(im, i);
    int dist_min = -1;
    int dist_act, assign;
    for (j = 0; j < ncolors; ++j) {
        dist_act = square(im[index+2] - means[j].r) + square(im[index+1] - means[j].g) + square(im[index] - means[j].b);
        if (dist_min == -1 || dist_act < dist_min) {
            dist_min = dist_act;
            assign = j;  
        }
    }
    im[index]=means[assign].b;
    im[index + 1]=means[assign].g;
    im[index + 2]=means[assign].r;  
  }
}

int main(int c, char *v[])
{
	  int ncolors;
	  if (c < 2 || c > 3) {
		  fprintf(stderr, "usage: %s ppm_file n_colors\n", v[0]);
		  return 0;
	  }
	  else if (c == 2) ncolors = 16;
	  else if (c == 3) ncolors = atoi(v[2]) ? : 16; /* GCC extension */
    
    //read:
    bmpInfoHeader infoHeader;
    unsigned char *im= LoadBMP("subaru.bmp", &infoHeader);
    
    //calcular variables globals:
    size_row = ((infoHeader.width*3 + 3) / 4) * 4;
    width = infoHeader.width;
    height = infoHeader.height;
    size = width * height;
    
    //inicialitzar means:
    Color *means = malloc(ncolors*sizeof(Color));
    init_means(means, ncolors, im);
    
    //executem k means:
    int *assigns = malloc(size*sizeof(int)); //vector d'assignacions (cada
                                             //pixel a un i_mean)
    execute_k_means(means, assigns, im, ncolors, 10);

    //assignem colors:
    assign_colors(means, im, ncolors);
    
    
    //convertir blanc i negre 1 for:
    /*for (i = 0; i < size; ++i) {
        int indexColor = getIndexColor(im, i);
        r = im[indexColor+2];
        g = im[indexColor+1];
        b = im[indexColor];
        
        color = (r+g+b)/3;
        im[indexColor]=color;
        im[indexColor + 1]=color;
        im[indexColor + 2]=color;
      
        
    }*/
    
    //print:
      /*for (i = 0; i < size; ++i) {
        int indexColor = getIndexColor(im, i);
        int r, g, b, color;
        r = im[indexColor+2];
        g = im[indexColor+1];
        b = im[indexColor];
        fprintf(stderr, "b: %d", im[i]);
        fprintf(stderr, "  g: %d", im[i+1]);
        fprintf(stderr, "  r: %d \n", im[i+2]);
      }*/
    
    /* //convertir balnc i negre 2 fors
    for (i = 0; i < height; ++i) {
      for (j = 0; j < width * 3; j += 3) {
        //int r, g, b, color;
        r = im[j+2+i*size_row];
        g = im[j+1+i*size_row];
        b = im[j+i*size_row];
        color = (r+g+b)/3;
        im[j+i*size_row]=color;
        im[j+1+i*size_row]=color;
        im[j+2+i*size_row]=color;
      }
    }
    */
    SaveBMP("sortida.bmp", &infoHeader, im);
    DisplayInfo("sortida.bmp", &infoHeader);
    //DataFrame punts = k_means(data,k,number_of_iterations);
	  //image im = read_ppm(v[1]);
	  //color_quant(im, ncolors, 0);
	  //write_ppm(im, "out.pnm");
    
    /*fprintf(stderr, "b: %d", im[j]);
      fprintf(stderr, "  g: %d", im[j+1]);
      fprintf(stderr, "  r: %d \n", im[j+2]);*/
         
         
	  //free(im);
 
	  return 0;
}
