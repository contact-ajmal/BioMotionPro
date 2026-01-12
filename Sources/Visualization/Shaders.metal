#include <metal_stdlib>
using namespace metal;

// MARK: - Core Structures

struct VertexIn {
    float3 position [[attribute(0)]];
    float4 color [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float4 color;
    float2 pointCoord; // Used for circular markers (UV: -1 to 1)
};

struct Uniforms {
    float4x4 modelMatrix;
    float4x4 viewMatrix;
    float4x4 projectionMatrix;
};

// MARK: - Basic Line Shader (Skeleton, Grid)

vertex VertexOut vertexShader(
    VertexIn in [[stage_in]],
    constant Uniforms &uniforms [[buffer(1)]]
) {
    VertexOut out;
    
    float4 worldPosition = uniforms.modelMatrix * float4(in.position, 1.0);
    float4 viewPosition = uniforms.viewMatrix * worldPosition;
    out.position = uniforms.projectionMatrix * viewPosition;
    out.color = in.color;
    out.pointCoord = float2(0, 0); // Unused for lines
    
    return out;
}

fragment float4 fragmentShader(VertexOut in [[stage_in]]) {
    return in.color;
}

// MARK: - Marker Point Shader (Instanced Billboards)

struct MarkerInstance {
    float3 position;
    float4 color;
    float size;
};

vertex VertexOut markerVertexShader(
    uint vertexID [[vertex_id]],
    uint instanceID [[instance_id]],
    constant MarkerInstance *markers [[buffer(0)]],
    constant Uniforms &uniforms [[buffer(1)]]
) {
    VertexOut out;
    
    // Billboard quad vertices (2 triangles)
    // -1,-1 to 1,1
    float2 quadVertices[6] = {
        float2(-1, -1), float2(1, -1), float2(-1, 1),
        float2(-1, 1), float2(1, -1), float2(1, 1)
    };
    
    MarkerInstance marker = markers[instanceID];
    float2 quadPos = quadVertices[vertexID] * marker.size;
    
    // Transform center to view space
    float4 viewPos = uniforms.viewMatrix * uniforms.modelMatrix * float4(marker.position, 1.0);
    
    // Simple billboard: add offset in view space (XY plane)
    viewPos.xy += quadPos;
    
    out.position = uniforms.projectionMatrix * viewPos;
    out.color = marker.color;
    out.pointCoord = quadVertices[vertexID]; // Pass UVs for fragment shader
    
    return out;
}

fragment float4 markerFragmentShader(VertexOut in [[stage_in]]) {
    // Discard pixels outside the circle (radius 1.0)
    // pointCoord ranges from (-1, -1) to (1, 1)
    float distSq = dot(in.pointCoord, in.pointCoord);
    
    if (distSq > 1.0) {
        discard_fragment();
    }
    
    // Optional: Anti-aliasing
    // float alpha = 1.0 - smoothstep(0.85, 1.0, sqrt(distSq));
    // return float4(in.color.rgb, in.color.a * alpha);
    
    return in.color;
}

// MARK: - Grid Shader (Fade with distance)

vertex VertexOut gridVertexShader(
    VertexIn in [[stage_in]],
    constant Uniforms &uniforms [[buffer(1)]]
) {
    VertexOut out;
    
    float4 worldPosition = float4(in.position, 1.0);
    float4 viewPosition = uniforms.viewMatrix * worldPosition;
    out.position = uniforms.projectionMatrix * viewPosition;
    
    // Fade grid based on distance from camera
    float distance = length(viewPosition.xyz);
    float fade = saturate(1.0 - distance / 20.0);
    out.color = float4(in.color.rgb, in.color.a * fade);
    out.pointCoord = float2(0, 0);
    
    return out;
}

fragment float4 gridFragmentShader(VertexOut in [[stage_in]]) {
    return in.color;
}

// MARK: - Force Vector Shader

struct ForceVectorInstance {
    float3 origin;
    float3 direction;
    float magnitude;
    float4 color;
};

vertex VertexOut forceVectorVertexShader(
    uint vertexID [[vertex_id]],
    uint instanceID [[instance_id]],
    constant ForceVectorInstance *vectors [[buffer(0)]],
    constant Uniforms &uniforms [[buffer(1)]]
) {
    VertexOut out;
    
    ForceVectorInstance vec = vectors[instanceID];
    
    // Scale factor for visualization (e.g. 1000N = 1m)
    float scale = 0.001;
    
    float3 position;
    if (vertexID == 0) {
        position = vec.origin;
    } else {
        position = vec.origin + normalize(vec.direction) * vec.magnitude * scale;
    }
    
    float4 worldPosition = uniforms.modelMatrix * float4(position, 1.0);
    float4 viewPosition = uniforms.viewMatrix * worldPosition;
    out.position = uniforms.projectionMatrix * viewPosition;
    out.color = vec.color;
    out.pointCoord = float2(0, 0);
    
    return out;
}

// MARK: - Skeleton Bone Shader (Instanced Cylinders/Lines)

struct BoneInstance {
    float3 startPosition;
    float3 endPosition;
    float4 color;
    float width; // Unused for simple lines
};

vertex VertexOut boneVertexShader(
    uint vertexID [[vertex_id]],
    uint instanceID [[instance_id]],
    constant BoneInstance *bones [[buffer(0)]],
    constant Uniforms &uniforms [[buffer(1)]]
) {
    VertexOut out;
    
    BoneInstance bone = bones[instanceID];
    
    float3 position = (vertexID == 0) ? bone.startPosition : bone.endPosition;
    
    float4 worldPosition = uniforms.modelMatrix * float4(position, 1.0);
    float4 viewPosition = uniforms.viewMatrix * worldPosition;
    out.position = uniforms.projectionMatrix * viewPosition;
    out.color = bone.color;
    out.pointCoord = float2(0, 0);
    
    return out;
}

// MARK: - Trajectory Shader

struct TrajectoryPoint {
    float3 position;
    float4 color;
    float age;  // 0 = current, 1 = oldest
};

vertex VertexOut trajectoryVertexShader(
    uint vertexID [[vertex_id]],
    constant TrajectoryPoint *points [[buffer(0)]],
    constant Uniforms &uniforms [[buffer(1)]]
) {
    VertexOut out;
    
    TrajectoryPoint point = points[vertexID];
    
    float4 worldPosition = uniforms.modelMatrix * float4(point.position, 1.0);
    float4 viewPosition = uniforms.viewMatrix * worldPosition;
    out.position = uniforms.projectionMatrix * viewPosition;
    
    // Fade based on age
    float fade = 1.0 - point.age;
    out.color = float4(point.color.rgb, point.color.a * fade);
    out.pointCoord = float2(0, 0);
    
    return out;
}

fragment float4 trajectoryFragmentShader(VertexOut in [[stage_in]]) {
    if (in.color.a < 0.01) {
        discard_fragment();
    }
    return in.color;
}
