class RenderingManager {
    opts;

    adapter;
    device;
    context;

    presentationFormat;

    renderPipeline;

    #vertexBuffer

    constructor(opts = {}) {
        if (!navigator.gpu) {
            throw Error("WebGPU not supported.");
        }

        if (!opts.canvas || !(opts.canvas instanceof HTMLCanvasElement)) {
            throw Error("Canvas should be a HTMLCanvasElement!")
        }

        this.canvas = opts.canvas;
        this.opts = opts;
    }

    async #generateImage(outputTexture) {
        const renderTexture = this.device.createTexture({
            size: { width: this.canvas.width, height: this.canvas.height },
            format: this.presentationFormat,
            usage: GPUTextureUsage.COPY_SRC | GPUTextureUsage.COPY_DST,
        });

       /*const data = new Float32Array(this.canvas.width * this.canvas.height * 3);

        for (let x = 0; x < this.canvas.width; x++) {
            for (let y = 0; y < this.canvas.height; y++) {
                let index = (x + y * this.canvas.width) * 3;

                data[index] = 0;
                data[index + 1] = 0;
                data[index + 2] = this.canvas.width / x;
            }
        }

        const transformedData = new Uint8Array(this.canvas.width * this.canvas.height * 4);

        for(let i = 0; i < data.length / 3; i ++){
            let index = i * 3;
            let newIndex = i * 4;

            if(this.presentationFormat == "rgba8unorm"){
                transformedData[newIndex] = data[index] * 255;
                transformedData[newIndex + 2] = data[index + 2] * 255;
            } else {
                transformedData[newIndex] = data[index + 2] * 255;
                transformedData[newIndex + 2] = data[index] * 255;
            }

            transformedData[newIndex + 1] = data[index + 1] * 255;
            transformedData[newIndex + 3] = 255;
        }*/

        const transformedData = new Uint8Array(this.canvas.width * this.canvas.height * 4);

        for (let x = 0; x < this.canvas.width; x++) {
            for (let y = 0; y < this.canvas.height; y++) {
                let index = 4 * (y * this.canvas.width + x);

                transformedData[index] = 0;
                transformedData[index + 1] = 0;
                transformedData[index + 2] = (this.canvas.width / x) * 255;
                transformedData[index + 3] = 1;
            }
        }

        this.device.queue.writeTexture({ texture: renderTexture }, transformedData,
            { bytesPerRow: 4 * this.canvas.width },
            { width: this.canvas.width, height: this.canvas.height }
        );

        const copyEncoder = this.device.createCommandEncoder();

        copyEncoder.copyTextureToTexture(
            {
                texture: renderTexture,
            },
            {
                texture: outputTexture,
            },
            {
                width: this.canvas.width,
                height: this.canvas.height,
                depthOrArrayLayers: 1,
            }
        );

        this.device.queue.submit([copyEncoder.finish()]);
    }

    async #renderImage() {
        const commandEncoder = this.device.createCommandEncoder();
        const currentTexture = this.context.getCurrentTexture();

        await this.#generateImage(currentTexture);

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
        passEncoder.draw(6, 2, 0, 0);
        passEncoder.end();

        this.device.queue.submit([commandEncoder.finish()]);
    }

    async RenderFrame() {
        await this.#renderImage();
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

        const vertexShader = this.device.createShaderModule({ code: this.opts.shaders.vertex, label: "Browzium vertex shader" });
        const fragmentShader = this.device.createShaderModule({ code: this.opts.shaders.fragment, label: "Browzium fragment shader" });

        this.renderPipeline = this.device.createRenderPipeline({
            layout: "auto",
            label: "Browzium Engine Render Pipeline",
            vertex: {
                module: vertexShader,
                entryPoint: 'main',
            },
            fragment: {
                module: fragmentShader,
                entryPoint: 'main',
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
}

export default RenderingManager