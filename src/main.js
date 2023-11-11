import AudioManager from "./core/audio/main.js";
import RenderingManager from "./core/rendering/main.js";
import CameraModel from "./core/rendering/camera.js";

class Engine {
    Audio;
    Renderer;

    isActive;

    Camera = new CameraModel();

    constructor(opts = {}){
        opts = {
            audio: {

            },

            renderer: {
                shaders: {

                },
            },
            ...opts,
        }

        this.Audio = new AudioManager(opts.audio)
        this.Renderer = new RenderingManager(opts.renderer, this.Camera)
    }

    async InitActivation(){
        await this.Audio.Init()
        await this.Renderer.Init()
    }

    async RenderFrame(){
        let startTime = performance.now()

        await this.Renderer.RenderFrame()

        let delta = performance.now() - startTime
        
        return delta
    }

    async StepFrame(){
        let startTime = performance.now()
        


        let delta = performance.now() - startTime

        return delta
    }

    AwaitPageActivation(){
        return new Promise((resolve, reject) => {
            function onActivation(){
                resolve()

                document.removeEventListener("keydown", onActivation)
                document.removeEventListener("click", onActivation)
            }

            document.addEventListener('keydown', onActivation)
            document.addEventListener('click', onActivation)
        })
    }
}

export default Engine;

import Vector2 from "./core/classes/Vector2.js";
import Vector3 from "./core/classes/Vector3.js";
import Vector4 from "./core/classes/Vector4.js";
import Matrix from "./core/classes/Matrix.js";

import OBJParser from "./utilities/scene/OBJParser.js"

export { Vector2, Vector3, Vector4, Matrix, OBJParser }