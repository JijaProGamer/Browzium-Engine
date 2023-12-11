import Triangle from "../../core/classes/Triangle.js";
import Vector3 from "../../core/classes/Vector3.js";
import { Material } from "../../core/classes/Material.js";

import { parseMAT } from "./MATParser.js";

function parseOBJ(obj, materialsCode=[], options={}) {
    options = {...{
        objectIdentityMode: "perFace"
    }, ...options}
    const result = {
        triangles: [],
        materials: {},
        objects: {},
    }

    const lines = obj.split('\n');

    let normals = []
    let textures = []
    let vertices = []
    let lastMaterial = "default"
    let lastObject = ""
    let lastObjectId = -1

    lines.forEach(line => {
        const parts = line.trim().split(/\s+/);
        const keyword = parts.shift();

        switch (keyword) {
            case "o":
                if(options.objectIdentityMode == "perObject"){
                    lastObjectId++;  
                }

                lastObject = parts[0]
                result.objects[lastObject] = []
                break;
            case 'v':
                var vertex = new Vector3(parseFloat(parts[0]), parseFloat(parts[1]), parseFloat(parts[2]));
                vertices.push(vertex)
                break;
            case 'vn':
                const normal = new Vector3(parseFloat(parts[0]), parseFloat(parts[1]), parseFloat(parts[2]));
                normals.push(normal)
                break;
            case 'vp':
                var vertex = new Vector3(parseFloat(parts[0]), parseFloat(parts[1]), parseFloat(parts[2]));
                vertices.push(vertex)
                break;
            case 'mtllib':
                var name = parts[0].split("/").pop().split("\\").pop().split(".mtl")[0]
                if(!materialsCode[name]){
                    throw new Error(`The OBJ file includes the material "${name}", but the file isnt provided in the "materialsCode" tab.`)
                }
                
                result.materials = {...result.materials, ...parseMAT(materialsCode[name])}
                break;
            case 'usemtl':
                var name = parts[0]
                if(!result.materials[name]){
                    throw new Error(`The OBJ file wants to use material "${name}" that hasn't been declared`)
                }

                lastMaterial = name
                
                break;
            case 'f':
                if(options.objectIdentityMode == "perFace"){
                    lastObjectId++;  
                }

                const faceVertices = [];
                const faceTextures = [];
                const faceNormals = [];

                for (let i = 0; i < parts.length; i++) {
                    const indices = parts[i].split('/');
                    let vertexIndice = parseInt(indices[0]);
                    let textureIndice = parseInt(indices[1]);
                    let normalIndice = parseInt(indices[2]);

                    if(vertexIndice > 0) vertexIndice -= 1;
                    if(textureIndice > 0) textureIndice -= 1;
                    if(normalIndice > 0) normalIndice -= 1;

                    faceVertices.push(vertices.at(vertexIndice));
                    faceTextures.push(textures.at(textureIndice));
                    faceNormals.push(normals.at(normalIndice));
                }

                for (let triIndex = 0; triIndex < faceVertices.length - 2; triIndex++) {
                    const triangle = new Triangle();
                
                    triangle.a = faceVertices[0];
                    triangle.b = faceVertices[triIndex + 1];
                    triangle.c = faceVertices[triIndex + 2];
                
                    triangle.na = faceNormals[0];
                    triangle.nb = faceNormals[triIndex + 1];
                    triangle.nc = faceNormals[triIndex + 2];

                    triangle.material = lastMaterial;
                    triangle.objectId = lastObjectId;
                
                    if (!triangle.na || !triangle.nb || !triangle.nc) {
                        let ab = triangle.b.copy().subtract(triangle.a);
                        let ac = triangle.c.copy().subtract(triangle.a);
                        let normal = ab.cross(ac).normalize();
                
                        triangle.na = normal;
                        triangle.nb = normal;
                        triangle.nc = normal;
                    }
                
                    result.triangles.push(triangle);
                    if(lastObject) result.objects[lastObject].push(result.triangles.length - 1)
                }
                break;
            default:
                break;
        }
    });

    if(!result.materials.default){
        result.materials.default = new Material()
    }
    
    return result
}

export default parseOBJ;
export { parseOBJ };