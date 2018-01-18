// Standard geometry shader example
// https://github.com/keijiro/StandardGeometryShader

#include "Common.cginc"
#include "UnityCG.cginc"
#include "UnityGBuffer.cginc"
#include "UnityStandardUtils.cginc"

// Cube map shadow caster; Used to render point light shadows on platforms
// that lacks depth cube map support.
#if defined(SHADOWS_CUBE) && !defined(SHADOWS_CUBE_IN_DEPTH_TEX)
#define PASS_CUBE_SHADOWCASTER
#endif

// Shader uniforms
half4 _Color;
sampler2D _MainTex;
float4 _MainTex_ST;

half _Glossiness;
half _Metallic;

sampler2D _BumpMap;
float _BumpScale;

sampler2D _OcclusionMap;
float _OcclusionStrength;

float _LocalTime;

float _EffectLevel;
float _EffectThreshold;

// Vertex input attributes
struct Attributes
{
    float4 position : POSITION;
    float3 normal : NORMAL;
    //float4 tangent : TANGENT;
    float2 texcoord : TEXCOORD;
};

// Fragment varyings
struct Varyings
{
    float4 position : SV_POSITION;

#if defined(PASS_CUBE_SHADOWCASTER)
    // Cube map shadow caster pass
    float3 shadow : TEXCOORD0;

#endif
};

//
// Vertex stage
//

Attributes vert(Attributes input)
{
    // Only do object space to world space transform.
    input.position = mul(unity_ObjectToWorld, input.position);
    input.normal = UnityObjectToWorldNormal(input.normal);
    //input.tangent.xyz = UnityObjectToWorldDir(input.tangent.xyz);
    input.texcoord = TRANSFORM_TEX(input.texcoord, _MainTex);
    return input;
}

//
// Geometry stage
//

//Varyings VertexOutput(float3 wpos, half3 wnrm, half4 wtan, float2 uv)
Varyings VertexOutput(float3 wpos, half3 wnrm, float2 uv)
{
    Varyings o;

#if defined(PASS_CUBE_SHADOWCASTER)
    // Cube map shadow caster pass: Transfer the shadow vector.
    o.position = UnityWorldToClipPos(float4(wpos, 1));
    o.shadow = wpos - _LightPositionRange.xyz;

#else
    // Default shadow caster pass: Apply the shadow bias.
    float scos = dot(wnrm, normalize(UnityWorldSpaceLightDir(wpos)));
    wpos -= wnrm * unity_LightShadowBias.z * sqrt(1 - scos * scos);
    o.position = UnityApplyLinearShadowBias(UnityWorldToClipPos(float4(wpos, 1)));

#endif
    return o;
}

float3 ConstructNormal(float3 v1, float3 v2, float3 v3)
{
    return normalize(cross(v2 - v1, v3 - v1));
}

[maxvertexcount(3)]
void geom(
    triangle Attributes input[3], uint pid : SV_PrimitiveID,
    inout TriangleStream<Varyings> outStream
)
{
    // Vertex inputs
    float3 wp0 = input[0].position.xyz;
    float3 wp1 = input[1].position.xyz;
    float3 wp2 = input[2].position.xyz;
	
    float3 n0 = input[0].normal;
    float3 n1 = input[1].normal;
    float3 n2 = input[2].normal;

    float2 uv0 = input[0].texcoord;
    float2 uv1 = input[1].texcoord;
    float2 uv2 = input[2].texcoord;
	
	uint seed = pid * 877;
	float3 center = (wp0 + wp1 + wp2) / 3;

	float param = center.y - _EffectThreshold;

	//if(_EffectLevel < 0)
	if(param < 0)
	{
		// draw original polygon
        outStream.Append(VertexOutput(wp0, n0, uv0));
        outStream.Append(VertexOutput(wp1, n1, uv1));
        outStream.Append(VertexOutput(wp2, n2, uv2));
        outStream.RestartStrip();
        return;
	}
    //else if (_EffectLevel >= 1)
    else if (param >= 1)
	{
		// draw nothing
		return;
	}
	else
    {
        // -- Triangle fx --
        // Simple scattering animation

        // We use smoothstep to make naturally damped linear motion.
        float ss_param = smoothstep(0, 1, param);

        // Random motion
        float3 move = RandomVector(seed + 1) * ss_param * 1.5;
		move.y = param * param;

        // Random rotation
        float3 rot_angles = (RandomVector01(seed + 1) - 0.5) * 50 * param;
        float3x3 rot_m = Euler3x3(rot_angles * ss_param);

        // Simple shrink
        float scale = 1 - ss_param;

        // Apply the animation.
        float3 t_p0 = mul(rot_m, wp0 - center) * scale + center + move;
        float3 t_p1 = mul(rot_m, wp1 - center) * scale + center + move;
        float3 t_p2 = mul(rot_m, wp2 - center) * scale + center + move;
        float3 normal = normalize(cross(t_p1 - t_p0, t_p2 - t_p0));

        // Vertex outputs
        outStream.Append(VertexOutput(t_p0, normal, uv0));
        outStream.Append(VertexOutput(t_p1, normal, uv1));
        outStream.Append(VertexOutput(t_p2, normal, uv2));
        outStream.RestartStrip();
    }


}

//
// Fragment phase
//

#if defined(PASS_CUBE_SHADOWCASTER)

// Cube map shadow caster pass
half4 frag(Varyings input) : SV_Target
{
    float depth = length(input.shadow) + unity_LightShadowBias.x;
    return UnityEncodeCubeShadowDepth(depth * _LightPositionRange.w);
}

#else
// Default shadow caster pass
half4 frag() : SV_Target { return 0; }

#endif
