import Vector3 from "../../core/classes/Vector3.js";
import Vector2 from "../../core/classes/Vector2.js";
import Material from "../../core/classes/Material.js";

function parseMAT(mat, textures) {
    const result = {};

    const lines = mat.split('\n');
    let lastMaterial;

    lines.forEach(line => {
        const parts = line.trim().split(/\s+/);
        const keyword = parts.shift();

        switch (keyword) {
            case 'newmtl':
                var name = parts[0]

                lastMaterial = name;
                result[name] = new Material();

                break;
            case 'Ka':
                result[lastMaterial].ambient = new Vector3(parseFloat(parts[0]), parseFloat(parts[1]), parseFloat(parts[2]))
                break;
            case 'Kd':
                result[lastMaterial].diffuse = new Vector3(parseFloat(parts[0]), parseFloat(parts[1]), parseFloat(parts[2]))
                break;
            case 'map_Kd':
                var name = parts.pop().split("/").pop();

                let texture = textures[name] 
                let resolution = texture && texture.resolution;

                if(!texture || !resolution){
                    throw new Error(`The material file includes the texture "${name}", but the file isnt provided in the "textures" table, or the texture has a incorrect format.`)
                }

                /*if(texture.bitmap.length !== (resolution[0] * resolution[1] * 4)){
                    throw new Error(`The material file includes the texture "${name}", but the texture's bitmap doesnt respect it's resolution.`)
                }*/
                
                result[lastMaterial].diffuseTexture.resolution = textures[name].resolution;
                result[lastMaterial].diffuseTexture.bitmap = textures[name].bitmap;

                break; 
            case 'Ks':
                result[lastMaterial].specular = new Vector3(parseFloat(parts[0]), parseFloat(parts[1]), parseFloat(parts[2]))
                break;
            case 'Ns':
                result[lastMaterial].specularWeight = parseFloat(parts[0])
                break;
            case 'Re':
                result[lastMaterial].reflectance = parseFloat(parts[0])
                break;
            case 'Rg':
                result[lastMaterial].roughtness = parseFloat(parts[0])
                break;
            case 'Tr':
                result[lastMaterial].transparency = parseFloat(parts[0])
                break;
            case 'd':
                result[lastMaterial].transparency = 1 - parseFloat(parts[0])
                break;
            case 'Ni':
                result[lastMaterial].index_of_refraction = parseFloat(parts[0])
                break;
            case "Em":
                result[lastMaterial].emittance = parseFloat(parts[0])
                break;
            case 'illum':
                result[lastMaterial].illumination_mode = parseFloat(parts[0])
                break;
            default:
                break;
        }
    });
    
    return result
}

export default parseMAT;
export { parseMAT };