import AudioManager from "./core/audio/main.js";

class Engine {
    AudioManager;

    isActive;

    constructor(opts = {}){
        opts = {...opts, 
            audio: {

            }
        }

        this.AudioManager = new AudioManager(opts.audio)
    }

    async InitActivation(){
        await this.AudioManager.Init()
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