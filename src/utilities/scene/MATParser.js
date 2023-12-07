import Vector3 from "../../core/classes/Vector3.js";
import Material from "../../core/classes/Material.js";

function parseMAT(mat) {
    const result = {};

    const lines = mat.split('\n');
    let lastMaterial;

    lines.forEach(line => {
        const parts = line.trim().split(/\s+/);
        const keyword = parts.shift();

        switch (keyword) {
            case 'newmtl':
                let name = parts[0]

                lastMaterial = name;
                result[name] = new Material();

                break;
            case 'Ka':
                result[lastMaterial].ambient = new Vector3(parseFloat(parts[0]), parseFloat(parts[1]), parseFloat(parts[2]))
                break;
            case 'Kd':
                result[lastMaterial].diffuse = new Vector3(parseFloat(parts[0]), parseFloat(parts[1]), parseFloat(parts[2]))
                break;
            case 'Ks':
                result[lastMaterial].specular = new Vector3(parseFloat(parts[0]), parseFloat(parts[1]), parseFloat(parts[2]))
                break;
            case 'Ns':
                result[lastMaterial].specularWeight = parseFloat(parts[0])
                break;
            case 'Kr':
                result[lastMaterial].reflectance = parseFloat(parts[0])
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