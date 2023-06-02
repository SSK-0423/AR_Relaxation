#include <metal_stdlib>
#include <simd/simd.h>

// Include header shared between this Metal shader code and C code executing Metal API commands
#import "ShaderTypes.h"

using namespace metal;

// YCbCr画像をRGB形式に変換
struct QuadVertexOut
{
    float4 position [[position]];
    float2 uv;
};
constant float2 quadVertices[] = {
    float2(-1, -1),
    float2(-1,  1),
    float2( 1,  1),
    float2(-1, -1),
    float2( 1,  1),
    float2( 1, -1)
};
// YCbCr画像をRGB形式に変換
struct ImagePlaneVertexIn {
    float2 position [[attribute(0)]];
    float2 uv       [[attribute(1)]];
};
struct ImagePlaneFragmentOut {
    float4 color    [[color(0)]];
    float depth     [[color(1)]];
};
vertex QuadVertexOut renderCapturedImageVertex(uint vid [[vertex_id]],
                                               const ImagePlaneVertexIn input [[stage_in]])
{
    QuadVertexOut out;
    out.position = float4(input.position,0.f,1.f);
    out.uv = input.uv;
    
    return out;
}
fragment ImagePlaneFragmentOut renderCapturedImageFragment(QuadVertexOut input [[stage_in]],
                                                           texture2d<float,access::sample> textureY [[texture(ENCODE_YCBCR_TO_RGB_TEXTURE_INDEX_Y)]],
                                                           texture2d<float,access::sample> textureCbCr
                                                           [[texture(ENCODE_YCBCR_TO_RGB_TEXTURE_INDEX_CBCR)]],
                                                           texture2d<float,access::sample> depthTexture
                                                           [[texture(ENCODE_YCBCR_TO_RGB_TEXTURE_INDEX_DEPTH)]])
{
    constexpr sampler smp(mip_filter::linear,
                          mag_filter::linear,
                          min_filter::linear);
    
    const float4x4 ycbcrToRGBTransform = float4x4(
                                                  float4(+1.0000f, +1.0000f, +1.0000f, +0.0000f),
                                                  float4(+0.0000f, -0.3441f, +1.7720f, +0.0000f),
                                                  float4(+1.4020f, -0.7141f, +0.0000f, +0.0000f),
                                                  float4(-0.7010f, +0.5291f, -0.8860f, +1.0000f)
                                                  );
    float2 uv = input.uv;
    // デバイスの姿勢によって処理内容を変える必要あり
    //uv.x = 1.f - uv.x;
    float4 ycbcr = float4(textureY.sample(smp, uv).r,textureCbCr.sample(smp, uv).rg,1.f);
    float depth = depthTexture.sample(smp, uv).r;
    
    ImagePlaneFragmentOut output;
    output.color = ycbcrToRGBTransform * ycbcr;
    output.depth = depth;
    
    return output;
}

// スクリーン全体を覆う四角形を描画する
vertex QuadVertexOut fullScreenQuadVertex(uint vid [[vertex_id]],
                                          const ImagePlaneVertexIn input[[stage_in]])
{
    //float2 position = quadVertices[vid];
    QuadVertexOut out;
    out.position = float4(input.position,0,1);
    out.uv = input.uv;
    
    return out;
}
// スクリーン全体を覆う四角形にレンダリング結果の画像をマッピングする
fragment float4 fullScreenQuadFragment(QuadVertexOut input [[stage_in]],
                                       constant SharedUniforms& uniforms
                                       [[buffer(RENDER_SCREEN_BUFFER_INDEX_SHARED_UNIFORMS)]],
                                       texture2d<float,access::sample> renderResult
                                       [[texture(RENDER_SCREEN_TEXTURE_INDEX_RENDER_RESULT)]])
{
    constexpr sampler smp(mag_filter::linear,
                          min_filter::linear,
                          mip_filter::linear);
    
    float2 uv = float2(input.uv.x, 1.f - input.uv.y);
    
    return renderResult.sample(smp, input.uv);
}

fragment float4 postProcessFragment(QuadVertexOut input [[stage_in]],
                                    constant SharedUniforms& uniforms
                                    [[buffer(RENDER_SCREEN_BUFFER_INDEX_SHARED_UNIFORMS)]],
                                    texture2d<float,access::sample> renderResult
                                    [[texture(POST_PROCESS_TEXTURE_INDEX_RENDER_RESULT)]],
                                    texture2d<float,access::sample> lidarDepth
                                    [[texture(POST_PROCESS_TEXTURE_INDEX_LIDAR_DEPTH)]],
                                    texture2d<float,access::sample> sky
                                    [[texture(POST_PROCESS_TEXTURE_INDEX_SKY)]],
                                    texture2d<float,access::sample> geometry
                                    [[texture(POST_PROCESS_TEXTURE_INDEX_GEOMETRY)]])
{
    constexpr sampler smp(mag_filter::linear,
                          min_filter::linear,
                          mip_filter::linear);
    
    float2 uv = float2(input.uv.x, 1.f - input.uv.y);
    
    float4 color = renderResult.sample(smp, input.uv);
    float4 skyColor = sky.sample(smp, input.uv);
    float4 geometryColor = geometry.sample(smp, input.uv);
    float depth = lidarDepth.sample(smp, input.uv).r;
    if(geometryColor.a != 0) {
        return geometryColor;
    }
    if(depth > 1 && skyColor.a != 0) {
        return skyColor;
    } else {
        return color;
    }
}

struct GeometryVertex
{
    float3 position [[attribute(0)]];
    float3 normal   [[attribute(1)]];
    float2 uv       [[attribute(2)]];
};

struct GeometryVertexOut
{
    float4 position [[position]];
    float3 worldPosition;
    float3 eyePosition;
    float3 normal;
    float2 uv;
};

struct GeometryFragmentOut
{
    float4 color        [[color(0)]];
    float  depth        [[color(1)]];
};

vertex GeometryVertexOut geometryVertex(GeometryVertex input [[stage_in]],
                                        uint vid [[vertex_id]],
                                        uint iid [[instance_id]],
                                        constant SharedUniforms& uniforms
                                        [[buffer(RENDER_GEOMETRY_BUFFER_INDEX_SHARED_UNIFORMS)]],
                                        constant GeometryUniforms& geometryUniforms
                                        [[buffer(RENDER_GEOMETRY_BUFFER_INDEX_GEOMETRY_UNIFORMS)]])
{
    GeometryVertexOut output;
    float4 position = float4(input.position,1.f);
    float4 worldPosition = geometryUniforms.model * position;
    output.position = uniforms.projection * uniforms.view * worldPosition;
    output.worldPosition = worldPosition.xyz;
    output.eyePosition = uniforms.eyePosition;
    
    float3 normal = (geometryUniforms.model * float4(input.normal,0.f)).xyz;
    output.normal = normalize(normal);
    
    output.uv = input.uv;
    
    return output;
};

fragment GeometryFragmentOut geometryFragment(GeometryVertexOut input [[stage_in]],
                                              constant SharedUniforms& uniforms
                                              [[buffer(RENDER_GEOMETRY_BUFFER_INDEX_SHARED_UNIFORMS)]],
                                              texture2d<float,access::sample> baseColor
                                              [[texture(0)]])
{
    GeometryFragmentOut output;
    constexpr sampler smp(mip_filter::linear,
                          mag_filter::linear,
                          min_filter::linear);
    // ランバートシェーディング
    float3 color = baseColor.sample(smp, input.uv).rgb;
    float3 lightColor = float3(1,1,1);
    float3 lightDir = normalize(float3(1,-1,-1));
    float3 diffuse = color * lightColor * saturate(dot(input.normal,-lightDir));
    
    float3 ambientColor = float3(0.5,0.5,0.5);
    float3 ambientIntensity = float3(1,1,1);
    float3 ambient = ambientColor * ambientIntensity;
    float3 phong = diffuse + ambient;
    
    // 深度
    float depth = length(input.worldPosition - input.eyePosition);
    
    // depthNormal
    output.color = float4(phong,1.f);
    output.depth = depth;
    
    return output;
};

fragment GeometryFragmentOut skyBoxFragment(GeometryVertexOut input [[stage_in]],
                                              constant SharedUniforms& uniforms
                                              [[buffer(RENDER_GEOMETRY_BUFFER_INDEX_SHARED_UNIFORMS)]],
                                              texture2d<float,access::sample> baseColor
                                              [[texture(0)]])
{
    GeometryFragmentOut output;
    constexpr sampler smp(mip_filter::linear,
                          mag_filter::linear,
                          min_filter::linear);
    float3 color = baseColor.sample(smp, input.uv).rgb;
    // 深度
    float depth = length(input.worldPosition - input.eyePosition);
    
    // depthNormal
    output.color = float4(color,1.f);
    output.depth = depth;
    
    return output;
};
