/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The math utilities function header.
*/

#include <stdlib.h>
#include <simd/simd.h>

/// Allow other libraries to overload their implementation because these are common method names.
#define AAPL_SIMD_OVERLOAD __attribute__((__overloadable__))

/// A single-precision quaternion type.
typedef vector_float4 quaternion_float;

/// Given a uint16_t encoded as a 16-bit float, returns a 32-bit float.
float AAPL_SIMD_OVERLOAD float32_from_float16(uint16_t i);

// Given a 32-bit float, returns a uint16_t encoded as a 16-bit float.
uint16_t AAPL_SIMD_OVERLOAD float16_from_float32(float f);

/// Returns the number of degrees in the specified number of radians.
float AAPL_SIMD_OVERLOAD degrees_from_radians(float radians);

/// Returns the number of radians in the specified number of degrees.
float AAPL_SIMD_OVERLOAD radians_from_degrees(float degrees);

// Generates a random float value inside the given range.
inline static float AAPL_SIMD_OVERLOAD  random_float(float min, float max)
{
    return (((double)random()/RAND_MAX) * (max-min)) + min;
}

/// Generate a random three-component vector with values between min and max.
vector_float3 AAPL_SIMD_OVERLOAD generate_random_vector(float min, float max);

/// Fast random seed.
void AAPL_SIMD_OVERLOAD seedRand(uint32_t seed);

/// Fast integer random.
int32_t AAPL_SIMD_OVERLOAD randi(void);

/// Fast floating-point random.
float AAPL_SIMD_OVERLOAD randf(float x);

/// Returns a vector that is linearly interpolated between the two given vectors.
vector_float3 AAPL_SIMD_OVERLOAD vector_lerp(vector_float3 v0, vector_float3 v1, float t);

/// Returns a vector that is linearly interpolated between the two given vectors.
vector_float4 AAPL_SIMD_OVERLOAD vector_lerp(vector_float4 v0, vector_float4 v1, float t);

/// Converts a unit-norm quaternion into its corresponding rotation matrix.
matrix_float3x3 AAPL_SIMD_OVERLOAD matrix3x3_from_quaternion(quaternion_float q);

/// Construct a matrix_float3x3 from three rows of three columns with float values.
/// Indices are m<column><row>.
matrix_float3x3 AAPL_SIMD_OVERLOAD matrix_make_rows(float m00, float m10, float m20,
                                                    float m01, float m11, float m21,
                                                    float m02, float m12, float m22);

/// Construct a matrix_float4x4 from four rows of four columns with float values.
/// Indices are m<column><row>.
matrix_float4x4 AAPL_SIMD_OVERLOAD matrix_make_rows(float m00, float m10, float m20, float m30,
                                                    float m01, float m11, float m21, float m31,
                                                    float m02, float m12, float m22, float m32,
                                                    float m03, float m13, float m23, float m33);

/// Construct a matrix_float3x3 from three vector_float3 column vectors.
matrix_float3x3 AAPL_SIMD_OVERLOAD matrix_make_columns(vector_float3 col0,
                                                       vector_float3 col1,
                                                       vector_float3 col2);

/// Construct a matrix_float4x4 from four vector_float4 column vectors.
matrix_float4x4 AAPL_SIMD_OVERLOAD matrix_make_columns(vector_float4 col0,
                                                       vector_float4 col1,
                                                       vector_float4 col2,
                                                       vector_float4 col3);

/// Construct a rotation matrix from the given angle and axis.
matrix_float3x3 AAPL_SIMD_OVERLOAD matrix3x3_rotation(float radians, vector_float3 axis);

/// Construct a rotation matrix from the given angle and axis.
matrix_float3x3 AAPL_SIMD_OVERLOAD matrix3x3_rotation(float radians, float x, float y, float z);

/// Construct a scaling matrix with the specified scaling factors.
matrix_float3x3 AAPL_SIMD_OVERLOAD matrix3x3_scale(float x, float y, float z);

/// Construct a scaling matrix, using the given vector as an array of scaling factors.
matrix_float3x3 AAPL_SIMD_OVERLOAD matrix3x3_scale(vector_float3 s);

/// Extracts the upper-left 3 x 3 submatrix of the given 4 x 4 matrix.
matrix_float3x3 AAPL_SIMD_OVERLOAD matrix3x3_upper_left(matrix_float4x4 m);

/// Returns the inverse of the transpose of the given matrix.
matrix_float3x3 AAPL_SIMD_OVERLOAD matrix_inverse_transpose(matrix_float3x3 m);

/// Construct a homogeneous rotation matrix from the given angle and axis.
matrix_float4x4 AAPL_SIMD_OVERLOAD matrix4x4_from_quaternion(quaternion_float q);

/// Construct a rotation matrix from the provided angle and axis.
matrix_float4x4 AAPL_SIMD_OVERLOAD matrix4x4_rotation(float radians, vector_float3 axis);

/// Construct a rotation matrix from the given angle and axis.
matrix_float4x4 AAPL_SIMD_OVERLOAD matrix4x4_rotation(float radians, float x, float y, float z);

/// Construct an identity matrix.
matrix_float4x4 AAPL_SIMD_OVERLOAD matrix4x4_identity(void);

/// Construct a scaling matrix with the given scaling factors.
matrix_float4x4 AAPL_SIMD_OVERLOAD matrix4x4_scale(float sx, float sy, float sz);

/// Construct a scaling matrix, using the given vector as an array of scaling factors.
matrix_float4x4 AAPL_SIMD_OVERLOAD matrix4x4_scale(vector_float3 s);

/// Construct a translation matrix that translates by the vector (tx, ty, tz).
matrix_float4x4 AAPL_SIMD_OVERLOAD matrix4x4_translation(float tx, float ty, float tz);

/// Construct a translation matrix that translates by the vector (t.x, t.y, t.z).
matrix_float4x4 AAPL_SIMD_OVERLOAD matrix4x4_translation(vector_float3 t);

/// Construct a translation matrix that scales by the vector (s.x, s.y, s.z) and translates by the vector (t.x, t.y, t.z).
matrix_float4x4 AAPL_SIMD_OVERLOAD matrix4x4_scale_translation(vector_float3 s, vector_float3 t);

/// Starting with left-hand world coordinates, construct a view matrix that is
/// positioned at (eyeX, eyeY, eyeZ) and looks toward (centerX, centerY, centerZ),
/// with the vector (upX, upY, upZ) pointing up for a left-hand coordinate system.
matrix_float4x4 AAPL_SIMD_OVERLOAD matrix_look_at_left_hand(float eyeX, float eyeY, float eyeZ,
                                                            float centerX, float centerY, float centerZ,
                                                            float upX, float upY, float upZ);

/// Starting with left-hand world coordinates, construct a view matrix that is
/// positioned at (eye) and looks toward (target), with the vector (up) pointing
/// up for a left-hand coordinate system.
matrix_float4x4 AAPL_SIMD_OVERLOAD matrix_look_at_left_hand(vector_float3 eye,
                                                            vector_float3 target,
                                                            vector_float3 up);

/// Starting with right-hand world coordinates, construct a view matrix that is
/// positioned at (eyeX, eyeY, eyeZ) and looks toward (centerX, centerY, centerZ),
/// with the vector (upX, upY, upZ) pointing up for a right-hand coordinate system.
matrix_float4x4 AAPL_SIMD_OVERLOAD matrix_look_at_right_hand(float eyeX, float eyeY, float eyeZ,
                                                             float centerX, float centerY, float centerZ,
                                                             float upX, float upY, float upZ);

/// Starting with right-hand world coordinates, construct a view matrix that is
/// positioned at (eye) and looks toward (target), with the vector (up) pointing
/// up for a right-hand coordinate system.
matrix_float4x4 AAPL_SIMD_OVERLOAD matrix_look_at_right_hand(vector_float3 eye,
                                                             vector_float3 target,
                                                             vector_float3 up);

/// Construct a symmetric orthographic projection matrix, from left-hand eye coordinates to left-hand clip coordinates.
/// This maps (left, top) to (-1, 1), (right, bottom) to (1, -1), and (nearZ, farZ) to (0, 1).
/// The first four arguments are signed eye coordinates.
/// nearZ and farZ are absolute distances from the eye to the near and far clip planes.
matrix_float4x4 AAPL_SIMD_OVERLOAD matrix_ortho_left_hand(float left, float right, float bottom, float top, float nearZ, float farZ);

/// Construct a symmetric orthographic projection matrix, from right-hand eye coordinates to right-hand clip coordinates.
/// This maps (left, top) to (-1, 1), (right, bottom) to (1, -1), and (nearZ, farZ) to (0, 1).
/// The first four arguments are signed eye coordinates.
/// nearZ and farZ are absolute distances from the eye to the near and far clip planes.
matrix_float4x4 AAPL_SIMD_OVERLOAD matrix_ortho_right_hand(float left, float right, float bottom, float top, float nearZ, float farZ);

/// Construct a symmetric perspective projection matrix, from left-hand eye
/// coordinates to left-hand clip coordinates, with a vertical viewing angle of
/// fovyRadians, the given aspect ratio, and the given absolute near and far
/// z distances from the eye.
matrix_float4x4 AAPL_SIMD_OVERLOAD matrix_perspective_left_hand(float fovyRadians, float aspect, float nearZ, float farZ);

/// Construct a symmetric perspective projection matrix, from right-hand eye
/// coordinates to right-hand clip coordinates, with a vertical viewing angle of
/// fovyRadians, the given aspect ratio, and the given absolute near and far
/// z distances from the eye.
matrix_float4x4  AAPL_SIMD_OVERLOAD matrix_perspective_right_hand(float fovyRadians, float aspect, float nearZ, float farZ);

/// Construct a general frustum projection matrix, from right-hand eye
/// coordinates to left-hand clip coordinates.
/// The bounds left, right, bottom, and top define the visible frustum at the near clip plane.
/// The first four arguments are signed eye coordinates.
/// nearZ and farZ are absolute distances from the eye to the near and far clip planes.
matrix_float4x4 AAPL_SIMD_OVERLOAD matrix_perspective_frustum_right_hand(float left, float right, float bottom, float top, float nearZ, float farZ);

/// Returns the inverse of the transpose of the given matrix.
matrix_float4x4 AAPL_SIMD_OVERLOAD matrix_inverse_transpose(matrix_float4x4 m);

/// Construct an identity quaternion.
quaternion_float AAPL_SIMD_OVERLOAD quaternion_identity(void);

/// Construct a quaternion of the form w + xi + yj + zk.
quaternion_float AAPL_SIMD_OVERLOAD quaternion(float x, float y, float z, float w);

/// Construct a quaternion of the form w + v.x*i + v.y*j + v.z*k.
quaternion_float AAPL_SIMD_OVERLOAD quaternion(vector_float3 v, float w);

/// Construct a unit-norm quaternion that represents rotation by the given angle about the axis (x, y, z).
quaternion_float AAPL_SIMD_OVERLOAD quaternion(float radians, float x, float y, float z);

/// Construct a unit-norm quaternion that represents rotation by the given angle about the specified axis.
quaternion_float AAPL_SIMD_OVERLOAD quaternion(float radians, vector_float3 axis);

/// Construct a unit-norm quaternion from the given matrix.
/// The result is undefined if the matrix doesn't represent a pure rotation.
quaternion_float AAPL_SIMD_OVERLOAD quaternion(matrix_float3x3 m);

/// Construct a unit-norm quaternion from the given matrix.
/// The result is undefined if the matrix doesn't represent a pure rotation.
quaternion_float AAPL_SIMD_OVERLOAD quaternion(matrix_float4x4 m);

/// Returns the length of the given quaternion.
float AAPL_SIMD_OVERLOAD quaternion_length(quaternion_float q);

float AAPL_SIMD_OVERLOAD quaternion_length_squared(quaternion_float q);

/// Returns the rotation axis of the given unit-norm quaternion.
vector_float3 AAPL_SIMD_OVERLOAD quaternion_axis(quaternion_float q);

/// Returns the rotation angle of the given unit-norm quaternion.
float AAPL_SIMD_OVERLOAD quaternion_angle(quaternion_float q);

/// Returns a quaternion from the given rotation axis and angle, in radians.
quaternion_float AAPL_SIMD_OVERLOAD quaternion_from_axis_angle(vector_float3 axis, float radians);

/// Returns a quaternion from the given 3 x 3 rotation matrix.
quaternion_float AAPL_SIMD_OVERLOAD quaternion_from_matrix3x3(matrix_float3x3 m);

/// Returns a quaternion from the given Euler angle, in radians.
quaternion_float AAPL_SIMD_OVERLOAD quaternion_from_euler(vector_float3 euler);

/// Returns a unit-norm quaternion.
quaternion_float AAPL_SIMD_OVERLOAD quaternion_normalize(quaternion_float q);

/// Returns the inverse quaternion of the given quaternion.
quaternion_float AAPL_SIMD_OVERLOAD quaternion_inverse(quaternion_float q);

/// Returns the conjugate quaternion of the given quaternion.
quaternion_float AAPL_SIMD_OVERLOAD quaternion_conjugate(quaternion_float q);

/// Returns the product of the two given quaternions.
quaternion_float AAPL_SIMD_OVERLOAD quaternion_multiply(quaternion_float q0, quaternion_float q1);

/// Returns the quaternion that results from spherically interpolating between the two given quaternions.
quaternion_float AAPL_SIMD_OVERLOAD quaternion_slerp(quaternion_float q0, quaternion_float q1, float t);

/// Returns the vector that results from rotating the given vector by the given unit-norm quaternion.
vector_float3 AAPL_SIMD_OVERLOAD quaternion_rotate_vector(quaternion_float q, vector_float3 v);

/// Returns the quaternion for the given forward and up vectors for right-hand coordinate systems.
quaternion_float AAPL_SIMD_OVERLOAD quaternion_from_direction_vectors_right_hand(vector_float3 forward, vector_float3 up);

/// Returns the quaternion for the given forward and up vectors for left-hand coordinate systems.
quaternion_float AAPL_SIMD_OVERLOAD quaternion_from_direction_vectors_left_hand(vector_float3 forward, vector_float3 up);

/// Returns a vector in the +Z direction for the given quaternion.
vector_float3 AAPL_SIMD_OVERLOAD forward_direction_vector_from_quaternion(quaternion_float q);

/// Returns a vector in the +Y direction for the given quaternion (for a left-hand coordinate system,
///   negate for a right-hand coordinate system).
vector_float3 AAPL_SIMD_OVERLOAD up_direction_vector_from_quaternion(quaternion_float q);

/// Returns a vector in the +X direction for the given quaternion (for a left-hand coordinate system,
///   negate for a right-hand coordinate system).
vector_float3 AAPL_SIMD_OVERLOAD right_direction_vector_from_quaternion(quaternion_float q);

matrix_float4x4 matrix_multiply(const matrix_float4x4 * m, const matrix_float4x4 * n);
