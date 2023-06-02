#ifndef ShaderTypes_h
#define ShaderTypes_h

#include <simd/simd.h>

#ifdef __METAL_VERSION__
#define NS_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
#define NSInteger metal::int32_t
#else
#import <Foundation/Foundation.h>
#endif

struct SharedUniforms {
    matrix_float4x4 view;
    matrix_float4x4 projection;
    vector_float3   eyePosition;
    unsigned int width;
    unsigned int height;
};

struct GeometryUniforms {
    matrix_float4x4 model;
};

// encodeYCrCbToRGBシェーダー関連
typedef NS_ENUM(NSInteger, ENCODE_YCBCR_TO_RGB_TEXTURE_INDEX)
{
    ENCODE_YCBCR_TO_RGB_TEXTURE_INDEX_Y         = 0,
    ENCODE_YCBCR_TO_RGB_TEXTURE_INDEX_CBCR      = 1,
    ENCODE_YCBCR_TO_RGB_TEXTURE_INDEX_DEPTH     = 2,
};
typedef NS_ENUM(NSInteger, ENCODE_YCBCR_TO_RGB_BUFFER_INDEX)
{
    ENCODE_YCBCR_TO_RGB_BUFFER_INDEX_VERTEX = 0,
};
// fullScreenQuadシェーダー関連
typedef NS_ENUM(NSInteger, RENDER_SCREEN_BUFFER_INDEX)
{
    RENDER_SCREEN_BUFFER_INDEX_SHARED_UNIFORMS = 0,
};
typedef NS_ENUM(NSInteger, RENDER_SCREEN_TEXTURE_INDEX)
{
    RENDER_SCREEN_TEXTURE_INDEX_RENDER_RESULT   = 0,
};
typedef NS_ENUM(NSInteger, POST_PROCESS_TEXTURE_INDEX)
{
    POST_PROCESS_TEXTURE_INDEX_RENDER_RESULT    = 0,
    POST_PROCESS_TEXTURE_INDEX_LIDAR_DEPTH      = 1,
    POST_PROCESS_TEXTURE_INDEX_SKY              = 2,
    POST_PROCESS_TEXTURE_INDEX_GEOMETRY         = 3,
};

typedef NS_ENUM(NSInteger, RENDER_GEOMETRY_TEXTURE_INDEX)
{
    RENDER_GEOMETRY_TEXTURE_INDEX_BASECOLOR     = 0,
};

typedef NS_ENUM(NSInteger, RENDER_GEOMETRY_BUFFER_INDEX)
{
    RENDER_GEOMETRY_BUFFER_INDEX_POSITION                   = 0,
    RENDER_GEOMETRY_BUFFER_INDEX_NORMAL                     = 1,
    RENDER_GEOMETRY_BUFFER_INDEX_UV                         = 2,
    RENDER_GEOMETRY_BUFFER_INDEX_SHARED_UNIFORMS            = 3,
    RENDER_GEOMETRY_BUFFER_INDEX_GEOMETRY_UNIFORMS          = 4,
};

#endif /* ShaderTypes_h */
