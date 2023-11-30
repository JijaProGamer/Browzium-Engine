import Vector3 from "./Vector3.js";

function updateMinMax(min, max, point) {
    min.x = Math.min(min.x, point.x);
    min.y = Math.min(min.y, point.y);
    min.z = Math.min(min.z, point.z);

    max.x = Math.max(max.x, point.x);
    max.y = Math.max(max.y, point.y);
    max.z = Math.max(max.z, point.z);
}

class Octree {
    constructor(center, halfSize, triangleArray) {
        this.center = center;
        this.halfSize = halfSize;

        this.children = [];
        this.objects = [];

        for(let triangleIndex = 0; triangleIndex < triangleArray.length; triangleIndex++){
            let triangle = triangleArray[triangleIndex];

            if(this.triangleIntersectsLeaf(triangle)){
                this.objects.push(triangleIndex)

                if(this.objects.length > 16){
                    this.objects = []
                    this.subdivide(triangleArray);
    
                    break;
                }
            }
        }
    }

    subdivide(triangleArray) {
        const newHalfSize = this.halfSize / 2;

        const newCenters = [
            this.center.copy().add({ x: -newHalfSize, y: -newHalfSize, z: -newHalfSize }),
            this.center.copy().add({ x: newHalfSize, y: -newHalfSize, z: -newHalfSize }),
            this.center.copy().add({ x: -newHalfSize, y: newHalfSize, z: -newHalfSize }),
            this.center.copy().add({ x: newHalfSize, y: newHalfSize, z: -newHalfSize }),
            this.center.copy().add({ x: -newHalfSize, y: -newHalfSize, z: newHalfSize }),
            this.center.copy().add({ x: newHalfSize, y: -newHalfSize, z: newHalfSize }),
            this.center.copy().add({ x: -newHalfSize, y: newHalfSize, z: newHalfSize }),
            this.center.copy().add({ x: newHalfSize, y: newHalfSize, z: newHalfSize }),
        ];

        for (let i = 0; i < 8; i++) {
            this.children[i] = new Octree(newCenters[i], newHalfSize, triangleArray);
        }
    }

    triangleIntersectsLeaf(triangle) {
        return (
            this.pointInsideLeaf(triangle.a) ||
            this.pointInsideLeaf(triangle.b) ||
            this.pointInsideLeaf(triangle.c)
        );
    }
    
    pointInsideLeaf(point) {
        return (
            point.x >= this.center.x - this.halfSize &&
            point.x <= this.center.x + this.halfSize &&
            point.y >= this.center.y - this.halfSize &&
            point.y <= this.center.y + this.halfSize &&
            point.z >= this.center.z - this.halfSize &&
            point.z <= this.center.z + this.halfSize
        );
    }

    static calculateOctreeSize(triangleArray){
        let minPosition = new Vector3(triangleArray[0].a.x, triangleArray[0].a.y, triangleArray[0].a.z);
        let maxPosition = new Vector3(triangleArray[0].a.x, triangleArray[0].a.y, triangleArray[0].a.z);
    
        for (const triangle of triangleArray) {
            updateMinMax(minPosition, maxPosition, triangle.a);
            updateMinMax(minPosition, maxPosition, triangle.b);
            updateMinMax(minPosition, maxPosition, triangle.c);
        }
    
        const center = new Vector3(
            (minPosition.x + maxPosition.x) / 2,
            (minPosition.y + maxPosition.y) / 2,
            (minPosition.z + maxPosition.z) / 2
        );
    
        const halfSize = Math.max(
            (maxPosition.x - minPosition.x) / 2,
            (maxPosition.y - minPosition.y) / 2,
            (maxPosition.z - minPosition.z) / 2
        );

        return {center, halfSize}
    }
}

export default Octree;
export { Octree }