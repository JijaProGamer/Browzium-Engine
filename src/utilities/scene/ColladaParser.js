import Triangle from "../../core/classes/Triangle.js";
import Vector3 from "../../core/classes/Vector3.js";
import Vector2 from "../../core/classes/Vector2.js";

import { Material } from "../../core/classes/Material.js";

let domParser = new DOMParser();
function parseCollada(obj, textures = {}, options = {}) {
    options = {
        ...{
            objectIdentityMode: "perObject"
        }, ...options
    }

    const result = {
        triangles: [],
        materials: {},
        objects: {},
    }

    let xmlDoc = domParser.parseFromString(obj, "text/xml");
    console.log(xmlDoc, "wtf xml")

    let sceneObject = xmlDoc.getElementsByTagName("scene")[0];
    let visualSceneLink = sceneObject.getElementsByTagName("instance_visual_scene")[0].getAttribute("url");
    let visualScene = xmlDoc.getElementsByTagName("library_visual_scenes")[0].querySelector(visualSceneLink);



    let xmlMaterials = Array.from(xmlDoc.getElementsByTagName("library_materials")[0].childNodes).filter(node => node.nodeType === 1)//.map(e => e = e.getElementsByTagName("mesh")[0]);
    let xmlEffects = xmlDoc.getElementsByTagName("library_effects")[0];

    for (let [materialIndex, materialNode] of xmlMaterials.entries()) {
        let name = materialNode.getAttribute("name");

        let effectParent = materialNode.getElementsByTagName("instance_effect")[0];
        let effectURL = effectParent.getAttribute("url");
        let effect = xmlEffects.querySelector(effectURL).getElementsByTagName("profile_COMMON")[0].getElementsByTagName("technique")[0]

        let lambertNode = effect.getElementsByTagName("lambert")[0]
        let material = new Material()

        if (lambertNode) {
            let emissionRaw = lambertNode.getElementsByTagName("emission")[0].getElementsByTagName("color")[0].textContent.split(" ").map(v => parseFloat(v));
            let diffuseRaw = lambertNode.getElementsByTagName("diffuse")[0].getElementsByTagName("color")[0].textContent.split(" ").map(v => parseFloat(v));

            if (emissionRaw[0] > 0 || emissionRaw[1] > 0 || emissionRaw[2] > 0) {
                material.diffuse = new Vector3(emissionRaw[0], emissionRaw[1], emissionRaw[2]);
                material.emittance = 1
            } else {
                material.diffuse = new Vector3(diffuseRaw[0], diffuseRaw[1], diffuseRaw[2]);
            }

            material.transparency = 1 - diffuseRaw[3];
            material.index_of_refraction = parseFloat(lambertNode.getElementsByTagName("index_of_refraction")[0].getElementsByTagName("float")[0].textContent)
        }

        result.materials[name] = material;
    }

    let xmlObjects = Array.from(xmlDoc.getElementsByTagName("library_geometries")[0].childNodes).filter(node => node.nodeType === 1)//.map(e => e = e.getElementsByTagName("mesh")[0]);

    for (let [geometryIndex, geometry] of xmlObjects.entries()) {
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

        for (let i = 0; i < verticesRaw.length; i += 3) {
            vertices.push(new Vector3(verticesRaw[i], verticesRaw[i + 1], verticesRaw[i + 2]))
        }

        for (let i = 0; i < normalsRaw.length; i += 3) {
            normals.push(new Vector3(normalsRaw[i], normalsRaw[i + 1], normalsRaw[i + 2]))
        }

        for (let i = 0; i < indices.length; i += 3) {
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

        try {
            for (let i = 0; i < tVertex.length; i += 3) {
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

                switch (options.objectIdentityMode) {
                    case "perObject":
                        tri.objectId = geometryIndex
                        break;
                }
            }
        } catch (err) { console.log(err) }

        result.triangles.push(...triangles)
        result.objects[name] = triangles;
    }

    console.log(result);

    return result
}

export default parseCollada;
export { parseCollada };