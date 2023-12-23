import Vector3 from "./Vector3.js";

function updateMinMax(min, max, point) {
    min.x = Math.min(min.x, point.x);
    min.y = Math.min(min.y, point.y);
    min.z = Math.min(min.z, point.z);

    max.x = Math.max(max.x, point.x);
    max.y = Math.max(max.y, point.y);
    max.z = Math.max(max.z, point.z);
}

function calculateSurfaceArea(min, max) {
    const width = max.x - min.x;
    const height = max.y - min.y;
    const depth = max.z - min.z;
    return 2 * (width * height + height * depth + depth * width);
}

class BVHTree {
    minPosition;
    maxPosition;

    child1;
    child2;

    objects = [];
    triangleArray;

    constructor(minPosition, maxPosition, triangleArray) {
        this.minPosition = minPosition;
        this.maxPosition = maxPosition;
        this.triangleArray = triangleArray;

        for (let triangleIndex = 0; triangleIndex < triangleArray.length; triangleIndex++) {
            let triangle = triangleArray[triangleIndex];

            if (BVHTree.triangleIntersectsLeaf(triangle, minPosition, maxPosition)) {
                this.objects.push(triangleIndex)

                if (this.objects.length > 8) {
                    this.objects = []
                    this.subdivide(triangleArray);

                    break;
                }
            }
        }
    }

    subdivide(triangleArray) {
        /*const size = Vector3.subtract(this.maxPosition, this.minPosition).multiplyScalar(1/2);
        const splitAxis = Math.abs(size.x) > Math.abs(size.y) ? (Math.abs(size.x) > Math.abs(size.z) ? 'x' : 'z') : (Math.abs(size.y) > Math.abs(size.z) ? 'y' : 'z');
        const splitPosition = Vector3.add(this.minPosition, new Vector3(size.x * (splitAxis == "x"), size.y * (splitAxis == "y"), size.z * (splitAxis == "z")))

        const minPositionChild1 = this.minPosition.copy();
        const maxPositionChild1 = splitPosition;
    
        const minPositionChild2 = splitPosition;
        const maxPositionChild2 = this.maxPosition.copy();

        const trianglesChild1 = [];
        const trianglesChild2 = [];

        for (let triangleIndex = 0; triangleIndex < triangleArray.length; triangleIndex++) {
            let triangle = triangleArray[triangleIndex];

            if (BVHTree.triangleIntersectsLeaf(triangle, minPositionChild1, maxPositionChild1)) {
                trianglesChild1.push(triangle)
            }

            if (BVHTree.triangleIntersectsLeaf(triangle, minPositionChild2, maxPositionChild2)) {
                trianglesChild2.push(triangle)
            }
        }
    
        this.child1 = new BVHTree(minPositionChild1, maxPositionChild1, trianglesChild1);
        this.child2 = new BVHTree(minPositionChild2, maxPositionChild2, trianglesChild2);*/

        console.log(this.calculateDivisionSAH(0, 0.35))
    }

    calculateDivisionSAH(axis, distance){
        let distancePosition = Vector3.subtract(this.maxPosition, this.minPosition).multiplyScalar(distance);
        let splitPosition = Vector3.add(this.minPosition, new Vector3(distancePosition.x * (axis == 0), distancePosition.y * (axis == 1), distancePosition.z * (axis == 2)))

        let child1 = {
            minPosition: this.minPosition,
            maxPosition: splitPosition,
            children: []
        }

        let child2 = {
            minPosition: splitPosition,
            maxPosition: this.maxPosition,
            children: []
        }

        for (let triangleIndex = 0; triangleIndex < this.triangleArray.length; triangleIndex++) {
            let triangle = this.triangleArray[triangleIndex];

            if (BVHTree.triangleIntersectsLeaf(triangle, child1.minPosition, child1.maxPosition)) {
                child1.children.push(triangle)
            }

            if (BVHTree.triangleIntersectsLeaf(triangle, child2.minPosition, child2.maxPosition)) {
                child2.children.push(triangle)
            }
        }

        return BVHTree.SAH(1, 2, child1, child2, this);
    }

    SAH(tTraversal, tIntersect, child1, child2){
        const sA = calculateSurfaceArea(child1.minPosition, child1.maxPosition)
        const sB = calculateSurfaceArea(child2.minPosition, child2.maxPosition)
        const sC = calculateSurfaceArea(this.minPosition, this.maxPosition);

        const pA = sA / sC;
        const pB = sB / sC;

        const N_A = child1.children.length;
        const N_B = child2.children.length;

        return tTraversal + (pA * N_A * tIntersect) + (pB * N_B * tIntersect)
    }

    /*static triangleIntersectsLeaf(triangle) {
        const min = this.minPosition;
        const max = this.maxPosition;

        if (
            triangle.a.x >= min.x && triangle.a.x <= max.x &&
            triangle.a.y >= min.y && triangle.a.y <= max.y &&
            triangle.a.z >= min.z && triangle.a.z <= max.z &&
            triangle.b.x >= min.x && triangle.b.x <= max.x &&
            triangle.b.y >= min.y && triangle.b.y <= max.y &&
            triangle.b.z >= min.z && triangle.b.z <= max.z &&
            triangle.c.x >= min.x && triangle.c.x <= max.x &&
            triangle.c.y >= min.y && triangle.c.y <= max.y &&
            triangle.c.z >= min.z && triangle.c.z <= max.z
        ) {
            return true;
        }

        return false;
    }*/

    static triangleIntersectsLeaf(triangle, min, max) {
        let centroid = triangle.getCentroid();
        if(min.x > max.x && min.y > max.y && min.y > max.y){
            let temp = min;
            min = max;
            max = temp;
        }

        if (
            centroid.x >= min.x && centroid.x <= max.x &&
            centroid.y >= min.y && centroid.y <= max.y &&
            centroid.z >= min.z && centroid.z <= max.z
        ) {
            return true;
        }

        return false;
    }

    /*static triangleIntersectsLeaf(triangle, p, dpp) {
        // Triangle normal
        const n = triangle.t;
        const dp = Vector3.subtract(dpp, p)

        // Test for triangle-plane/box overlap
        const c = new Vector3(
            n.x > 0 ? dp.x : 0,
            n.y > 0 ? dp.y : 0,
            n.z > 0 ? dp.z : 0
        );

        const d1 = n.dot(c.subtract(triangle.a));
        const d2 = n.dot(dp.subtract(c.subtract(triangle.a)));

        if ((n.dot(p) + d1) * (n.dot(p) + d2) > 0) {
            return false;
        }

        let edge0 = triangle.b.subtract(triangle.a);
        let edge1 = triangle.c.subtract(triangle.a);
        let edge2 = triangle.c.subtract(triangle.b);

        // XY-plane projection overlap
        const xym = (n.z < 0 ? -1 : 1);
        const ne0xy = edge0.multiply(-1).cross(new Vector3(0, 0, xym)).multiply(-1);
        const ne1xy = edge1.multiply(-1).cross(new Vector3(0, 0, xym)).multiply(-1);
        const ne2xy = edge2.multiply(-1).cross(new Vector3(0, 0, xym)).multiply(-1);

        const axy = new Vector3(triangle.a.x, triangle.a.y, 0);
        const bxy = new Vector3(triangle.b.x, triangle.b.y, 0);
        const cxy = new Vector3(triangle.c.x, triangle.c.y, 0);

        const de0xy = -ne0xy.dot(axy) + Math.max(0, dp.x * ne0xy.x) + Math.max(0, dp.y * ne0xy.y);
        const de1xy = -ne1xy.dot(bxy) + Math.max(0, dp.x * ne1xy.x) + Math.max(0, dp.y * ne1xy.y);
        const de2xy = -ne2xy.dot(cxy) + Math.max(0, dp.x * ne2xy.x) + Math.max(0, dp.y * ne2xy.y);

        const pxy = new Vector3(p.x, p.y, 0);

        if (ne0xy.dot(pxy) + de0xy < 0 || ne1xy.dot(pxy) + de1xy < 0 || ne2xy.dot(pxy) + de2xy < 0) {
            return false;
        }

        // YZ-plane projection overlap
        const yzm = (n.x < 0 ? -1 : 1);
        const ne0yz = edge0.multiply(-1).cross(new Vector3(yzm, 0, 0)).multiply(-1);
        const ne1yz = edge1.multiply(-1).cross(new Vector3(yzm, 0, 0)).multiply(-1);
        const ne2yz = edge2.multiply(-1).cross(new Vector3(yzm, 0, 0)).multiply(-1);

        const ayz = new Vector3(triangle.a.y, triangle.a.z, 0);
        const byz = new Vector3(triangle.b.y, triangle.b.z, 0);
        const cyz = new Vector3(triangle.c.y, triangle.c.z, 0);

        const de0yz = -ne0yz.dot(ayz) + Math.max(0, dp.y * ne0yz.x) + Math.max(0, dp.z * ne0yz.y);
        const de1yz = -ne1yz.dot(byz) + Math.max(0, dp.y * ne1yz.x) + Math.max(0, dp.z * ne1yz.y);
        const de2yz = -ne2yz.dot(cyz) + Math.max(0, dp.y * ne2yz.x) + Math.max(0, dp.z * ne2yz.y);

        const pyz = new Vector3(p.y, p.z, 0);

        if (ne0yz.dot(pyz) + de0yz < 0 || ne1yz.dot(pyz) + de1yz < 0 || ne2yz.dot(pyz) + de2yz < 0) {
            return false;
        }

        // ZX-plane projection overlap
        const zxm = (n.y < 0 ? -1 : 1);
        const ne0zx = edge0.multiply(-1).cross(new Vector3(0, zxm, 0)).multiply(-1);
        const ne1zx = edge1.multiply(-1).cross(new Vector3(0, zxm, 0)).multiply(-1);
        const ne2zx = edge2.multiply(-1).cross(new Vector3(0, zxm, 0)).multiply(-1);

        const azx = new Vector3(triangle.a.z, triangle.a.x, 0);
        const bzx = new Vector3(triangle.b.z, triangle.b.x, 0);
        const czx = new Vector3(triangle.c.z, triangle.c.x, 0);

        const de0zx = -ne0zx.dot(azx) + Math.max(0, dp.y * ne0zx.x) + Math.max(0, dp.z * ne0zx.y);
        const de1zx = -ne1zx.dot(bzx) + Math.max(0, dp.y * ne1zx.x) + Math.max(0, dp.z * ne1zx.y);
        const de2zx = -ne2zx.dot(czx) + Math.max(0, dp.y * ne2zx.x) + Math.max(0, dp.z * ne2zx.y);

        const pzx = new Vector3(p.z, p.x, 0);

        if (ne0zx.dot(pzx) + de0zx < 0 || ne1zx.dot(pzx) + de1zx < 0 || ne2zx.dot(pzx) + de2zx < 0) {
            return false;
        }

        return true;
    }*/

    static calculateTreeSize(triangleArray) {
        let minPosition = new Vector3(triangleArray[0].a.x, triangleArray[0].a.y, triangleArray[0].a.z);
        let maxPosition = new Vector3(triangleArray[0].a.x, triangleArray[0].a.y, triangleArray[0].a.z);

        for (const triangle of triangleArray) {
            updateMinMax(minPosition, maxPosition, triangle.a);
            updateMinMax(minPosition, maxPosition, triangle.b);
            updateMinMax(minPosition, maxPosition, triangle.c);
        }

        return { minPosition, maxPosition }
    }
}

export default BVHTree;
export { BVHTree }