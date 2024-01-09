import Triangle from "../../core/classes/Triangle.js";
import Vector3 from "../../core/classes/Vector3.js";
import Vector2 from "../../core/classes/Vector2.js";

import { Material } from "../../core/classes/Material.js";

let domParser = new DOMParser();
function parseCollada(obj, textures={}, options={}) {
    options = {...{
        objectIdentityMode: "perObject"
    }, ...options}

    const result = {
        triangles: [],
        materials: {},
        objects: {},
    }

    let xmlDoc = domParser.parseFromString(obj, "text/xml");
    console.log(xmlDoc, "wtf xml")

    //let xmlMaterials = Array.from(xmlDoc.getElementsByTagName("library_materials")[0].childNodes).filter(node => node.nodeType === 1);
    //console.log(xmlMaterials, 'lol sugi')

    let xmlMaterials = Array.from(xmlDoc.getElementsByTagName("library_materials")[0].childNodes).filter(node => node.nodeType === 1)//.map(e => e = e.getElementsByTagName("mesh")[0]);
    let xmlEffects = xmlDoc.getElementsByTagName("library_effects")[0];

    for(let [materialIndex, material] of xmlMaterials.entries()){
        let name = material.getAttribute("name");

        let effectParent = material.getElementsByTagName("instance_effect")[0];
        let effectURL = effectParent.getAttribute("url");
        let effect = xmlEffects.querySelector(effectURL).getElementsByTagName("profile_COMMON")[0].getElementsByTagName("technique")[0]

        let lambert = effect.getElementsByTagName("lambert")[0]

        if(lambert){
            let emissionRaw = lambert.getElementsByTagName("emission")[0].getElementsByTagName("color")[0].textContent.split(" ").map(v => parseFloat(v));
            let emission = new Vector3(emissionRaw[0], emissionRaw[1], emissionRaw[2]);
         
            let diffuseRaw = lambert.getElementsByTagName("diffuse")[0].getElementsByTagName("color")[0].textContent.split(" ").map(v => parseFloat(v));
            let diffuse = new Vector3(diffuseRaw[0], diffuseRaw[1], diffuseRaw[2]);
            let transparency = 1 - diffuseRaw[3];

            let indexOfRefraction = parseFloat(lambert.getElementsByTagName("index_of_refraction")[0].getElementsByTagName("float")[0].textContent)

            console.log("plm", emission, diffuse, transparency, indexOfRefraction)
        }
    }

    let xmlObjects = Array.from(xmlDoc.getElementsByTagName("library_geometries")[0].childNodes).filter(node => node.nodeType === 1)//.map(e => e = e.getElementsByTagName("mesh")[0]);
    
    for(let [geometryIndex, geometry] of xmlObjects.entries()){
        let name = geometry.getAttribute("name");

        let trianglesNode = geometry.getElementsByTagName("triangles")[0];
        let vertexIndex = trianglesNode.querySelector(`input[semantic="VERTEX"]`).getAttribute("source")
        let normalIndex = trianglesNode.querySelector(`input[semantic="NORMAL"]`).getAttribute("source")

        let vertexList = geometry.querySelector(vertexIndex)
        let positionList = vertexList.querySelector(`input[semantic="POSITION"]`).getAttribute("source");
        positionList = geometry.querySelector(positionList)
        let normalList = geometry.querySelector(normalIndex)

        let verticesRaw = positionList.getElementsByTagName("float_array")[0].textContent.split(" ").map(v => parseFloat(v))
        let normalsRaw = normalList.getElementsByTagName("float_array")[0].textContent.split(" ").map(v => parseFloat(v))

        let indices = trianglesNode.querySelector(`p`).textContent.split(" ").map(v => parseInt(v))

        let vertices = []
        let normals = []
        let uvs = []
        let tVertex = []

        for(let i = 0; i < verticesRaw.length; i += 3 ){
            vertices.push(new Vector3(verticesRaw[i], verticesRaw[i + 1], verticesRaw[i + 2]))
        }

        for(let i = 0; i < normalsRaw.length; i += 3 ){
            normals.push(new Vector3(normalsRaw[i], normalsRaw[i + 1], normalsRaw[i + 2]))
        }

        for(let i = 0; i < indices.length; i += 3 ){
            let vertexIndex = indices[i];
            let normalIndex = indices[i + 1];
            let uvIndex = indices[i + 2];
            
            tVertex.push({
                position: vertices[vertexIndex],
                normal: normals[normalIndex],
                uv: new Vector2(0, 0)//textures[textureIndex],
            })
        }

        let triangles = []

        for(let i = 0; i < tVertex.length; i += 3 ){
            let tri = new Triangle()

            let ta = tVertex[i];
            let tb = tVertex[i + 1];
            let tc = tVertex[i + 2];

            tri.a = ta.position;
            tri.b = tb.position;
            tri.c = tc.position;

            tri.na = ta.normal;
            tri.nb = tb.normal;
            tri.nc = tc.normal;

            tri.uva = ta.uv;
            tri.uvb = tb.uv;
            tri.uvc = tc.uv;

            let ab = tri.b.copy().subtract(tri.a);
            let ac = tri.c.copy().subtract(tri.a);

            tri.t = ab.cross(ac).normalize();

            triangles.push(tri)
        
            switch(options.objectIdentityMode){
                case "perObject":
                    tri.objectId = geometryIndex
                    break;
            }
        }
        
        result.triangles.push(...triangles)
        result.objects[name] = triangles;

        console.log(geometry, triangles, "geometry")
    }

    /*const lines = obj.split('\n');

    let normals = []
    let textureUVs = []
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
                    throw new Error(`The OBJ file includes the material "${name}", but the file isnt provided in the "materialsCode" table.`)
                }
                
                result.materials = {...result.materials, ...parseMAT(materialsCode[name], textures)}
                break;
            case 'usemtl':
                var name = parts.pop()
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
                    faceTextures.push(textureUVs.at(textureIndice));
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

                    let ab = triangle.b.copy().subtract(triangle.a);
                    let ac = triangle.c.copy().subtract(triangle.a);
                    let tangent = ab.cross(ac).normalize();
                
                    if (!triangle.na || !triangle.nb || !triangle.nc) {
                        triangle.na = tangent;
                        triangle.nb = tangent;
                        triangle.nc = tangent;
                    }

                    triangle.t = tangent;
                
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
    }*/
    
    return result
}

export default parseCollada;
export { parseCollada };