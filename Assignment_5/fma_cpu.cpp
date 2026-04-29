#include <stdio.h>
#include <stdlib.h>
#include <chrono>

#define N     262144
#define ITERS 1024

#if defined(_MSC_VER)
  #define RESTRICT __restrict
#else
  #define RESTRICT __restrict__
#endif

void cpu_fma(const float * RESTRICT X,
             const float * RESTRICT Y,
             const float * RESTRICT Z,
             float       * RESTRICT R, int n) {
    for (int i = 0; i < n; i++) {
        R[i] = X[i] * Y[i] + Z[i];
    }
}

int main() {
    size_t bytes = N * sizeof(float);

    float *X = (float*)malloc(bytes);
    float *Y = (float*)malloc(bytes);
    float *Z = (float*)malloc(bytes);
    float *R = (float*)malloc(bytes);

    for (int i = 0; i < N; i++) {
        X[i] = (float)i;
        Y[i] = (float)i;
        Z[i] = (float)i;
    }

    // warm-up
    cpu_fma(X, Y, Z, R, N);

    auto t0 = std::chrono::high_resolution_clock::now();
    for (int it = 0; it < ITERS; it++) {
        cpu_fma(X, Y, Z, R, N);
    }
    auto t1 = std::chrono::high_resolution_clock::now();
    double cpu_ms = std::chrono::duration<double, std::milli>(t1 - t0).count();

    // for (int i = 0; i < N; i++) {
    //     printf("R[%d] = %f\n", i, R[i]);
    // }

    printf("=== CPU ===\n");
    printf("N = %d, ITERS = %d\n", N, ITERS);
    printf("CPU total: %.4f ms  (%.4f us/iter)\n", cpu_ms, (cpu_ms * 1000.0) / ITERS);
    printf("Sample: R[0]=%.2f  R[1]=%.2f  R[100]=%.2f  R[%d]=%.2f\n",
           R[0], R[1], R[100], N-1, R[N-1]);

    free(X); free(Y); free(Z); free(R);
    return 0;
}
