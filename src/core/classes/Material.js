import Vector3 from "./Vector3.js";

class Material {
    ambient = new Vector3(0, 0, 0)
    diffuse = new Vector3(0, 0, 0)
    specular = new Vector3(0, 0, 0)
    
    specularWeight = 0.5
    transparency = 1
    index_of_refraction = 0
    illumination_mode = 0
}

export default Material;
export { Material }