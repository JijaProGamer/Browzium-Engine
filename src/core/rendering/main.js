//import Denoiser from "./denoiser.js"

/*
    Triangle struct:

    a, b, c - 3 * 4 * 3

*/

let triangleStride = 3 * 4 * 3;

function getNext2Power(n) {
    return Math.pow(2, Math.ceil(Math.log2(n + 1)));
}

class RenderingManager {
    // globals

    opts;
    canvas;
    #lastCanvasSize = { width: 0, height: 0 }
    #lastData = ""

    // raw gpu context

    adapter;
    device;
    context;

    presentationFormat;

    // render pipeline

    renderPipeline;

    // compute pipeline

    computePipeline
    #computeLayout
    #computeBindGroup

    #renderTexture;
    #renderReadTexture;

    #computeGlobalData;
    #computeMapData;

    #Denoiser

    constructor(opts = {}) {
        if (!navigator.gpu) {
            throw Error("WebGPU not supported.");
        }

        if (!opts.canvas || !(opts.canvas instanceof HTMLCanvasElement)) {
            throw Error("Canvas should be a HTMLCanvasElement!")
        }

        this.canvas = opts.canvas;
        this.opts = opts;

        //this.#Denoiser = new Denoiser(opts.canvas)

        this.opts.cameraPosition = [0, 0, 0]
        this.opts.cameraRotation = [0, 0, 0]
    }

    async #makeBindGroups() {
        /*
            Albedo - 3 channels (r, g, b)

        */

        // render textures

        let ComputeSize = this.canvas.width * this.canvas.height * 3 * 4

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
            size: (4 * 2) + 4 + (4 * 3) + (4 * 3),
            usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST,
        });

        this.#computeLayout = this.device.createBindGroupLayout({
            entries: [
                {
                    binding: 0,
                    visibility: GPUShaderStage.COMPUTE,
                    buffer: {
                        type: "storage",
                    },
                },
                {
                    binding: 1,
                    visibility: GPUShaderStage.COMPUTE,
                    buffer: {
                        type: "read-only-storage",
                    },
                },
                {
                    binding: 2,
                    visibility: GPUShaderStage.COMPUTE,
                    buffer: {
                        type: "read-only-storage",
                    },
                },
            ],
        });

        this.#computeBindGroup = this.device.createBindGroup({
            layout: this.#computeLayout,
            label: "Browzium Engine compute shader bind group",
            entries: [
                {
                    binding: 0,
                    resource: {
                        buffer: this.#renderTexture,
                    },
                },
                {
                    binding: 1,
                    resource: {
                        buffer: this.#computeGlobalData,
                    },
                },
                {
                    binding: 2,
                    resource: {
                        buffer: this.#computeMapData,
                    },
                },
            ],
        });
    }

    async #makePipelines() {
        const computeShader = this.device.createShaderModule({ code: this.opts.shaders.compute, label: "Browzium compute shader" });

        this.computePipeline = this.device.createComputePipeline({
            layout: this.device.createPipelineLayout({
                bindGroupLayouts: [this.#computeLayout],
                label: "Browzium Engine Compute Pipeline Layout",
            }),
            label: "Browzium Engine Compute Pipeline",
            compute: {
                module: computeShader,
                entryPoint: "main",
            },
        });
    }

    async #generateImage() {

        // Run the compute shader

        const commandEncoder = this.device.createCommandEncoder();

        const passEncoder = commandEncoder.beginComputePass();

        passEncoder.setPipeline(this.computePipeline);
        passEncoder.setBindGroup(0, this.#computeBindGroup);
        passEncoder.dispatchWorkgroups(Math.ceil(this.canvas.width / 8), Math.ceil(this.canvas.height / 8), 1); //  Z for SPP
        passEncoder.end();

        this.device.queue.submit([commandEncoder.finish()]);
        await this.device.queue.onSubmittedWorkDone()

        // Read the results

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

    async #renderImage(image) {
        //console.log(image)

        // Write image to scren

        const imageData = this.context.createImageData(this.canvas.width, this.canvas.height);
        for (let i = 0; i < image.length; i++) {
            const index = i * 4;
            const rawIndex = i * 3;

            imageData.data[index] = image[rawIndex] * 255;
            imageData.data[index + 1] = image[rawIndex + 1] * 255;
            imageData.data[index + 2] = image[rawIndex + 2] * 255;
            imageData.data[index + 3] = 255;
        }

        this.context.putImageData(imageData, 0, 0);
    }

    async #setGlobalData() {
        let globalData = new Float32Array([
            this.canvas.width,
            this.canvas.height,

            this.opts.fov,

            this.opts.cameraPosition[0],
            this.opts.cameraPosition[1],
            this.opts.cameraPosition[2],
            
            this.opts.cameraRotation[0],
            this.opts.cameraRotation[1],
            this.opts.cameraRotation[2]
        ])

        this.device.queue.writeBuffer(this.#computeGlobalData, 0, globalData, 0, globalData.length);
    }

    async SetTriangles(triangleArray) {
        let oldSize = (this.#computeMapData || { size: 0 }).size
        let newSize = getNext2Power(triangleArray.length) * triangleStride

        let startIndex = 1;
        let totalSize = startIndex + newSize

        while (totalSize % 4 > 0) {
            totalSize++;
        }

        let triangleData = new Float32Array(totalSize);

        if (totalSize > oldSize) {
            this.#computeMapData = this.device.createBuffer({
                size: triangleData.length,
                usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST,
            });

            await this.#makeBindGroups()
        }

        triangleData[0] = triangleArray.length

        for (let triIndex = 0; triIndex < triangleArray.length; triIndex++) {

        }
    }

    SetFOV(newFOV){
        this.opts.fov = newFOV
    }

    SetCameraPosition(cameraPosition){
        this.opts.cameraPosition = cameraPosition
    }

    SetCameraRotation(cameraRotation){
        this.opts.cameraRotation = cameraRotation
    }

    async RenderFrame() {
        let changedData = false
        let currentData = JSON.stringify({
            fov: this.opts.fov
        })

        if (this.canvas.width !== this.#lastCanvasSize.width || this.canvas.height !== this.#lastCanvasSize.height) {
            this.#lastCanvasSize = { width: this.canvas.width, height: this.canvas.height }

            await this.#makeBindGroups()
            await this.#setGlobalData()
            changedData = true;
        }

        if(!changedData && this.#lastData !== currentData){
            this.#lastData = currentData

            await this.#setGlobalData()
        }

        let imageData = await this.#generateImage();
        await this.#renderImage(imageData);

        /*let imageData = await this.#generateImage();
        let denoisedImage = await this.#Denoiser.DenoiseImage(imageData)
        await this.#renderImage(denoisedImage);*/
    }

    async Init() {
        this.context = this.canvas.getContext('2d');
        this.adapter = await navigator.gpu.requestAdapter({ powerPreference: "high-performance" });
        if (!this.adapter) {
            throw Error("Couldn't request WebGPU adapter.");
        }

        this.device = await this.adapter.requestDevice({ label: "Browzium GPU Device" });
        this.presentationFormat = await navigator.gpu.getPreferredCanvasFormat();

        await this.SetTriangles([]);
        await this.#makeBindGroups();
        await this.#makePipelines();

        //await this.#Denoiser.Init()
    }
}

export default RenderingManager