import Vector3 from "./Vector3.js";
import Vector2 from "./Vector2.js"

class Material {
    ambient = new Vector3(0, 0, 0)
    diffuse = new Vector3(0, 0, 0)
    specular = new Vector3(0, 0, 0)
    
    specularWeight = 0.5
    transparency = 0
    index_of_refraction = 0
    illumination_mode = 0
    reflectance = 0
    roughtness = 0
    emittance = 0

    diffuseTexture = {
        resolution: new Vector2(0, 0),
        bitmap: [],

        atlasInfo: {
            depth: -1,
            start: new Vector2(0, 0),
            extend: new Vector2(0, 0)
        },
    }
}

export default Material;
export { Material }