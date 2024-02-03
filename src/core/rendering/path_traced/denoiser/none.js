class emptyDenoiser {
    parent;
    holder;

    constructor(parent, holder) {
        this.parent = parent;
        this.holder = holder;
    }

    makeBindGroups() {
        this.renderTextureColor = this.parent.device.createTexture({
            size: { width: this.parent.canvas.width, height: this.parent.canvas.height },
            format: 'rgba16float',
            usage: GPUTextureUsage.COPY_DST | GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.RENDER_ATTACHMENT,
        });

        this.renderTextureAlbedo = this.parent.device.createTexture({
            size: { width: this.parent.canvas.width, height: this.parent.canvas.height },
            format: 'rgba16float',
            usage: GPUTextureUsage.COPY_DST | GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.STORAGE_BINDING,
        });

        this.renderTextureOutput = this.parent.device.createTexture({
            size: { width: this.parent.canvas.width, height: this.parent.canvas.height },
            format: 'rgba16float',
            usage: GPUTextureUsage.COPY_SRC | GPUTextureUsage.STORAGE_BINDING,
        });

        // Bind groups


        this.computeImageBindGroup = this.parent.device.createBindGroup({
            layout: this.computeImageLayout,
            label: "Browzium Engine None denoiser compute shader image bind group",
            entries: [
                {
                    binding: 0,
                    resource: this.renderTextureColor.createView(),
                    //resource: this.parent.renderTextureColor.createView(),
                },
                {
                    binding: 1,
                    resource: this.renderTextureAlbedo.createView(),
                    //resource: this.parent.renderTextureAlbedo.createView(),
                },
                {
                    binding: 2,
                    resource: this.renderTextureOutput.createView(),
                    //resource: this.parent.renderDenoisedTexture.createView(),
                }
            ],
        });
    }

    makePipelines() {
        const shader = this.parent.device.createShaderModule({ code: this.parent.opts.shaders.path_traced.denoisers.none, label: "Browzium engine compute shader none denoiser code" });

        this.computeImageLayout = this.parent.device.createBindGroupLayout({
            entries: [
                {
                    binding: 0,
                    visibility: GPUShaderStage.COMPUTE,
                    texture: {
                        format: "rgba16float",
                    }
                },
                {
                    binding: 1,
                    visibility: GPUShaderStage.COMPUTE,
                    texture: {
                        format: "rgba16float",
                    }
                },
                {
                    binding: 2,
                    visibility: GPUShaderStage.COMPUTE,
                    storageTexture: {
                        access: "write-only",
                        format: "rgba16float",
                    }
                },
            ],
        });

        let pipelineLayout = this.parent.device.createPipelineLayout({
            bindGroupLayouts: [this.computeImageLayout],
            label: "Browzium Engine None Denoiser Pipeline Layout",
        })

        this.computePipeline = this.parent.device.createComputePipeline({
            layout: pipelineLayout,
            label: "Browzium Engine None Denoiser Compute Pipeline",
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
                texture: this.holder.renderTextureColor,
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
                texture: this.holder.renderTextureAlbedo,
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

    async denoise() {
        this.#copyTracedData()

        const commandEncoder = this.parent.device.createCommandEncoder();
        const passEncoder = commandEncoder.beginComputePass();

        passEncoder.setPipeline(this.computePipeline);

        passEncoder.setBindGroup(0, this.computeImageBindGroup);

        passEncoder.dispatchWorkgroups(Math.ceil(this.parent.canvas.width / 16), Math.ceil(this.parent.canvas.height / 16), 1);
        passEncoder.end();

        this.parent.device.queue.submit([commandEncoder.finish()]);
        await this.parent.device.queue.onSubmittedWorkDone()

        // copy output

        const copyEncoder = this.parent.device.createCommandEncoder();

        copyEncoder.copyTextureToTexture(
            {
                texture: this.renderTextureOutput,
            },
            {
                texture: this.holder.renderTextureReadDenoised,
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

module.exports = emptyDenoiser;