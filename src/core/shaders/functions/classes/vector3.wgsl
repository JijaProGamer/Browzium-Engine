struct Vector3 {
  x: f32,
  y: f32,
  z: f32,
};

fn vector_neg(v: Vector3) -> Vector3 {
  return Vector3(-v.x, -v.y, -v.z);
}

fn vector_add(v1: Vector3, v2: Vector3) -> Vector3 {
  return Vector3(v1.x + v2.x, v1.y + v2.y, v1.z + v2.z);
}

fn vector_mul(v1: Vector3, v2: Vector3) -> Vector3 {
  return Vector3(v1.x * v2.x, v1.y * v2.y, v1.z * v2.z);
}

fn vector_length(v: Vector3) -> f32 {
  return sqrt(vector_length_squared(v));
}

fn vector_length_squared(v: Vector3) -> f32 {
  return vector_dot(v, v);
}

fn vector_sub(v1: Vector3, v2: Vector3) -> Vector3 {
  return Vector3(v1.x - v2.x, v1.y - v2.y, v1.z - v2.z);
}

fn vector_mul_scalar(t: f32, v: Vector3) -> Vector3 {
   return Vector3(v.x * t, v.y * t, v.z * t);
}

fn vector_div(v1: Vector3, v2: Vector3) -> Vector3 {
  return Vector3(v1.x / v2.x, v1.y / v2.y, v1.z / v2.z);
}

fn vector_div_scalar(v: Vector3, t: f32) -> Vector3 {
  return vector_mul_scalar(1.0 / t, v);
}

fn vector_dot(v1: Vector3, v2: Vector3) -> f32 {
  return v1.x * v2.x + v1.y * v2.y + v1.z * v2.z;
}

fn vector_cross(v1: Vector3, v2: Vector3) -> Vector3 {
    return Vector3(
        v1.y * v2.z - v1.z * v2.y,
        v1.z * v2.x - v1.x * v2.z,
        v1.x * v2.y - v1.y * v2.x
    );}

fn unit_vector(v: Vector3) -> Vector3 {
  return vector_div_scalar(v, vector_length(v));
}