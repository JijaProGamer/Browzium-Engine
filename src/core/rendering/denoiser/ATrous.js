class ATrousDenoiser {
    renderTextureColor;
    renderTextureNormal;
    renderTextureDepth;
    renderTextureAlbedo;

    computeGlobalData;

    computeImageBindGroup;

    parent;

    constructor(parent){
        this.parent = parent;
    }

    makeBindGroups(){
        // render textures

        this.renderTextureColor = this.parent.device.createTexture({
            size: { width: this.parent.canvas.width, height: this.parent.canvas.height },
            format: 'rgba16float',
            usage: GPUTextureUsage.COPY_DST | GPUTextureUsage.TEXTURE_BINDING,
        });

        this.renderTextureNormal = this.parent.device.createTexture({
            size: { width: this.parent.canvas.width, height: this.parent.canvas.height },
            format: 'rgba16float',
            usage: GPUTextureUsage.COPY_DST | GPUTextureUsage.TEXTURE_BINDING,
        });

        this.renderTextureDepth = this.parent.device.createTexture({
            size: { width: this.parent.canvas.width, height: this.parent.canvas.height },
            format: 'rgba16float',
            usage: GPUTextureUsage.COPY_DST | GPUTextureUsage.TEXTURE_BINDING,
        });

        this.renderTextureAlbedo = this.parent.device.createTexture({
            size: { width: this.parent.canvas.width, height: this.parent.canvas.height },
            format: 'rgba16float',
            usage: GPUTextureUsage.COPY_DST | GPUTextureUsage.TEXTURE_BINDING,
        });

        // Data

        this.computeGlobalData = this.parent.device.createBuffer({
            size: 112,
            usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST,
        });


        // Bind groups

        this.computeImageBindGroup = this.parent.device.createBindGroup({
            layout: this.computeImageLayout,
            label: "Browzium Engine ATrous denoiser compute shader image bind group",
            entries: [
                {
                    binding: 0,
                    resource: this.renderTextureColor.createView(),
                },
                {
                    binding: 1,
                    resource: this.renderTextureNormal.createView(),
                },
                {
                    binding: 2,
                    resource: this.renderTextureDepth.createView(),
                },
                {
                    binding: 3,
                    resource: this.renderTextureAlbedo.createView(),
                }
            ],
        });
    }

    makePipelines(){
        const shader = this.parent.device.createShaderModule({ code: this.parent.opts.shaders.denoisers.atrous, label: "Browzium engine compute shader atrous denoiser code" });

        this.computeDataLayout = this.parent.device.createBindGroupLayout({
            entries: [
                {
                    binding: 0,
                    visibility: GPUShaderStage.COMPUTE | GPUShaderStage.FRAGMENT,
                    buffer: {
                        type: "read-only-storage",
                    },
                },
            ],
        });

        this.computeImageLayout = this.parent.device.createBindGroupLayout({
            entries: [
                {
                    binding: 0,
                    visibility: GPUShaderStage.COMPUTE | GPUShaderStage.FRAGMENT,
                    texture: {
                        format: "rgba16float",
                        viewDimension: "2d",
                        multisampled: false,
                    }
                },
                {
                    binding: 1,
                    visibility: GPUShaderStage.COMPUTE | GPUShaderStage.FRAGMENT,
                    texture: {
                        format: "rgba16float",
                        viewDimension: "2d",
                        multisampled: false,
                    }
                },
                {
                    binding: 2,
                    visibility: GPUShaderStage.COMPUTE | GPUShaderStage.FRAGMENT,
                    texture: {
                        format: "rgba16float",
                        viewDimension: "2d",
                        multisampled: false,
                    }
                },
                {
                    binding: 3,
                    visibility: GPUShaderStage.COMPUTE | GPUShaderStage.FRAGMENT,
                    texture: {
                        format: "rgba16float",
                        viewDimension: "2d",
                        multisampled: false,
                    }
                },
                /*{
                    binding: 4,
                    visibility: GPUShaderStage.COMPUTE | GPUShaderStage.COMPUTE,
                    storageTexture: {
                        access: "write-only",
                        format: "rgba16float",
                        viewDimension: "2d",
                        multisampled: false,
                    }
                },*/
            ],
        });

        let pipelineLayout = this.parent.device.createPipelineLayout({
            bindGroupLayouts: [this.computeDataLayout, this.computeImageLayout],
            label: "Browzium Engine Pipeline Layout",
        })

        this.computePipeline = this.parent.device.createComputePipeline({
            layout: pipelineLayout,
            label: "Browzium Engine Compute Pipeline",
            compute: {
                module: shader,
                entryPoint: "computeMain",
            },
        });
    }

    #copyTracedData(){
        const copyEncoder = this.parent.device.createCommandEncoder();

        copyEncoder.copyTextureToTexture(
            {
                texture: this.parent.renderTextureColor,
            },
            {
                texture: this.renderTextureColor,
            },
            {
                width: this.parent.canvas.width,
                height: this.parent.canvas.height,
                depthOrArrayLayers: 1,
            },
        );

        copyEncoder.copyTextureToTexture(
            {
                texture: this.parent.renderTextureNormal,
            },
            {
                texture: this.renderTextureNormal,
            },
            {
                width: this.parent.canvas.width,
                height: this.parent.canvas.height,
                depthOrArrayLayers: 1,
            },
        );

        copyEncoder.copyTextureToTexture(
            {
                texture: this.parent.renderTextureDepth,
            },
            {
                texture: this.renderTextureDepth,
            },
            {
                width: this.parent.canvas.width,
                height: this.parent.canvas.height,
                depthOrArrayLayers: 1,
            },
        );

        copyEncoder.copyTextureToTexture(
            {
                texture: this.parent.renderTextureAlbedo,
            },
            {
                texture: this.renderTextureAlbedo,
            },
            {
                width: this.parent.canvas.width,
                height: this.parent.canvas.height,
                depthOrArrayLayers: 1,
            },
        );

        this.parent.device.queue.submit([copyEncoder.finish()]);
    }

    denoise(){
        this.#copyTracedData()

        const copyEncoder = this.parent.device.createCommandEncoder();

        copyEncoder.copyTextureToTexture(
            {
                texture: this.parent.renderTextureColor,
            },
            {
                texture: this.parent.renderTextureReadDenoised,
            },
            {
                width: this.parent.canvas.width,
                height: this.parent.canvas.height,
                depthOrArrayLayers: 1,
            },
        );

        this.parent.device.queue.submit([copyEncoder.finish()]);
    }
}

module.exports = ATrousDenoiser;