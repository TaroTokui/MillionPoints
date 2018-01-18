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
half _Smoothness;
half _Metallic;

struct ParticleData
{
	float3 BasePosition;
	float3 Position;
	float3 Albedo;
	float rotationSpeed;
};

#if defined(UNITY_PROCEDURAL_INSTANCING_ENABLED)
StructuredBuffer<ParticleData> _ParticleDataBuffer;
#endif

// Vertex input attributes
struct Attributes
{
	float4 position : POSITION;
	float3 normal : NORMAL;
	//float4 tangent : TANGENT;
	float2 texcoord : TEXCOORD;
	uint instanceID : POSITION1;
	float4 color : COLOR;
};

// Fragment varyings
struct Varyings
{
	float4 position : SV_POSITION;

#if defined(PASS_CUBE_SHADOWCASTER)
	// Cube map shadow caster pass
	float3 shadow : TEXCOORD0;

#elif defined(UNITY_PASS_SHADOWCASTER)
	// Default shadow caster pass

#else
	// GBuffer construction pass
	float3 normal : NORMAL;
	float2 texcoord : TEXCOORD0;
	float3 worldPos : TEXCOORD1;
	half3 ambient : TEXCOORD2;

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
	//input.texcoord = TRANSFORM_TEX(input.texcoord, _MainTex);
	input.instanceID = unity_InstanceID;
	input.color = _ParticleDataBuffer[unity_InstanceID].color;
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

#elif defined(UNITY_PASS_SHADOWCASTER)
	// Default shadow caster pass: Apply the shadow bias.
	float scos = dot(wnrm, normalize(UnityWorldSpaceLightDir(wpos)));
	wpos -= wnrm * unity_LightShadowBias.z * sqrt(1 - scos * scos);
	o.position = UnityApplyLinearShadowBias(UnityWorldToClipPos(float4(wpos, 1)));

#else
	// GBuffer construction pass
	//half3 bi = cross(wnrm, wtan) * wtan.w * unity_WorldTransformParams.w;
	o.position = UnityWorldToClipPos(float4(wpos, 1));
	o.normal = wnrm;
	o.texcoord = uv;
	o.worldPos = wpos;
	o.ambient = ShadeSHPerVertex(wnrm, 0);

#endif
	return o;
}

float3 ConstructNormal(float3 v1, float3 v2, float3 v3)
{
	return normalize(cross(v2 - v1, v3 - v1));
}

[maxvertexcount(2)]
void geom(
	line Attributes input[2], uint pid : SV_PrimitiveID,
	inout LineStream<Varyings> outStream
)
{
	// Vertex inputs
	//float3 wp0 = input[0].position.xyz;
	//float3 wp1 = input[1].position.xyz;
	float3 wp0 = _ParticleDataBuffer[input[0].instanceID].Position;
	float3 wp1 = _ParticleDataBuffer[input[1].instanceID].Position;

	float3 n0 = input[0].normal;
	float3 n1 = input[1].normal;

	float2 uv0 = input[0].texcoord;
	float2 uv1 = input[1].texcoord;

	// draw original polygon
	outStream.Append(VertexOutput(wp0, n0, uv0));
	outStream.Append(VertexOutput(wp1, n1, uv1));
	outStream.RestartStrip();

	//float4x4 matrix_ = (float4x4)0;
	//matrix_._11_22_33_44 = float4(_MeshScale.xyz, 1.0);
	//matrix_._14_24_34 += _ParticleDataBuffer[unity_InstanceID].Position;
	//v.vertex = mul(matrix_, v.vertex);
	//v.color = fixed4(_ParticleDataBuffer[unity_InstanceID].Albedo, 1);

}

void setup()
{
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

#elif defined(UNITY_PASS_SHADOWCASTER)

// Default shadow caster pass
half4 frag() : SV_Target{ return 0; }

#else

// GBuffer construction pass
void frag(
	Varyings input,
	float vface : VFACE,
	out half4 outGBuffer0 : SV_Target0,
	out half4 outGBuffer1 : SV_Target1,
	out half4 outGBuffer2 : SV_Target2,
	out half4 outEmission : SV_Target3
)
{
	// Sample textures
	half3 albedo = _Color.rgb;

	half4 normal = half4(input.normal,1);
	//normal.xyz = UnpackScaleNormal(normal, _BumpScale);

	//half occ = tex2D(_OcclusionMap, input.texcoord).g;
	//occ = LerpOneTo(occ, _OcclusionStrength);

	// PBS workflow conversion (metallic -> specular)
	half3 c_diff, c_spec;
	half refl10;
	c_diff = DiffuseAndSpecularFromMetallic(
		albedo, _Metallic, // input
		c_spec, refl10     // output
	);

	// Update the GBuffer.
	UnityStandardData data;
	data.diffuseColor = c_diff;
	data.occlusion = 1;
	data.specularColor = c_spec;
	data.smoothness = _Smoothness;
	data.normalWorld = (vface < 0 ? -1 : 1) * input.normal;
	UnityStandardDataToGbuffer(data, outGBuffer0, outGBuffer1, outGBuffer2);

	// Output ambient light and edge emission to the emission buffer.
	half3 sh = ShadeSHPerPixel(data.normalWorld, input.ambient.rgb, input.worldPos);
	outEmission = half4(sh * data.diffuseColor, 1);
}

#endif
