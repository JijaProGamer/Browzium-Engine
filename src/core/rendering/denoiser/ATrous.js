class ATrousDenoiser {
    levels = 5;
    levelSteps = []//[1, 3, 5, 8, 11]
    colorStrenght = 0;
    normalStrenght = 0.5;
    depthStrenght = 0.1;

    parent;

    constructor(parent) {
        this.parent = parent;
    }

    makeBindGroups() {
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

        this.renderTextureObject = this.parent.device.createTexture({
            size: { width: this.parent.canvas.width, height: this.parent.canvas.height },
            format: 'r32float',
            usage: GPUTextureUsage.COPY_DST | GPUTextureUsage.TEXTURE_BINDING,
        });

        this.renderTextureOutput = this.parent.device.createTexture({
            size: { width: this.parent.canvas.width, height: this.parent.canvas.height },
            format: 'rgba16float',
            usage: GPUTextureUsage.COPY_SRC | GPUTextureUsage.STORAGE_BINDING,
        });

        // Data

        this.filteringData = this.parent.device.createBuffer({
            size: 20,
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
                },
                {
                    binding: 4,
                    resource: this.renderTextureObject.createView(),
                },
                {
                    binding: 5,
                    resource: this.renderTextureOutput.createView(),
                }
            ],
        });

        this.computeFilteringDataBindGroup = this.parent.device.createBindGroup({
            layout: this.computeFilteringDataLayout,
            label: "Browzium Engine ATrous denoiser compute shader image bind group",
            entries: [
                {
                    binding: 0,
                    resource: {
                        buffer: this.filteringData
                    },
                }
            ]
        });
    }

    makePipelines() {
        const shader = this.parent.device.createShaderModule({ code: this.parent.opts.shaders.denoisers.atrous, label: "Browzium engine compute shader atrous denoiser code" });

        this.computeFilteringDataLayout = this.parent.device.createBindGroupLayout({
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
                    visibility: GPUShaderStage.COMPUTE,
                    texture: {
                        format: "rgba16float",
                        viewDimension: "2d",
                        multisampled: false,
                    }
                },
                {
                    binding: 1,
                    visibility: GPUShaderStage.COMPUTE,
                    texture: {
                        format: "rgba16float",
                        viewDimension: "2d",
                        multisampled: false,
                    }
                },
                {
                    binding: 2,
                    visibility: GPUShaderStage.COMPUTE,
                    texture: {
                        format: "rgba16float",
                        viewDimension: "2d",
                        multisampled: false,
                    }
                },
                {
                    binding: 3,
                    visibility: GPUShaderStage.COMPUTE,
                    texture: {
                        format: "rgba16float",
                        viewDimension: "2d",
                        multisampled: false,
                    }
                },
                {
                    binding: 4,
                    visibility: GPUShaderStage.COMPUTE,
                    texture: {
                        format: "r32float",
                        viewDimension: "2d",
                        multisampled: false,
                    }
                },
                {
                    binding: 5,
                    visibility: GPUShaderStage.COMPUTE,
                    storageTexture: {
                        access: "write-only",
                        format: "rgba16float",
                        viewDimension: "2d",
                        multisampled: false,
                    }
                },
            ],
        });

        let pipelineLayout = this.parent.device.createPipelineLayout({
            bindGroupLayouts: [this.parent.computeDataLayout, this.computeImageLayout, this.computeFilteringDataLayout],
            label: "Browzium Engine ATrous Denoiser Pipeline Layout",
        })

        this.computePipeline = this.parent.device.createComputePipeline({
            layout: pipelineLayout,
            label: "Browzium Engine ATrous Denoiser Compute Pipeline",
            compute: {
                module: shader,
                entryPoint: "computeMain",
            },
        });
    }

    async #runLevel(level) {
        // set data
        let isLastStep = level == this.levels

        let filteringDataArray = new Float32Array([
            this.colorStrenght,
            this.normalStrenght,
            this.depthStrenght,

            this.levelSteps[level - 1] || Math.pow(2, level),
            isLastStep,
        ])

        this.parent.device.queue.writeBuffer(this.filteringData, 0, filteringDataArray, 0, filteringDataArray.length);

        // run denoiser

        const commandEncoder = this.parent.device.createCommandEncoder();
        const passEncoder = commandEncoder.beginComputePass();

        passEncoder.setPipeline(this.computePipeline);

        passEncoder.setBindGroup(0, this.parent.computeDataBindGroup);
        passEncoder.setBindGroup(1, this.computeImageBindGroup);
        passEncoder.setBindGroup(2, this.computeFilteringDataBindGroup);

        passEncoder.dispatchWorkgroups(Math.ceil(this.parent.canvas.width / 16), Math.ceil(this.parent.canvas.height / 16), 1);
        passEncoder.end();

        this.parent.device.queue.submit([commandEncoder.finish()]);
        await this.parent.device.queue.onSubmittedWorkDone()

        // copy output

        if (level < this.levels) {
            const copyEncoder = this.parent.device.createCommandEncoder();

            copyEncoder.copyTextureToTexture(
                {
                    texture: this.renderTextureOutput,
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

            this.parent.device.queue.submit([copyEncoder.finish()]);
            await this.parent.device.queue.onSubmittedWorkDone()
        }
    }

    #copyTracedData() {
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

        copyEncoder.copyTextureToTexture(
            {
                texture: this.parent.renderTextureObject,
            },
            {
                texture: this.renderTextureObject,
            },
            {
                width: this.parent.canvas.width,
                height: this.parent.canvas.height,
                depthOrArrayLayers: 1,
            },
        );

        this.parent.device.queue.submit([copyEncoder.finish()]);
    }

    async denoise() {
        this.#copyTracedData()

        for (let level = 1; level <= this.levels; level++) {
            await this.#runLevel(level)
        }

        const copyEncoder = this.parent.device.createCommandEncoder();

        copyEncoder.copyTextureToTexture(
            {
                texture: this.renderTextureOutput,
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

        /*const copyEncoder = this.parent.device.createCommandEncoder();

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

        this.parent.device.queue.submit([copyEncoder.finish()]);*/
    }
}

module.exports = ATrousDenoiser;