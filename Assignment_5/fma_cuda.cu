#include <stdio.h>
#include <stdlib.h>
#include <cuda_runtime.h>

#define N       8192*32
#define ITERS   1024
#define THREADS 256
#define BLOCKS  (N / THREADS)

__global__ void fmaKernel(const float *X, const float *Y, const float *Z, float *R, int n) {
    int gid = blockIdx.x * blockDim.x + threadIdx.x;
    // int warp_id = threadIdx.x / 32;
    // int lane_id = threadIdx.x % 32;
    // int smid;
    // asm("mov.u32 %0, %%smid;" : "=r"(smid));

    if (gid < n) {
        R[gid] = X[gid] * Y[gid] + Z[gid];
    }

    // if (lane_id == 0 && gid < n && blockIdx.x < 4) {
    //     printf("Block %d | SM %d | Warp %d | Global Thread %d\n",
    //            blockIdx.x, smid, warp_id, gid);
    // }
    // if (gid < n) {
    //     printf("R[%d] = %f\n", gid, R[gid]);
    // }
}

int main() {
    size_t bytes = N * sizeof(float);

    float *hX = (float*)malloc(bytes);
    float *hY = (float*)malloc(bytes);
    float *hZ = (float*)malloc(bytes);
    float *hR = (float*)malloc(bytes);

    for (int i = 0; i < N; i++) {
        hX[i] = (float)i;
        hY[i] = (float)i;
        hZ[i] = (float)i;
    }

    float *dX, *dY, *dZ, *dR;
    cudaMalloc(&dX, bytes);
    cudaMalloc(&dY, bytes);
    cudaMalloc(&dZ, bytes);
    cudaMalloc(&dR, bytes);

    cudaMemcpy(dX, hX, bytes, cudaMemcpyHostToDevice);
    cudaMemcpy(dY, hY, bytes, cudaMemcpyHostToDevice);
    cudaMemcpy(dZ, hZ, bytes, cudaMemcpyHostToDevice);

    cudaEvent_t start, stop;
    cudaEventCreate(&start);
    cudaEventCreate(&stop);

    // warm-up
    fmaKernel<<<BLOCKS, THREADS>>>(dX, dY, dZ, dR, N);
    cudaDeviceSynchronize();

    cudaEventRecord(start);
    for (int it = 0; it < ITERS; it++) {
        fmaKernel<<<BLOCKS, THREADS>>>(dX, dY, dZ, dR, N);
    }
    cudaEventRecord(stop);
    cudaEventSynchronize(stop);

    float gpu_ms = 0.0f;
    cudaEventElapsedTime(&gpu_ms, start, stop);

    cudaMemcpy(hR, dR, bytes, cudaMemcpyDeviceToHost);

    // for (int i = 0; i < N; i++) {
    //     printf("R[%d] = %f\n", i, hR[i]);
    // }

    printf("=== GPU ===\n");
    printf("N = %d, ITERS = %d, BLOCKS = %d, THREADS = %d\n", N, ITERS, BLOCKS, THREADS);
    printf("GPU total: %.4f ms  (%.4f us/iter)\n", gpu_ms, (gpu_ms * 1000.0) / ITERS);
    printf("Sample: R[0]=%.2f  R[1]=%.2f  R[100]=%.2f  R[%d]=%.2f\n",
           hR[0], hR[1], hR[100], N-1, hR[N-1]);

    cudaEventDestroy(start);
    cudaEventDestroy(stop);
    cudaFree(dX); cudaFree(dY); cudaFree(dZ); cudaFree(dR);
    free(hX); free(hY); free(hZ); free(hR);
    return 0;
}
