Shader "Unlit/MillionLines"
{
	Properties
	{
		_Color("Color", Color) = (1, 1, 1, 1)
		_Smoothness("Smoothness", Range(0, 1)) = 0
		_Metallic("Metallic", Range(0, 1)) = 0
	}

	SubShader
	{
		Tags{ "RenderType" = "Opaque" }

		CGPROGRAM

		#pragma surface surf Standard vertex:vert addshadow nolightmap
		#pragma instancing_options procedural:setup
		#pragma target 3.5

		struct ParticleData
		{
			float3 BasePosition;
			float3 Position;
			float3 Albedo;
			float rotationSpeed;
		};

		struct Input
		{
			float vface : VFACE;
			fixed4 color : COLOR;
		};

		struct appdata
		{
			float4 vertex : POSITION;
			float3 normal : NORMAL;
			float4 tangent : TANGENT;
			float4 texcoord1 : TEXCOORD1;
			float4 texcoord2 : TEXCOORD2;
			uint vid : SV_VertexID;
			fixed4 color : COLOR;
			UNITY_VERTEX_INPUT_INSTANCE_ID
		};

		half4 _Color;
		half _Smoothness;
		half _Metallic;

		float3 _MeshScale;
		uint _InstanceCount;
		uint _MeshVertices;

		#if defined(UNITY_PROCEDURAL_INSTANCING_ENABLED)
		StructuredBuffer<ParticleData> _ParticleDataBuffer;
		#endif

		void vert(inout appdata v)
		{
			#if defined(UNITY_PROCEDURAL_INSTANCING_ENABLED)

			uint idx = unity_InstanceID + v.vertex.x * _InstanceCount;

			// スケールと位置(平行移動)を適用
			float4x4 matrix_ = (float4x4)0;
			matrix_._11_22_33_44 = float4(_MeshScale.xyz, 1.0);
			matrix_._14_24_34 += _ParticleDataBuffer[idx].Position;
			v.vertex = mul(matrix_, v.vertex);
			v.color = fixed4(_ParticleDataBuffer[idx].Albedo, 1);

			#endif
		}

		void setup()
		{
			//unity_ObjectToWorld = _LocalToWorld;
			//unity_WorldToObject = _WorldToLocal;
		}

		void surf(Input IN, inout SurfaceOutputStandard o)
		{
			o.Albedo = IN.color.rgb * _Color.rgb;
			o.Metallic = _Metallic;
			o.Smoothness = _Smoothness;
			o.Normal = float3(0, 0, IN.vface < 0 ? -1 : 1);
		}

		ENDCG
	}
	FallBack "Diffuse"
}
