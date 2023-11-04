struct ray {
  origin: Vector3,
  direction: Vector3
};

fn rayAt(r: ray, t: f32) -> Vector3 {
  return vector_add(r.origin, vector_mul_scalar(t, r.direction));
}
