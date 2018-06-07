#include <time.h>
#include <stdio.h>
#include <stdlib.h>
#include "bmp.h"

typedef struct Color {
  unsigned int r, g, b;
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

int size, width, height, size_row, ncolors, N_iterations;

int getIndexColor(unsigned char *im, int index) {
  
    int i = (index*3/size_row);
    int j = ((index*3)%size_row);
   return i * size_row + j;
}

void display_means(Color means[]) {
    int i;
    for (i = 0; i < ncolors; ++i) {
        fprintf(stderr, "mean %d:  ", i);
        fprintf(stderr, "r: %d, ", means[i].r);
        fprintf(stderr, "g: %d, ", means[i].g);
        fprintf(stderr, "b: %d\n", means[i].b);
        
    }
    fprintf(stderr, "\n");
}

void execute_k_means(Color means[], int assigns[], unsigned char *im) {
  int it;
  Color *new_means = malloc(ncolors*sizeof(Color));
  int *counts = malloc (sizeof (int) * ncolors);
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
    //set count to 0
    memset (counts, 0, sizeof (int) * ncolors);
    memset (new_means, 0, sizeof (Color) * ncolors);
    for (i = 0; i < size; ++i) {
      int imeans = assigns[i];
      int index = getIndexColor(im, i);
      new_means[imeans].r += im[index+2];
      new_means[imeans].g += im[index+1];
      new_means[imeans].b += im[index];
      counts[imeans] += 1;
    }
    
    // Divide sums by counts to get new centroids.
    for (i = 0; i < ncolors; ++i) {
      // Turn 0/0 into 0/1 to avoid zero division.
      if (counts[i] == 0) counts[i] = 1;
      means[i].r = new_means[i].r / counts[i];
      means[i].g = new_means[i].g / counts[i];
      means[i].b = new_means[i].b / counts[i];
    }
  }
}

void init_means(Color means[], unsigned char *im) {
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

void assign_colors(Color means[], int assigns[], unsigned char *im) {
  int i;
  for (i = 0; i < size; ++i) {
    int index = getIndexColor(im, i);
    im[index]=means[assigns[i]].b;
    im[index + 1]=means[assigns[i]].g;
    im[index + 2]=means[assigns[i]].r;  
  }
}



void display_assigns(int assigns[]) {
    int i;
    for (i = 0; i < size; ++i) {
        fprintf(stderr, "%d:  %d\n", i, assigns[i]);
    }
}

int main(int c, char *v[])
{
	  if (c < 4 || c > 5) {
		  fprintf(stderr, "usage: %s ppm_file n_iterations seed n_colors\n", v[0]);
		  return 0;
	  }
	  else if (c == 4) ncolors = 16;
	  else if (c == 5) ncolors = atoi(v[4]) ? : 16; /* GCC extension */
    
    N_iterations = atoi(v[2]);
    //read:
    bmpInfoHeader infoHeader;
    unsigned char *im= LoadBMP(v[1], &infoHeader);
    
    //calcular variables globals:
    size_row = ((infoHeader.width*3 + 3) / 4) * 4;
    width = infoHeader.width;
    height = infoHeader.height;
    size = width * height;
    
    //inicialitzar means:
    Color *means = malloc(ncolors*sizeof(Color));
    srand(atoi(v[3])); //init seed
    init_means(means, im);
    
    display_means(means);
    
    //executem k means:
    int *assigns = malloc(size*sizeof(int)); //vector d'assignacions (cada
                                             //pixel a un i_mean)
    execute_k_means(means, assigns, im);
    //assignem colors:
    assign_colors(means, assigns, im);
    
    display_means(means);
    //display_assigns(assigns);
    
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
