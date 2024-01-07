//import * as tf from '@tensorflow/tfjs';
//import '@tensorflow/tfjs-backend-webgpu';

//tf.setBackend('webgpu')

class TensorflowDenoiser {
    parent;

    constructor(parent) {
        this.parent = parent;
    }

    makeBindGroups() {
        /*// render textures

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
        });*/
    }

    async makePipelines() {
        console.log(tf, 69420);

        return;
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


    async denoise() {
        
    }
}

module.exports = TensorflowDenoiser;