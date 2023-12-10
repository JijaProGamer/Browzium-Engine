better-wgsl-preprocessor run denoising/atrous.wgsl atrous-denoiser.wgsl ^
    && better-wgsl-preprocessor run denoising/none.wgsl none-denoiser.wgsl ^
    && better-wgsl-preprocessor run compute.wgsl compute-output.wgsl ^
    && better-wgsl-preprocessor run fragment.wgsl fragment-output.wgsl 