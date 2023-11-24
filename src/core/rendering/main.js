//import Denoiser from "./denoiser.js"

/*
    Triangle struct:

    a, b, c - 3 * 4
    na, nb, nc - 3 * 4
    material_id - 4
    padding0 - 4
    padding1 - 4
    padding2 - 4
*/

let triangleStride = (3 * 4) + (3 * 4) + 4;

/*
    Material struct:

    color - 4 * 4
    transparency - 4
    index_of_refraction - 4
    padding0 - 4
    padding1 - 4
*/

let materialStride = 4 + 1 + 1 + (1 * 2);

function getNext2Power(n) {
    return Math.pow(2, Math.ceil(Math.log2(n + 1)));
}

class RenderingManager {
    // globals

    opts;
    canvas;
    #lastCanvasSize = { width: 0, height: 0 }
    #materials = [];

    // raw gpu context

    adapter;
    device;
    context;

    presentationFormat;

    // compute pipeline

    computePipeline;
    renderPipeline;

    #computeDataBindGroup
    #computeMaterialBindGroup
    #computeMapBindGroup
    #computeImageBindGroup

    #computeDataLayout
    #computeMaterialLayout
    #computeMapLayout
    #computeImageLayout

    #renderTexture;
    #renderReadTexture;

    #computeGlobalData;
    #computeMapData;
    #computeMaterialData;

    // Camera

    #Camera

    // Denoiser

    //#Denoiser

    // Renderer Data

    antiAlias = true;
    gammaCorrect = true;

    constructor(opts = {}, Camera) {
        if (!navigator.gpu) {
            throw Error("WebGPU not supported.");
        }

        if (!opts.canvas || !(opts.canvas instanceof HTMLCanvasElement)) {
            throw Error("Canvas should be a HTMLCanvasElement!")
        }

        this.canvas = opts.canvas;
        this.opts = opts;

        this.#Camera = Camera

        //this.#Denoiser = new Denoiser(opts.canvas)
    }

    async #makeBindGroups() {
        /*
            Albedo - 4 channels (r, g, b, w)

        */

        // render textures

        let TextureSize = this.canvas.width * this.canvas.height * 4 * 4;
        let ComputeSize = TextureSize * 1;

        this.#renderTexture = this.device.createBuffer({
            size: ComputeSize,
            usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_SRC,
        });

        this.#renderReadTexture = this.device.createBuffer({
            size: ComputeSize,
            usage: GPUBufferUsage.MAP_READ | GPUBufferUsage.COPY_DST,
        });

        // Data

        this.#computeGlobalData = this.device.createBuffer({
            size: 112,
            usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST,
        });


        // Bind groups

        this.#computeDataBindGroup = this.device.createBindGroup({
            layout: this.#computeDataLayout,
            label: "Browzium Engine compute shader data bind group",
            entries: [
                {
                    binding: 0,
                    resource: {
                        buffer: this.#computeGlobalData,
                    },
                }
            ],
        });

        this.#computeMaterialBindGroup = this.device.createBindGroup({
            layout: this.#computeMaterialLayout,
            label: "Browzium Engine compute shader material bind group",
            entries: [
                {
                    binding: 0,
                    resource: {
                        buffer: this.#computeMaterialData,
                    },
                }
            ],
        });

        this.#computeMapBindGroup = this.device.createBindGroup({
            layout: this.#computeMapLayout,
            label: "Browzium Engine compute shader map bind group",
            entries: [
                {
                    binding: 0,
                    resource: {
                        buffer: this.#computeMapData,
                    },
                }
            ],
        });

        this.#computeImageBindGroup = this.device.createBindGroup({
            layout: this.#computeImageLayout,
            label: "Browzium Engine compute shader image bind group",
            entries: [
                {
                    binding: 0,
                    resource: {
                        buffer: this.#renderTexture,
                    },
                }
            ],
        });
    }

    async #makePipelines() {
        const shader = this.device.createShaderModule({ code: this.opts.shader, label: "Browzium engine shader" });

        this.#computeDataLayout = this.device.createBindGroupLayout({
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

        this.#computeMaterialLayout = this.device.createBindGroupLayout({
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

        this.#computeMapLayout = this.device.createBindGroupLayout({
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

        this.#computeImageLayout = this.device.createBindGroupLayout({
            entries: [
                {
                    binding: 0,
                    visibility: GPUShaderStage.COMPUTE | GPUShaderStage.FRAGMENT,
                    buffer: {
                        type: "storage",
                    },
                },
            ],
        });

        let pipelineLayout = this.device.createPipelineLayout({
            bindGroupLayouts: [this.#computeDataLayout, this.#computeMaterialLayout, this.#computeMapLayout, this.#computeImageLayout],
            label: "Browzium Engine Pipeline Layout",
        })

        this.computePipeline = this.device.createComputePipeline({
            layout: pipelineLayout,
            label: "Browzium Engine Compute Pipeline",
            compute: {
                module: shader,
                entryPoint: "computeMain",
            },
        });

        this.renderPipeline = this.device.createRenderPipeline({
            layout: pipelineLayout,
            label: "Browzium Engine Render Pipeline",
            vertex: {
                module: shader,
                entryPoint: 'vertexMain',
            },
            fragment: {
                module: shader,
                entryPoint: 'fragmentMain',
                targets: [
                    {
                        format: this.presentationFormat,
                    },
                ],
            },
            primitive: {
                topology: 'triangle-list',
            }
        })
    }

    async #generateImage() {

        // Run the compute shader

        const commandEncoder = this.device.createCommandEncoder();

        const passEncoder = commandEncoder.beginComputePass();

        passEncoder.setPipeline(this.computePipeline);

        passEncoder.setBindGroup(0, this.#computeDataBindGroup);
        passEncoder.setBindGroup(1, this.#computeMapBindGroup);
        passEncoder.setBindGroup(2, this.#computeMaterialBindGroup)
        passEncoder.setBindGroup(3, this.#computeImageBindGroup);

        passEncoder.dispatchWorkgroups(Math.ceil(this.canvas.width / 16), Math.ceil(this.canvas.height / 16), 1); //  Z for SPP
        passEncoder.end();

        this.device.queue.submit([commandEncoder.finish()]);
        await this.device.queue.onSubmittedWorkDone()
    }

    async #readImage(){
        const copyCommandEncoder = this.device.createCommandEncoder();
        copyCommandEncoder.copyBufferToBuffer(this.#renderTexture, 0, this.#renderReadTexture, 0, this.#renderReadTexture.size);
        this.device.queue.submit([copyCommandEncoder.finish()]);
        await this.device.queue.onSubmittedWorkDone();

        await this.#renderReadTexture.mapAsync(GPUMapMode.READ);

        const arrayBuffer = this.#renderReadTexture.getMappedRange();
        const data = new Float32Array(new Float32Array(arrayBuffer));

        this.#renderReadTexture.unmap();

        return data
    }

    async #renderImage() {
        // Write image to scren

        const commandEncoder = this.device.createCommandEncoder();
        const currentTexture = this.context.getCurrentTexture();

        const passEncoder = commandEncoder.beginRenderPass({
            colorAttachments: [{
                view: currentTexture.createView(),
                loadValue: { r: 1.0, g: 0, b: 1.0, a: 1.0 },
                loadOp: "clear",
                storeOp: 'store',
            }],
            label: "Browzium render pass"
        });

        passEncoder.setPipeline(this.renderPipeline);

        passEncoder.setBindGroup(0, this.#computeDataBindGroup);
        passEncoder.setBindGroup(1, this.#computeMapBindGroup);
        passEncoder.setBindGroup(2, this.#computeMaterialBindGroup)
        passEncoder.setBindGroup(3, this.#computeImageBindGroup);

        passEncoder.draw(6, 2, 0, 0);
        passEncoder.end();

        this.device.queue.submit([commandEncoder.finish()]);
    }

    #UpdateData() {
        let computeGlobalData = new Float32Array([
            this.canvas.width,
            this.canvas.height,

            this.#Camera.FieldOfView,
            0,

            this.#Camera.Position.x,
            this.#Camera.Position.y,
            this.#Camera.Position.z,
            0,

            ...this.#Camera.CameraToWorldMatrix.getContents(),

            this.antiAlias,
            this.gammaCorrect
        ])

        this.#Camera.wasCameraUpdated = false;
        this.device.queue.writeBuffer(this.#computeGlobalData, 0, computeGlobalData, 0, computeGlobalData.length);
    }

    async SetMaterials(materialList, dontUpdateBuffer) {
        this.#materials = materialList;
        let startIndex = 0;

        let oldSize = (this.#computeMaterialData || { size: 0 }).size / 4
        let newSize = getNext2Power(Object.keys(materialList).length) * materialStride + startIndex

        let totalSize = startIndex + newSize

        while (totalSize % 4 > 0) {
            totalSize++;
        }

        let materialData = new Float32Array(totalSize);

        if (totalSize > oldSize) {
            this.#computeMaterialData = this.device.createBuffer({
                size: materialData.byteLength,
                usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST,
            });

            if (!dontUpdateBuffer) {
                await this.#makeBindGroups()
            }
        }

        let materialsKeys = Object.keys(materialList)
        for (let matIndex = 0; matIndex < materialsKeys.length; matIndex++) {
            let material = materialList[materialsKeys[matIndex]]
            let locationStart = materialStride * matIndex + startIndex;

            // Color

            materialData[locationStart + 0] = material.diffuse.x;
            materialData[locationStart + 1] = material.diffuse.y;
            materialData[locationStart + 2] = material.diffuse.z;
            materialData[locationStart + 3] = 0;

            // Other stuff

            materialData[locationStart + 4] = material.transparency;
            materialData[locationStart + 5] = material.index_of_refraction;

            // Padding

            materialData[locationStart + 6] = 0;
            materialData[locationStart + 7] = 0;
        }

        this.device.queue.writeBuffer(this.#computeMaterialData, 0, materialData, 0, materialData.length);
    }

    async SetTriangles(triangleArray, dontUpdateBuffer) {
        let startIndex = 4;

        let oldSize = (this.#computeMapData || { size: 0 }).size / 4
        let newSize = getNext2Power(triangleArray.length) * triangleStride + startIndex

        let totalSize = startIndex + newSize

        while (totalSize % 4 > 0) {
            totalSize++;
        }

        let triangleData = new Float32Array(totalSize);

        if (totalSize > oldSize) {
            this.#computeMapData = this.device.createBuffer({
                size: triangleData.byteLength,
                usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST,
            });

            if (!dontUpdateBuffer) {
                await this.#makeBindGroups()
            }
        }

        triangleData[0] = triangleArray.length
        triangleData[1] = 0
        triangleData[2] = 0
        triangleData[3] = 0

        let materialsKeys = Object.keys(this.#materials)
        for (let triIndex = 0; triIndex < triangleArray.length; triIndex++) {
            let triangle = triangleArray[triIndex]
            let locationStart = triangleStride * triIndex + startIndex;

            // Vertices

            triangleData[locationStart + 0] = triangle.a.x;
            triangleData[locationStart + 1] = triangle.a.y;
            triangleData[locationStart + 2] = triangle.a.z;
            triangleData[locationStart + 3] = 0;

            triangleData[locationStart + 4] = triangle.b.x;
            triangleData[locationStart + 5] = triangle.b.y;
            triangleData[locationStart + 6] = triangle.b.z;
            triangleData[locationStart + 7] = 0;

            triangleData[locationStart + 8] = triangle.c.x;
            triangleData[locationStart + 9] = triangle.c.y;
            triangleData[locationStart + 10] = triangle.c.z;
            triangleData[locationStart + 11] = 0;

            // Normals

            triangleData[locationStart + 12] = triangle.na.x;
            triangleData[locationStart + 13] = triangle.na.y;
            triangleData[locationStart + 14] = triangle.na.z;
            triangleData[locationStart + 15] = 0;

            triangleData[locationStart + 16] = triangle.nb.x;
            triangleData[locationStart + 17] = triangle.nb.y;
            triangleData[locationStart + 18] = triangle.nb.z;
            triangleData[locationStart + 19] = 0;

            triangleData[locationStart + 20] = triangle.nc.x;
            triangleData[locationStart + 21] = triangle.nc.y;
            triangleData[locationStart + 22] = triangle.nc.z;
            triangleData[locationStart + 23] = 0;

            // Other data

            triangleData[locationStart + 24] = materialsKeys.indexOf(triangle.material);
            triangleData[locationStart + 25] = 0;
            triangleData[locationStart + 26] = 0;
            triangleData[locationStart + 27] = 0;
        }

        this.device.queue.writeBuffer(this.#computeMapData, 0, triangleData, 0, triangleData.length);
    }

    async RenderFrame(readImage) {
        if (this.canvas.width !== this.#lastCanvasSize.width || this.canvas.height !== this.#lastCanvasSize.height) {
            this.#lastCanvasSize = { width: this.canvas.width, height: this.canvas.height }

            await this.#makeBindGroups()
            this.#Camera.wasCameraUpdated = true;
        }

        if (this.#Camera.wasCameraUpdated) {
            this.#UpdateData();
        }

        await this.#generateImage();
        await this.#renderImage();

        if(readImage){
            return {image: this.#readImage()}
        }
    }

    async Init() {
        this.context = this.canvas.getContext('webgpu');
        this.adapter = await navigator.gpu.requestAdapter({ powerPreference: "high-performance" });
        if (!this.adapter) {
            throw Error("Couldn't request WebGPU adapter.");
        }

        this.device = await this.adapter.requestDevice({ label: "Browzium GPU Device" });
        this.presentationFormat = await navigator.gpu.getPreferredCanvasFormat();

        await this.context.configure({
            device: this.device,
            format: this.presentationFormat,
            alphaMode: "opaque",
            usage: GPUTextureUsage.COPY_DST | GPUTextureUsage.RENDER_ATTACHMENT
        })

        await this.SetMaterials([], true);
        await this.SetTriangles([], true);
        await this.#makePipelines();
        await this.#makeBindGroups();
        this.#UpdateData();

        //await this.#Denoiser.Init()
    }
}

export default RenderingManager