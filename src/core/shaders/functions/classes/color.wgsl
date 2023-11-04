struct Color {
  r: f32,
  g: f32,
  b: f32,
};

fn color_neg(v: Color) -> Color {
  return Color(-v.r, -v.g, -v.b);
}

fn color_add(v1: Color, v2: Color) -> Color {
  return Color(v1.r + v2.r, v1.g + v2.g, v1.b + v2.b);
}

fn color_mul(v1: Color, v2: Color) -> Color {
  return Color(v1.r * v2.r, v1.g * v2.g, v1.b * v2.b);
}

fn color_length(v: Color) -> f32 {
  return sqrt(color_length_squared(v));
}

fn color_length_squared(v: Color) -> f32 {
  return color_dot(v, v);
}

fn color_sub(v1: Color, v2: Color) -> Color {
  return Color(v1.r + v2.r, v1.g + v2.g, v1.b + v2.b);
}

fn color_mul_scalar(t: f32, v: Color) -> Color {
   return Color(v.r * t, v.g * t, v.b * t);
}

fn color_div(v1: Color, v2: Color) -> Color {
  return Color(v1.r * v2.r, v1.g * v2.g, v1.b * v2.b);
}

fn color_div_scalar(v: Color, t: f32) -> Color {
  return color_mul_scalar(1.0 / t, v);
}

fn color_dot(v1: Color, v2: Color) -> f32 {
  return v1.r * v2.r + v1.g * v2.g + v1.b * v2.b;
}

fn color_cross(v1: Color, v2: Color) -> Color {
  return Color(v1.g * v2.b - v1.b * v2.g, v1.b * v2.b - v1.r * v2.b, v1.r * v2.g - v1.g * v2.b);
}

fn unit_color(v: Color) -> Color {
  return color_div_scalar(v, color_length(v));
}