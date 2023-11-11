import Triangle from "../../core/classes/Triangle.js";
import Vector3 from "../../core/classes/Vector3.js";

function parseOBJ(obj) {
    const result = []

    const lines = obj.split('\n');
    const instructions = []

    lines.forEach(line => {
        const parts = line.trim().split(/\s+/);
        const keyword = parts[0];

        switch (keyword) {
            case 'v':
                const vertex = new Vector3(parseFloat(parts[1]), parseFloat(parts[2]), parseFloat(parts[3]));
                instructions.push({ type: "vertex", data: vertex })
                break;
            case 'vn':
                const normal = new Vector3(parseFloat(parts[1]), parseFloat(parts[2]), parseFloat(parts[3]));
                instructions.push({ type: "normal", data: normal })
                break;
            case 'f':
                const faceVertices = [];
                const faceTextures = [];
                const faceNormals = [];

                for (let i = 1; i < parts.length; i++) {
                    const indices = parts[i].split('/');
                    let vertexIndice = parseInt(indices[0]);
                    let textureIndice = parseInt(indices[1]);
                    let normalIndice = parseInt(indices[2]);

                    if(vertexIndice < 0){
                        let indicesLeft = -vertexIndice
                        for(let currentIndex = instructions.length - 1; currentIndex >= 0; currentIndex--){
                            if(instructions[currentIndex].type == "vertex"){
                                indicesLeft -= 1;
                            }

                            if(indicesLeft == 0){
                                faceVertices.push(instructions[currentIndex].data);

                                break
                            }
                        }
                    } else {
                        let indicesLeft = vertexIndice

                        for(let currentIndex = 0; currentIndex < instructions.length; currentInde++){
                            if(instructions[currentIndex].type == "vertex"){
                                indicesLeft -= 1;
                            }

                            if(indicesLeft == 0){
                                faceVertices.push(instructions[currentIndex].data);

                                break
                            }
                        }
                    }
                }

                for(let triIndex = 0; triIndex < faceVertices.length - 2; triIndex += 1){
                    const triangle = new Triangle();

                    triangle.a = faceVertices[triIndex + 0];
                    triangle.b = faceVertices[triIndex + 1];
                    triangle.c = faceVertices[triIndex + 2];

                    triangle.na = faceNormals[triIndex + 0];
                    triangle.nb = faceNormals[triIndex + 1];
                    triangle.nc = faceNormals[triIndex + 2];

                    if(!triangle.na || !triangle.nb || !triangle.nc){
                        let ab = triangle.b.subtract(triangle.a)
                        let ac = triangle.c.subtract(triangle.a)
                        let normal = ab.cross(ac).normalize()

                        triangle.na = normal;
                        triangle.nb = normal;
                        triangle.nc = normal;
                    }

                    result.push(triangle);
                }
                break;
            default:
                break;
        }
    });

    console.log(result)
    
    return result
}

export default parseOBJ;
export { parseOBJ };