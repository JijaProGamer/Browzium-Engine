class AudioManager {
    audioContext;

    constructor(opts = {}) {

    }

    async Init() {
        this.audioContext = new (AudioContext || webkitAudioContext)()
    }

    CreateAudioBuffer(numSamples, numChannels = 1){
        if(typeof(numChannels) == "string"){
            numChannels = numChannels.split(".").reduce((a, b) => a + parseInt(b), 0)
        }

        return this.audioContext.createBuffer(numChannels, numSamples, this.audioContext.sampleRate);
    }

    PlaySoundInSpace(){

    }

    PlaySound(audioBuffer, opts={}) {
        opts = {
            position: [0, 0, 0], 
            lookDirection: [0, 0, 0],

            innerCone: 60,
            outerCone: 90,
        }

        const panner = this.audioContext.createPanner();
        const source = this.audioContext.createBufferSource();
        source.buffer = audioBuffer;

        panner.setPosition(opts.position[0], opts.position[1], opts.position[2]);
        panner.setOrientation(opts.lookDirection[0], opts.lookDirection[1], opts.lookDirection[2]);

        panner.coneInnerAngle = opts.innerCone;
        panner.coneOuterAngle = opts.outerCone;

        panner.distanceMode = "linear"
        panner.panningModel = "HRTF"

        source.connect(panner);
        panner.connect(this.audioContext.destination);

        source.start();

        source.onended = () => {
            source.stop();
            source.disconnect();
            panner.disconnect();
            source.onended = null;
        };

        return { panner, source }
    }
}

export default AudioManager