
import Vector3 from "../classes/Vector3";
import Vector2 from "../classes/Vector2";

import PathTracedRenderer from "./path_traced/renderer";
import RasterRenderer from "./raster/renderer";

let triangleStride = (3 * 4) + (3 * 4) + (2 * 4);
let materialStride = 4 + 4 + 4 + 4;

function getNext2Power(n) {
    return Math.pow(2, Math.ceil(Math.log2(n + 1)));
}

class RenderingManager {
    // globals

    opts;
    canvas;
    materials = [];
    triangles = [];
    lights = []

    #lastCanvasSize = {width: 0, height: 0}

    // raw gpu context

    adapter;
    device;
    context;

    presentationFormat;

    // Camera

    Camera

    // Renderer Data

    tonemapMode = 1;
    gammaCorrect = true;

    frame = 0;
    staticFrames = 0;

    focalLength = 0;
    apertureSize = 0;

    rendererType = "raster"
    renderer = null

    // Buffers

    computeLightData;
    computeMaterialData;

    // Texture Data

    textureAtlas;
    textureAtlasSampler;
    texturesContained;

    constructor(opts = {}, Camera) {
        if (!navigator.gpu) {
            throw Error("WebGPU not supported.");
        }

        if (!opts.canvas || !(opts.canvas instanceof HTMLCanvasElement)) {
            throw Error("Canvas should be a HTMLCanvasElement!")
        }

        this.canvas = opts.canvas;
        this.opts = opts;

        this.Camera = Camera
    }

    #computeAtlasFormat() {
        let maxSize = 4096;
        //let maxSize = this.device.limits.maxTextureDimension2D
        let maxDepth = this.device.limits.maxTextureArrayLayers

        let textures = [[]]

        for (let materialName of Object.keys(this.materials)) {
            let material = this.materials[materialName]
            if (material.diffuseTexture.bitmap.length == 0) { continue; }

            let start = new Vector3(0, 0, 0);
            let resolution = material.diffuseTexture.resolution;
            let spaceFound = false;

            for(let textureIndex = 0; textureIndex < textures.length; textureIndex += 1){
                let atlas = textures[textureIndex];

                for (let x = 0; x <= maxSize - resolution.x; x += 1) {
                    for (let y = 0; y <= maxSize - resolution.y; y += 1) {
                        let isSpaceFree = true;
    
                        for (let tex of atlas) {
                            if (x < tex.x + tex.width &&
                                x + resolution.x > tex.x &&
                                y < tex.y + tex.height &&
                                y + resolution.y > tex.y) {
                                isSpaceFree = false;
                                break;
                            }
                        }
    
                        if (isSpaceFree) {
                            start.x = x;
                            start.y = y;
                            start.z = textureIndex;

                            spaceFound = true;
                            break;
                        }
                    }
    
                    if (spaceFound) {
                        break;
                    }
                }
    
                if (spaceFound) {
                    break;
                }
            }

            if(!spaceFound){
                start.z = textures.length;
                textures[start.z].push([])
            }

            material.diffuseTexture.atlasInfo.depth = start.z;
            material.diffuseTexture.atlasInfo.start = new Vector2(start.x / maxSize, start.y / maxSize);
            material.diffuseTexture.atlasInfo.extend = new Vector2(resolution.x / maxSize, resolution.y / maxSize);

            if(start.z >= maxDepth){
                throw new Error("The texture atlas is overflowing. Please reduce your textures or the resolution of your textures")
            }

            textures[start.z].push({
                x: start.x,
                y: start.y,
                depth: start.z,
                width: resolution.x,
                height: resolution.y,
                bitmap: material.diffuseTexture.bitmap,
                material,
            })
        }

        this.texturesContained = textures
    }

    makeWorldTexture(resolution){
        this.worldTextureResolution = resolution;
        
        this.worldTexture = this.device.createTexture({
            dimension: "2d",
            format: "rgba16float", // might decrease later
            label: "Browzium Engine Texture Atlas",
            mipLevelCount: 1, // will increase later
            sampleCount: 1, // idk what this is
            size: { width: resolution.x, height: resolution.y, depthOrArrayLayers: 1 },
            usage: GPUTextureUsage.COPY_DST | GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.RENDER_ATTACHMENT,
        })

        this.worldTextureSampler = this.device.createSampler({
            addressModeU: "clamp-to-edge",
            addressModeV: "clamp-to-edge",
            addressModeW: "clamp-to-edge",
            label: "Browzium Engine Texture Atlas Sampler",

            magFilter: "linear", // Will be user costumizable
            minFilter: "linear", // Will be user costumizable
            mipmapFilter: "nearest", // Will be user costumizable
        })
    }

    applyWorldTexture(texture){
        if (
            texture instanceof ImageBitmap ||
            texture instanceof HTMLVideoElement ||
            texture instanceof VideoFrame ||
            texture instanceof HTMLCanvasElement ||
            texture instanceof OffscreenCanvas
        ) {
            this.device.queue.copyExternalImageToTexture(
                {
                    source: texture
                },
                {
                    mipLevel: 0,
                    texture: this.worldTexture
                },
                [
                    this.worldTextureResolution.x,
                    this.worldTextureResolution.y,
                    1                
                ]
            )
        } else {
            this.device.queue.writeTexture(
                {
                    mipLevel: 0,
                    texture: this.worldTexture
                },
                texture.data.buffer || texture.data,
                {
                    bytesPerRow: 4 * 2 * this.worldTextureResolution.x,
                    rowsPerImage: this.worldTextureResolution.y
                },
                [
                    this.worldTextureResolution.x,
                    this.worldTextureResolution.y,
                    1
                ]
            )
        }
    }

    #makeTextureAtlas() {
        //let limit2D = Math.floor(this.device.limits.maxTextureDimension2D / 2)
        //let limit3D = this.device.limits.maxTextureArrayLayers

        let limit2D = 4096

        this.textureAtlas = this.device.createTexture({
            dimension: "2d",
            format: "rgba16float", // might decrease later
            label: "Browzium Engine Texture Atlas",
            mipLevelCount: 1, // will increase later
            sampleCount: 1, // idk what this is
            size: { width: limit2D, height: limit2D, depthOrArrayLayers: Math.max(this.texturesContained.length, 2) },
            usage: GPUTextureUsage.COPY_DST | GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.RENDER_ATTACHMENT,
        })

        this.textureAtlasSampler = this.device.createSampler({
            addressModeU: "clamp-to-edge",
            addressModeV: "clamp-to-edge",
            addressModeW: "clamp-to-edge",
            label: "Browzium Engine Texture Atlas Sampler",

            magFilter: "linear", // Will be user costumizable
            minFilter: "linear", // Will be user costumizable
            mipmapFilter: "nearest", // Will be user costumizable
        })
    }

    #applyTextureAtlas() {
        for (let atlasDepthIndex = 0; atlasDepthIndex < this.texturesContained.length; atlasDepthIndex++) {
            let atlasDepth = this.texturesContained[atlasDepthIndex];

            for (let textureIndex = 0; textureIndex < atlasDepth.length; textureIndex++) {
                let texture = atlasDepth[textureIndex]

                if (
                    texture.bitmap instanceof ImageBitmap ||
                    texture.bitmap instanceof HTMLVideoElement ||
                    texture.bitmap instanceof VideoFrame ||
                    texture.bitmap instanceof HTMLCanvasElement ||
                    texture.bitmap instanceof OffscreenCanvas
                ) {
                    this.device.queue.copyExternalImageToTexture(
                        {
                            origin: [0, 0],
                            source: texture.bitmap
                        },
                        {
                            mipLevel: 0,
                            origin: [texture.x, texture.y],
                            texture: this.textureAtlas
                        },
                        [
                            texture.width,
                            texture.height,
                            atlasDepthIndex + 1
                        ]
                    )
                } else {
                    this.device.queue.writeTexture(
                        {
                            mipLevel: 0,
                            origin: [texture.x, texture.y],
                            texture: this.textureAtlas
                        },
                        texture.bitmap.buffer || texture.bitmap,
                        {
                            bytesPerRow: 4 * 2 * texture.width,
                            rowsPerImage: texture.height
                        },
                        [
                            texture.width,
                            texture.height,
                            atlasDepthIndex + 1
                        ]
                    )
                }
            }
        }
    }

    SetMaterials(materialList, updateBuffer) {
        this.materials = materialList;

        let oldSize = (this.computeMaterialData || { size: 0 }).size / 4
        let newSize = getNext2Power(Object.keys(this.materials).length) * materialStride

        while (newSize % 4 > 0) {
            newSize++;
        }

        let materialData = new Float32Array(newSize);

        if (newSize > oldSize) {
            this.computeMaterialData = this.device.createBuffer({
                size: materialData.byteLength,
                usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST,
            });

            if (updateBuffer) {
                this.renderer.internal__makeBindGroups()
            }
        }

        let materialsKeys = Object.keys(this.materials)
        for (let matIndex = 0; matIndex < materialsKeys.length; matIndex++) {
            let material = this.materials[materialsKeys[matIndex]]
            let locationStart = materialStride * matIndex;

            // Diffuse

            materialData[locationStart + 0] = material.diffuse.x;
            materialData[locationStart + 1] = material.diffuse.y;
            materialData[locationStart + 2] = material.diffuse.z;
            materialData[locationStart + 3] = material.diffuseTexture.atlasInfo.depth;

            // Specular

            materialData[locationStart + 4] = material.specular.x;
            materialData[locationStart + 5] = material.specular.y;
            materialData[locationStart + 6] = material.specular.z;
            materialData[locationStart + 7] = material.transparency;

            // UV Mapping

            materialData[locationStart + 8] = material.diffuseTexture.atlasInfo.start.x;
            materialData[locationStart + 9] = material.diffuseTexture.atlasInfo.start.y;
            materialData[locationStart + 10] = material.diffuseTexture.atlasInfo.extend.x;
            materialData[locationStart + 11] = material.diffuseTexture.atlasInfo.extend.y;

            // Other stuff

            materialData[locationStart + 12] = material.index_of_refraction;
            materialData[locationStart + 13] = material.reflectance;
            materialData[locationStart + 14] = material.emittance;
            materialData[locationStart + 15] = material.roughtness;
        }

        this.device.queue.writeBuffer(this.computeMaterialData, 0, materialData, 0, materialData.length);
    }

    #SetLights(triangleArray) {
        let lightTriangleArray = triangleArray.slice().filter(t => this.materials[t.material].emittance > 0);

        let oldSize = (this.computeLightData || { size: 0 }).size / 4
        let newSize = getNext2Power(lightTriangleArray.length)

        let totalSize = 1 + newSize

        while (totalSize % 4 > 0) {
            totalSize++;
        }

        let triangleData = new Float32Array(totalSize);

        if (totalSize > oldSize) {
            this.computeLightData = this.device.createBuffer({
                size: triangleData.byteLength,
                usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST,
            });
        }

        triangleData[0] = lightTriangleArray.length

        for (let triIndex = 0; triIndex < lightTriangleArray.length; triIndex++) {
            triangleData[triIndex + 1] = triangleArray.indexOf(lightTriangleArray[triIndex]);
        }

        this.device.queue.writeBuffer(this.computeLightData, 0, triangleData, 0, triangleData.length);
    }

    SetTriangles(triangleArray, updateTextures, updateBuffer, updateMaterials) {
        this.triangles = triangleArray;
        this.#SetLights(triangleArray);

        if (updateTextures) {
            this.#computeAtlasFormat(triangleArray)
            this.#makeTextureAtlas()
            this.#applyTextureAtlas()

            if(updateMaterials){
                this.SetMaterials(this.materials, true)
            }
        }


        let startIndex = 4;
        let updateBufferDown = false;

        let oldSize = (this.computeMapData || { size: 0 }).size / 4
        let newSize = getNext2Power(triangleArray.length) * triangleStride + startIndex

        let totalSize = startIndex + newSize

        while (totalSize % 4 > 0) {
            totalSize++;
        }

        let triangleData = new Float32Array(totalSize);

        if (totalSize > oldSize) {
            this.computeMapData = this.device.createBuffer({
                size: triangleData.byteLength,
                usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST,
            });

            if (updateBuffer) {
                updateBufferDown = true;
            }
        }

        triangleData[0] = triangleArray.length
        triangleData[1] = 0
        triangleData[2] = 0
        triangleData[3] = 0

        let materialsKeys = Object.keys(this.materials)
        for (let triIndex = 0; triIndex < triangleArray.length; triIndex++) {
            let triangle = triangleArray[triIndex]
            let locationStart = triangleStride * triIndex + startIndex;

            // Vertices

            triangleData[locationStart + 0] = triangle.a.x;
            triangleData[locationStart + 1] = triangle.a.y;
            triangleData[locationStart + 2] = triangle.a.z;
            triangleData[locationStart + 3] = materialsKeys.indexOf(triangle.material); // material index

            triangleData[locationStart + 4] = triangle.b.x;
            triangleData[locationStart + 5] = triangle.b.y;
            triangleData[locationStart + 6] = triangle.b.z;
            triangleData[locationStart + 7] = triangle.objectId; // object id

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

            // UVs

            triangleData[locationStart + 24] = triangle.uva.x;
            triangleData[locationStart + 25] = triangle.uva.y;
            triangleData[locationStart + 26] = triangle.uvb.x;
            triangleData[locationStart + 27] = triangle.uvb.y;

            triangleData[locationStart + 28] = triangle.uvc.x;
            triangleData[locationStart + 29] = triangle.uvc.y;
            triangleData[locationStart + 30] = 0;
            triangleData[locationStart + 31] = 0;
        }

        this.device.queue.writeBuffer(this.computeMapData, 0, triangleData, 0, triangleData.length);

        if(updateMaterials) this.renderer.SetTriangles(triangleArray, triangleData, updateBuffer)

        if (updateBufferDown) {
            this.renderer.internal__makeBindGroups()
        }
    }

    async RenderFrame(readImage) {
        this.frame++;
        this.staticFrames++;

        if (this.canvas.width !== this.#lastCanvasSize.width || this.canvas.height !== this.#lastCanvasSize.height) {
            this.#lastCanvasSize = { width: this.canvas.width, height: this.canvas.height }

            this.renderer.ResolutionChange()
        }

        if (this.Camera.wasCameraUpdated) {
            this.staticFrames = 0;
        }

        return await this.renderer.RenderFrame(readImage);
    }

    async SetRenderer(rendererType){
        if(!(rendererType == "raster" || rendererType == "path_traced")){
            throw new Error(`Render type ${rendererType} doesn't exist. Chose "raster" or "path_traced".`)
        }

        this.rendererType = rendererType

        switch(rendererType){
            case "path_traced": 
                this.renderer = new PathTracedRenderer(this);
                break;
            case "raster":
                this.renderer = new  RasterRenderer(this)
                break;
        }

        await this.renderer.Init()
    }

    async Init() {
        this.context = this.canvas.getContext('webgpu');
        this.adapter = await navigator.gpu.requestAdapter({ powerPreference: "high-performance" });
        if (!this.adapter) {
            throw Error("Couldn't request WebGPU adapter.");
        }

        if (!this.adapter.features.has("float32-filterable")) {
            throw new Error("Filterable 32-bit float textures support is not available");
        }

        this.device = await this.adapter.requestDevice({
            label: "Browzium GPU Device",
            requiredFeatures: [
                "float32-filterable"
            ],
            requiredLimits: {
                maxStorageTexturesPerShaderStage: 6,
            }
        });

        this.presentationFormat = navigator.gpu.getPreferredCanvasFormat();

        await this.context.configure({
            device: this.device,
            format: this.presentationFormat,
            alphaMode: "opaque",
            usage: GPUTextureUsage.RENDER_ATTACHMENT
        })

        this.frame = 0;
        this.staticFrames = 0;

        this.#computeAtlasFormat([])
        this.#makeTextureAtlas(1)

        this.makeWorldTexture(new Vector2(1, 1))

        this.SetTriangles([], true, false, false)
        this.SetMaterials([], false)

        //await this.SetRenderer("raster");
        await this.SetRenderer("path_traced");
    }
}

export default RenderingManager