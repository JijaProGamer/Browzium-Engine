//import Denoiser from "./denoiser.js"

import Vector3 from "../classes/Vector3";
import Octree from "../classes/octree";

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

/*
    Octree Branch struct:

    center: vec3<f32> - 4 * 4
    padding0: f32,

    halfSize: f32,
    children: array<f32, 8> - 4 * 8
    triangles: array<f32, 8> - 4 * 8

    padding1: f32,
    padding2: f32,
    padding3: f32
*/

let octreeBranchStride = 4 + 4 + 8 + 16;

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
    #computeMapBindGroup
    #computeImageBindGroup

    #computeDataLayout
    #computeMapLayout
    #computeImageLayout

    #renderTextureColor;
    #renderTextureReadColor;

    #temporalBuffer;
    #renderReadTexture;

    #computeGlobalData;
    #computeMapData;
    #computeMaterialData;
    #computeOctreeTreeData;

    // Camera

    #Camera

    // Denoiser

    //#Denoiser

    // Renderer Data

    antiAlias = true;
    gammaCorrect = true;
    frame = 0;

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

    #makeBindGroups() {
        /*
            Pixel:

            Noisy Image - 4 channels (r, g, b, w)
            Normal Image - 4 channels (r, g, b, w)
            Velocity Image - 4 channels (r, g, b, w)
        */

        /*
            Temportal Pixel

            Velocity - 4 channels (r, g, b, w)
        */

        // render textures

        let TextureSize = (this.canvas.width * this.canvas.height * 4) * 4;
        let ComputeSize = TextureSize * 3;
        let TemportalSize = TextureSize * 1;

        this.#renderTextureColor = this.device.createTexture({
            size: { width: this.canvas.width, height: this.canvas.height },
            format: 'rgba8unorm',
            usage: GPUTextureUsage.COPY_SRC | GPUTextureUsage.STORAGE_BINDING,
        });

        this.#renderTextureReadColor = this.device.createTexture({
            size: { width: this.canvas.width, height: this.canvas.height },
            format: 'rgba8unorm',
            usage: GPUTextureUsage.COPY_DST | GPUTextureUsage.TEXTURE_BINDING,
        });

        this.#temporalBuffer = this.device.createBuffer({
            size: TemportalSize,
            usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_SRC,
        });

        this.#renderReadTexture = this.device.createBuffer({
            size: ComputeSize,
            usage: GPUBufferUsage.MAP_READ | GPUBufferUsage.COPY_DST,
        });

        // Data

        this.#computeGlobalData = this.device.createBuffer({
            size: 116,
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

        this.#computeMapBindGroup = this.device.createBindGroup({
            layout: this.#computeMapLayout,
            label: "Browzium Engine compute shader map bind group",
            entries: [
                {
                    binding: 0,
                    resource: {
                        buffer: this.#computeMapData,
                    },
                },
                {
                    binding: 1,
                    resource: {
                        buffer: this.#computeMaterialData,
                    },
                },
                {
                    binding: 2,
                    resource: {
                        buffer: this.#computeOctreeTreeData,
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
                    resource: this.#renderTextureColor.createView(),
                },
                {
                    binding: 1,
                    resource: this.#renderTextureReadColor.createView(),
                },
                {
                    binding: 2,
                    resource: {
                        buffer: this.#temporalBuffer,
                    },
                }
            ],
        });
    }

    #makePipelines() {
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

        this.#computeMapLayout = this.device.createBindGroupLayout({
            entries: [
                {
                    binding: 0,
                    visibility: GPUShaderStage.COMPUTE,
                    buffer: {
                        type: "read-only-storage",
                    },
                },
                {
                    binding: 1,
                    visibility: GPUShaderStage.COMPUTE,
                    buffer: {
                        type: "read-only-storage",
                    }
                },
                {
                    binding: 2,
                    visibility: GPUShaderStage.COMPUTE,
                    buffer: {
                        type: "read-only-storage",
                    }
                }
            ],
        });


        this.#computeImageLayout = this.device.createBindGroupLayout({
            entries: [
                {
                    binding: 0,
                    visibility: GPUShaderStage.COMPUTE,
                    storageTexture: {
                        access: "write-only",
                        format: "rgba8unorm",
                        viewDimension: "2d",
                        multisampled: false,
                    }
                },
                {
                    binding: 1,
                    visibility: GPUShaderStage.FRAGMENT,
                    texture: {
                        format: "rgba8unorm",
                        viewDimension: "2d",
                        multisampled: false,
                    }
                },
                {
                    binding: 2,
                    visibility: GPUShaderStage.COMPUTE | GPUShaderStage.FRAGMENT,
                    buffer: {
                        type: "storage",
                    },
                }
            ],
        });

        let pipelineLayout = this.device.createPipelineLayout({
            bindGroupLayouts: [this.#computeDataLayout, this.#computeMapLayout, this.#computeImageLayout],
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
        passEncoder.setBindGroup(2, this.#computeImageBindGroup);

        passEncoder.dispatchWorkgroups(Math.ceil(this.canvas.width / 16), Math.ceil(this.canvas.height / 16), 1); //  Z for SPP
        passEncoder.end();

        this.device.queue.submit([commandEncoder.finish()]);
        await this.device.queue.onSubmittedWorkDone()

        // copy iamge

        const copyEncoder = this.device.createCommandEncoder();

        copyEncoder.copyTextureToTexture(
            {
                texture: this.#renderTextureColor,
            },
            {
                texture: this.#renderTextureReadColor,
            },
            {
                width: this.canvas.width,
                height: this.canvas.height,
                depthOrArrayLayers: 1,
            },
        );

        this.device.queue.submit([copyEncoder.finish()]);
    }

    async #readImage() {
        const copyCommandEncoder = this.device.createCommandEncoder();
        copyCommandEncoder.copyBufferToBuffer(this.#renderTextureColor, 0, this.#renderReadTexture, 0, this.#renderReadTexture.size);
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
                loadValue: { r: 0.0, g: 0, b: 0.0, a: 1.0 },
                loadOp: "clear",
                storeOp: 'store',
            }],
            label: "Browzium render pass"
        });

        passEncoder.setPipeline(this.renderPipeline);

        passEncoder.setBindGroup(0, this.#computeDataBindGroup);
        passEncoder.setBindGroup(1, this.#computeMapBindGroup);
        passEncoder.setBindGroup(2, this.#computeImageBindGroup);

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
            this.gammaCorrect,
            this.frame,
        ])

        this.#Camera.wasCameraUpdated = false;
        this.device.queue.writeBuffer(this.#computeGlobalData, 0, computeGlobalData, 0, computeGlobalData.length);
    }

    SetMaterials(materialList, dontUpdateBuffer) {
        this.#materials = materialList;

        let oldSize = (this.#computeMaterialData || { size: 0 }).size / 4
        let newSize = getNext2Power(Object.keys(materialList).length) * materialStride

        while (newSize % 4 > 0) {
            newSize++;
        }

        let materialData = new Float32Array(newSize);

        if (newSize > oldSize) {
            this.#computeMaterialData = this.device.createBuffer({
                size: materialData.byteLength,
                usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST,
            });

            if (!dontUpdateBuffer) {
                this.#makeBindGroups()
            }
        }

        let materialsKeys = Object.keys(materialList)
        for (let matIndex = 0; matIndex < materialsKeys.length; matIndex++) {
            let material = materialList[materialsKeys[matIndex]]
            let locationStart = materialStride * matIndex;

            // Color

            materialData[locationStart + 0] = material.diffuse.x;
            materialData[locationStart + 1] = material.diffuse.y;
            materialData[locationStart + 2] = material.diffuse.z;
            materialData[locationStart + 3] = 0;

            // Other stuff

            materialData[locationStart + 4] = material.transparency;
            materialData[locationStart + 5] = material.index_of_refraction;

            // Padding

            materialData[locationStart + 6] = material.reflectance;
            materialData[locationStart + 7] = 0;
        }

        this.device.queue.writeBuffer(this.#computeMaterialData, 0, materialData, 0, materialData.length);
    }

    #CreateOctree(triangleArray) {
        if (triangleArray.length == 0) {
            return [new Octree(new Vector3(0, 0, 0), 0, [])];
        }

        /*let octree = new Octree()
        let branches = []*/

        let octreeSize = Octree.calculateOctreeSize(triangleArray)
        let octree = new Octree(octreeSize.center, octreeSize.halfSize, triangleArray)

        let branches = []
        function getBranches(leaf) {
            branches.push(leaf)

            for (let childIndex = 0; childIndex < 8; childIndex++) {
                let child = leaf.children[childIndex]
                if (!child) {
                    return;
                }

                leaf.children[childIndex] = branches.length;
                getBranches(child)
            }
        }

        getBranches(octree)
        console.log(branches)

        return branches
    }

    #SetOctree(triangleArray, dontUpdateBuffer) {
        let octree = this.#CreateOctree(triangleArray)

        let oldSize = (this.#computeOctreeTreeData || { size: 0 }).size / 4
        let newSize = getNext2Power(octree.length) * octreeBranchStride

        let octreeData = new Float32Array(newSize);

        if (newSize > oldSize) {
            this.#computeOctreeTreeData = this.device.createBuffer({
                size: octreeData.byteLength,
                usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST,
            });

            if (!dontUpdateBuffer) {
                this.#makeBindGroups()
            }
        }

        for (let branchIndex = 0; branchIndex < octree.length; branchIndex++) {
            let octreeBranch = octree[branchIndex]
            let locationStart = octreeBranchStride * branchIndex;

            // Center

            octreeData[locationStart + 0] = octreeBranch.center.x;
            octreeData[locationStart + 1] = octreeBranch.center.y;
            octreeData[locationStart + 2] = octreeBranch.center.z;
            octreeData[locationStart + 3] = 0;

            // Half Size

            octreeData[locationStart + 4] = octreeBranch.halfSize;

            // Children

            for (let i = 0; i < 8; i++) {
                octreeData[locationStart + 5 + i] = isNaN(octreeBranch.children[i]) ? -1 : octreeBranch.children[i];
            }

            // Triangles

            for (let i = 0; i < 16; i++) {
                octreeData[locationStart + 5 + 16 + i] = isNaN(octreeBranch.objects[i]) ? -1 : octreeBranch.objects[i];
            }
        }

        this.device.queue.writeBuffer(this.#computeOctreeTreeData, 0, octreeData, 0, octreeData.length);
    }

    SetTriangles(triangleArray, updateOctree, dontUpdateBuffer) {
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
                this.#makeBindGroups()
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

        if (updateOctree) {
            this.#SetOctree(triangleArray)
        }
    }

    async RenderFrame(readImage) {
        this.frame ++;

        if (this.canvas.width !== this.#lastCanvasSize.width || this.canvas.height !== this.#lastCanvasSize.height) {
            this.#lastCanvasSize = { width: this.canvas.width, height: this.canvas.height }

            await this.#makeBindGroups()
            this.#Camera.wasCameraUpdated = true;
        }

        this.#UpdateData();

        await this.#generateImage();
        await this.#renderImage();

        if (readImage) {
            return { image: this.#readImage() }
        }
    }

    async Init() {
        this.context = this.canvas.getContext('webgpu');
        this.adapter = await navigator.gpu.requestAdapter({ powerPreference: "high-performance" });
        if (!this.adapter) {
            throw Error("Couldn't request WebGPU adapter.");
        }

        this.device = await this.adapter.requestDevice({ label: "Browzium GPU Device", requiredFeatures: [] });
        this.presentationFormat = await navigator.gpu.getPreferredCanvasFormat();

        await this.context.configure({
            device: this.device,
            format: this.presentationFormat,
            alphaMode: "opaque",
            usage: GPUTextureUsage.RENDER_ATTACHMENT
        })

        this.frame = 0;

        this.#SetOctree([], true);
        this.SetMaterials([], true);
        this.SetTriangles([], false, true);
        this.#makePipelines();
        this.#makeBindGroups();
        //this.#UpdateData();

        //await this.#Denoiser.Init()
    }
}

export default RenderingManager