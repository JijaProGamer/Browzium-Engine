import Triangle from "../../core/classes/Triangle.js";
import Vector4 from "../../core/classes/Vector4.js";
import Vector3 from "../../core/classes/Vector3.js";
import Vector2 from "../../core/classes/Vector2.js";
import Matrix from "../../core/classes/Matrix.js"

import { Material } from "../../core/classes/Material.js";

let domParser = new DOMParser();
function parseCollada(obj, textures = {}, options = {}) {
    options = {
        ...{
            inputFormat: "classic",
            objectIdentityMode: "perObject"
        }, ...options
    }

    const result = {
        triangles: [],
        cameras: {},
        materials: {},
        objects: {},
    }

    let xmlDoc = domParser.parseFromString(obj, "text/xml");
    console.log(xmlDoc, "wtf xml")

    let sceneObject = xmlDoc.getElementsByTagName("scene")[0];
    let visualSceneLink = sceneObject.getElementsByTagName("instance_visual_scene")[0].getAttribute("url");
    let visualScene = xmlDoc.getElementsByTagName("library_visual_scenes")[0].querySelector(visualSceneLink);

    let xmlMaterials = xmlDoc.getElementsByTagName("library_materials")[0]
    let xmlEffects = xmlDoc.getElementsByTagName("library_effects")[0];

    function loadMaterial(materialNode) {
        let name = materialNode.getAttribute("name");
        if (result.materials[name]) return;

        let effectParent = materialNode.getElementsByTagName("instance_effect")[0];
        let effectURL = effectParent.getAttribute("url");
        let effect = xmlEffects.querySelector(effectURL).getElementsByTagName("profile_COMMON")[0].getElementsByTagName("technique")[0]

        let lambertNode = effect.getElementsByTagName("lambert")[0]
        let material = new Material()

        if (lambertNode) {
            let emissionRaw = lambertNode.getElementsByTagName("emission")[0].getElementsByTagName("color")[0].textContent.split(" ").map(v => parseFloat(v));
            let diffuseRaw = lambertNode.getElementsByTagName("diffuse")[0].getElementsByTagName("color")[0].textContent.split(" ").map(v => parseFloat(v));

            let reflectivityRaw = lambertNode.getElementsByTagName("reflectivity")[0]
            let transparencyRaw = lambertNode.getElementsByTagName("transparent")[0]

            if (emissionRaw[0] > 0 || emissionRaw[1] > 0 || emissionRaw[2] > 0) {
                material.diffuse = new Vector3(emissionRaw[0], emissionRaw[1], emissionRaw[2]);
                material.emittance = 1
            } else {
                material.diffuse = new Vector3(diffuseRaw[0], diffuseRaw[1], diffuseRaw[2]);
            }

            if(reflectivityRaw){
                let specularRaw = reflectivityRaw.querySelector(`float[sid="specular"]`)

                material.reflectance = parseFloat(specularRaw.textContent)
            }

            if(transparencyRaw){
                transparencyRaw = transparencyRaw.getElementsByTagName("color")[0].textContent.split(" ")[3]

                material.transparency = 1 - parseFloat(transparencyRaw);
            }

            material.index_of_refraction = parseFloat(lambertNode.getElementsByTagName("index_of_refraction")[0].getElementsByTagName("float")[0].textContent)
        }

        result.materials[name] = material;
    }

    let xmlObjects = xmlDoc.getElementsByTagName("library_geometries")[0]
    let xmlCameras = xmlDoc.getElementsByTagName("library_cameras")[0]
    let xmlLights = xmlDoc.getElementsByTagName("library_lights")[0]
    let geometryIndex = 0;

    function loadObject(transformMatrix, geometry, materialName) {
        let normalTransformMatrix = transformMatrix.transpose()
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
            let vertice = new Vector4(verticesRaw[i], verticesRaw[i + 1], verticesRaw[i + 2], 1)
            vertice = transformMatrix.multiplyVector(vertice)

            vertices.push(new Vector3(vertice.x, vertice.y, vertice.z))
        }

        for (let i = 0; i < normalsRaw.length; i += 3) {
            let normal = new Vector4(normalsRaw[i], normalsRaw[i + 1], normalsRaw[i + 2], 0)
            normal = normalTransformMatrix.multiplyVector(normal)
            normal.normalize()

            normals.push(new Vector3(normal.x, normal.y, normal.z))
        }

        let inputTypes = trianglesNode.getElementsByTagName(`input`);

        // TODO:  Multiply the object rotation matrix by the normal

        if (inputTypes.length == 3) {
            for (let i = 0; i < indices.length; i += 3) {
                let vertexIndex = indices[i];
                let normalIndex = indices[i + 1];
                let uvIndex = indices[i + 2];

                tVertex.push({
                    position: vertices[vertexIndex],
                    normal: normals[normalIndex],
                    uv: new Vector2(0, 0)//textures[uvIndex],
                })
            }
        } else {
            for (let i = 0; i < indices.length; i += 2) {
                let vertexIndex = indices[i];
                let normalIndex = indices[i + 1];

                tVertex.push({
                    position: vertices[vertexIndex],
                    normal: normals[normalIndex],
                    uv: new Vector2(0, 0),
                })
            }
        }

        let triangles = []

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

            tri.material = materialName;

            let ab = tri.b.copy().subtract(tri.a);
            let ac = tri.c.copy().subtract(tri.a);

            tri.t = ab.cross(ac).normalize();

            tri.na = tri.t; // remove later
            tri.nb = tri.t; // remove later
            tri.nc = tri.t; // remove later

            tri.t.x = Math.round(tri.t.x)
            tri.t.y = Math.round(tri.t.y)
            tri.t.z = Math.round(tri.t.z)

            triangles.push(tri)

            switch (options.objectIdentityMode) {
                case "perObject":
                    tri.objectId = geometryIndex
                    break;
            }
        }

        result.triangles.push(...triangles)
        result.objects[name] = triangles;
        geometryIndex++;
    }

    function loadLight(transformMatrix, lightNode) {
        let name = lightNode.getAttribute("name");
        let pointData = lightNode.getElementsByTagName("technique_common")[0].getElementsByTagName("point")[0]

        let material = new Material()

        let emissionRaw = pointData.getElementsByTagName("color")[0].textContent.split(" ").map(v => parseFloat(v));
        material.diffuse = new Vector3(emissionRaw[0], emissionRaw[1], emissionRaw[2]);
        material.emittance = 1

        result.materials[name] = material;

        let lightExtra = lightNode.getElementsByTagName("extra")[0].getElementsByTagName("technique")[0]

        // currently only supports quad lights
        let spotSize = 1;//parseFloat(lightExtra.getElementsByTagName("spotsize")[0].textContent) / 2
        let squadSizeX = parseFloat(lightExtra.getElementsByTagName("area_size")[0].textContent) / 2
        let squadSizeY = parseFloat(lightExtra.getElementsByTagName("area_sizey")[0].textContent) / 2
        let squadSizeZ = parseFloat(lightExtra.getElementsByTagName("area_sizez")[0].textContent) / 2

        let ta = transformMatrix.multiplyVector(new Vector4(-1 * spotSize * squadSizeZ, 0, -1 * spotSize * squadSizeY, 1));
        let tb = transformMatrix.multiplyVector(new Vector4(1 * spotSize * squadSizeZ, 0, -1 * spotSize * squadSizeY, 1));
        let tc = transformMatrix.multiplyVector(new Vector4(-1 * spotSize * squadSizeZ, 0, 1 * spotSize * squadSizeY, 1));
        let td = transformMatrix.multiplyVector(new Vector4(1 * spotSize * squadSizeZ, 0, 1 * spotSize * squadSizeY, 1));

        /*let ta = transformMatrix.multiplyVector(new Vector4(-1 * spotSize * squadSizeX, -1 * spotSize * squadSizeZ, 0, 1));
        let tb = transformMatrix.multiplyVector(new Vector4(1 * spotSize * squadSizeX, -1 * spotSize * squadSizeZ, 0, 1));
        let tc = transformMatrix.multiplyVector(new Vector4(-1 * spotSize * squadSizeX, 1 * spotSize * squadSizeZ, 0, 1));
        let td = transformMatrix.multiplyVector(new Vector4(1 * spotSize * squadSizeX, 1 * spotSize * squadSizeZ, 0, 1));*/

        ta = new Vector3(ta.x, ta.y, ta.z);
        tb = new Vector3(tb.x, tb.y, tb.z);
        tc = new Vector3(tc.x, tc.y, tc.z);
        td = new Vector3(td.x, td.y, td.z);

        let tri1 = new Triangle()
        let tri2 = new Triangle()

        tri1.a = ta;
        tri1.b = tb;
        tri1.c = tc;

        tri2.a = tc;
        tri2.b = tb;
        tri2.c = td;

        let ab = tri1.b.copy().subtract(tri1.a);
        let ac = tri1.c.copy().subtract(tri1.a);

        tri1.t = ab.cross(ac).normalize();
        tri2.t = tri1.t;

        tri1.na = tri1.t;
        tri1.nb = tri1.t;
        tri1.nc = tri1.t;
        tri2.na = tri1.t;
        tri2.nb = tri1.t;
        tri2.nc = tri1.t;

        tri1.material = name;
        tri2.material = name;

        switch (options.objectIdentityMode) {
            case "perObject":
                tri1.objectId = geometryIndex
                tri2.objectId = geometryIndex
                break;
        }

        result.triangles.push(tri1, tri2)
        result.objects[name] = [tri1, tri2];
        geometryIndex ++;
    }

    function loadCamera(transformMatrix, cameraNode) {
        let name = cameraNode.getAttribute("name");
        let cameraOptics = cameraNode.getElementsByTagName("optics")[0].getElementsByTagName("technique_common")[0].getElementsByTagName("perspective")[0]
        let cameraExtra = cameraNode.getElementsByTagName("extra")[0].getElementsByTagName("technique")[0]

        result.cameras[name] = {
            transform: transformMatrix,
            fov: parseFloat(cameraOptics.querySelector(`xfov`).textContent),
            dof: {
                focalLength: parseFloat(cameraExtra.querySelector(`dof_distance`).textContent),
                apertureSize: new Vector2(parseFloat(cameraExtra.querySelector(`shiftx`).textContent), parseFloat(cameraExtra.querySelector(`shifty`).textContent)).length(),
            }
        }
    }

    let xmlSceneObjects = Array.from(visualScene.childNodes).filter(node => node.nodeType === 1)//.map(e => e = e.getElementsByTagName("mesh")[0]);

    for (let sceneObject of xmlSceneObjects) {
        let transformMatrixData = sceneObject.querySelector(`matrix[sid="transform"]`).textContent.split(" ").map(v => parseFloat(v))
        let transformMatrix = new Matrix(4, 4, transformMatrixData)

        let geometryInstance = sceneObject.getElementsByTagName("instance_geometry")[0]
        let cameraInstance = sceneObject.getElementsByTagName("instance_camera")[0]
        let lightInstance = sceneObject.getElementsByTagName("instance_light")[0]

        if (geometryInstance) {
            // is a object

            let materialInstance = geometryInstance.getElementsByTagName("bind_material")[0].getElementsByTagName("technique_common")[0].getElementsByTagName("instance_material")[0]

            let geometry = xmlObjects.querySelector(geometryInstance.getAttribute("url"))
            let material = xmlMaterials.querySelector(materialInstance.getAttribute("target"))
            let materialName = material.getAttribute("name");

            loadMaterial(material);
            loadObject(transformMatrix, geometry, materialName)
        } else if (cameraInstance) {
            // is a camera

            let camera = xmlCameras.querySelector(cameraInstance.getAttribute("url"))

            loadCamera(transformMatrix, camera);
        } else if (lightInstance) {
            // is a light

            let light = xmlLights.querySelector(lightInstance.getAttribute("url"))

            loadLight(transformMatrix, light);
        }
    }

    return result
}

export default parseCollada;
export { parseCollada };