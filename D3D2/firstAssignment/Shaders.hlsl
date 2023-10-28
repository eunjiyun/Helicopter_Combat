struct MATERIAL
{
	float4					m_cAmbient;
	float4					m_cDiffuse;


	//float4					m_cSpecular; //a = power
	//float4					m_cEmissive;
	float3					texMat;

	uint gnTexturesMask;
	float 		gfCurrentTime;
	

	
	float		gfElapsedTime;
	float2		gf2CursorPos;
};

cbuffer cbCameraInfo : register(b1)
{
	matrix		gmtxView : packoffset(c0);
	matrix		gmtxProjection : packoffset(c4);
	float3		gvCameraPosition : packoffset(c8);
};



cbuffer cbGameObjectInfo : register(b2)
{
	matrix		gmtxGameObject : packoffset(c0);
	MATERIAL	gMaterial : packoffset(c4);
};

//cbuffer cbFrameworkInfo : register(b3)
//{
//	float 		gfCurrentTime;
//	float		gfElapsedTime;
//	float2		gf2CursorPos;
//};

#include "Light.hlsl"

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
//#define _WITH_VERTEX_LIGHTING

#define MATERIAL_ALBEDO_MAP			0x01
#define MATERIAL_SPECULAR_MAP		0x02
#define MATERIAL_NORMAL_MAP			0x04
#define MATERIAL_METALLIC_MAP		0x08
#define MATERIAL_EMISSION_MAP		0x10
#define MATERIAL_DETAIL_ALBEDO_MAP	0x20
#define MATERIAL_DETAIL_NORMAL_MAP	0x40

#define _WITH_STANDARD_TEXTURE_MULTIPLE_DESCRIPTORS

#ifdef _WITH_STANDARD_TEXTURE_MULTIPLE_DESCRIPTORS
Texture2D gtxtAlbedoTexture : register(t6);
Texture2D gtxtSpecularTexture : register(t7);
Texture2D gtxtNormalTexture : register(t8);
Texture2D gtxtMetallicTexture : register(t9);
Texture2D gtxtEmissionTexture : register(t10);
Texture2D gtxtDetailAlbedoTexture : register(t11);
Texture2D gtxtDetailNormalTexture : register(t12);
#else
Texture2D gtxtStandardTextures[7] : register(t6);
#endif

Texture2D<float4> gtxtWaterBaseTexture : register(t3);
Texture2D<float4> gtxtWaterDetail0Texture : register(t4);
Texture2D<float4> gtxtWaterDetail1Texture : register(t5);

static matrix<float, 3, 3> sf3x3TextureAnimation = { { 1.0f, 0.0f, 0.0f }, { 0.0f, 1.0f, 0.0f }, { 0.0f, 0.0f, 0.0f } };

SamplerState gssWrap : register(s0);


Texture2D gtxtTexture : register(t0);
struct VS_STANDARD_INPUT
{
	float3 position : POSITION;
	float2 uv : TEXCOORD;
	float3 normal : NORMAL;
	float3 tangent : TANGENT;
	float3 bitangent : BITANGENT;
};

struct VS_STANDARD_OUTPUT
{
	float4 position : SV_POSITION;
	float3 positionW : POSITION;
	float3 normalW : NORMAL;
	float3 tangentW : TANGENT;
	float3 bitangentW : BITANGENT;
	float2 uv : TEXCOORD;
};

VS_STANDARD_OUTPUT VSStandard(VS_STANDARD_INPUT input)
{
	VS_STANDARD_OUTPUT output;

	output.positionW = (float3)mul(float4(input.position, 1.0f), gmtxGameObject);
	output.normalW = mul(input.normal, (float3x3)gmtxGameObject);
	output.tangentW = (float3)mul(float4(input.tangent, 1.0f), gmtxGameObject);
	output.bitangentW = (float3)mul(float4(input.bitangent, 1.0f), gmtxGameObject);
	output.position = mul(mul(float4(output.positionW, 1.0f), gmtxView), gmtxProjection);
	output.uv = input.uv;

	return(output);
}

float4 PSStandard(VS_STANDARD_OUTPUT input) : SV_TARGET
{
	float4 cAlbedoColor = float4(0.0f, 0.0f, 0.0f, 1.0f);
	float4 cSpecularColor = float4(0.0f, 0.0f, 0.0f, 1.0f);
	float4 cNormalColor = float4(0.0f, 0.0f, 0.0f, 1.0f);
	float4 cMetallicColor = float4(0.0f, 0.0f, 0.0f, 1.0f);
	float4 cEmissionColor = float4(0.0f, 0.0f, 0.0f, 1.0f);

#ifdef _WITH_STANDARD_TEXTURE_MULTIPLE_DESCRIPTORS
	if (gMaterial.gnTexturesMask & MATERIAL_ALBEDO_MAP) cAlbedoColor = gtxtAlbedoTexture.Sample(gssWrap, input.uv);
	if (gMaterial.gnTexturesMask & MATERIAL_SPECULAR_MAP) cSpecularColor = gtxtSpecularTexture.Sample(gssWrap, input.uv);
	if (gMaterial.gnTexturesMask & MATERIAL_NORMAL_MAP) cNormalColor = gtxtNormalTexture.Sample(gssWrap, input.uv);
	if (gMaterial.gnTexturesMask & MATERIAL_METALLIC_MAP) cMetallicColor = gtxtMetallicTexture.Sample(gssWrap, input.uv);
	if (gMaterial.gnTexturesMask & MATERIAL_EMISSION_MAP) cEmissionColor = gtxtEmissionTexture.Sample(gssWrap, input.uv);
#else
	if (gMaterial.gnTexturesMask & MATERIAL_ALBEDO_MAP) cAlbedoColor = gtxtStandardTextures[0].Sample(gssWrap, input.uv);
	if (gMaterial.gnTexturesMask & MATERIAL_SPECULAR_MAP) cSpecularColor = gtxtStandardTextures[1].Sample(gssWrap, input.uv);
	if (gMaterial.gnTexturesMask & MATERIAL_NORMAL_MAP) cNormalColor = gtxtStandardTextures[2].Sample(gssWrap, input.uv);
	if (gMaterial.gnTexturesMask & MATERIAL_METALLIC_MAP) cMetallicColor = gtxtStandardTextures[3].Sample(gssWrap, input.uv);
	if (gMaterial.gnTexturesMask & MATERIAL_EMISSION_MAP) cEmissionColor = gtxtStandardTextures[4].Sample(gssWrap, input.uv);
#endif

	float4 cIllumination = float4(1.0f, 1.0f, 1.0f, 1.0f);
	float4 cColor = cAlbedoColor + cSpecularColor + cEmissionColor;
	if (gMaterial.gnTexturesMask & MATERIAL_NORMAL_MAP)
	{
		float3 normalW = input.normalW;
		float3x3 TBN = float3x3(normalize(input.tangentW), normalize(input.bitangentW), normalize(input.normalW));
		float3 vNormal = normalize(cNormalColor.rgb * 2.0f - 1.0f); //[0, 1] → [-1, 1]
		normalW = normalize(mul(vNormal, TBN));
		cIllumination = Lighting(input.positionW, normalW);
		cColor = lerp(cColor, cIllumination, 0.5f);
	}

	return(cColor);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
struct VS_SKYBOX_CUBEMAP_INPUT
{
	float3 position : POSITION;
};

struct VS_SKYBOX_CUBEMAP_OUTPUT
{
	float3	positionL : POSITION;
	float4	position : SV_POSITION;
};

VS_SKYBOX_CUBEMAP_OUTPUT VSSkyBox(VS_SKYBOX_CUBEMAP_INPUT input)
{
	VS_SKYBOX_CUBEMAP_OUTPUT output;

	output.position = mul(mul(mul(float4(input.position, 1.0f), gmtxGameObject), gmtxView), gmtxProjection);
	output.positionL = input.position;

	return(output);
}

TextureCube gtxtSkyCubeTexture : register(t13);
SamplerState gssClamp : register(s1);

float4 PSSkyBox(VS_SKYBOX_CUBEMAP_OUTPUT input) : SV_TARGET
{
	float4 cColor = gtxtSkyCubeTexture.Sample(gssClamp, input.positionL);

	return(cColor);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
struct VS_TEXTURED_INPUT
{
	float3 position : POSITION;
	float2 uv : TEXCOORD;
};

struct VS_TEXTURED_OUTPUT
{
	float4 position : SV_POSITION;
	float2 uv : TEXCOORD;
};

VS_TEXTURED_OUTPUT VSTextured(VS_TEXTURED_INPUT input)
{
	VS_TEXTURED_OUTPUT output;

	output.position = mul(mul(mul(float4(input.position, 1.0f), gmtxGameObject), gmtxView), gmtxProjection);

	output.uv = input.uv;

	return(output);
}
VS_TEXTURED_OUTPUT VSSpriteAnimation(VS_TEXTURED_INPUT input)
{
	VS_TEXTURED_OUTPUT output;

	output.position = mul(mul(mul(float4(input.position, 1.0f), gmtxGameObject), gmtxView), gmtxProjection);//gmtxGameObject

	if (gMaterial.texMat.z == 6)//연기 
	{
		output.uv.x = (input.uv.x) / gMaterial.texMat.z + gMaterial.texMat.x;
		output.uv.y = input.uv.y / gMaterial.texMat.z + gMaterial.texMat.y;
	}
	else if (gMaterial.texMat.z == 8)//로딩 파티클
	{
		output.uv.x = (input.uv.x) / gMaterial.texMat.z + gMaterial.texMat.x;
		output.uv.y = input.uv.y / (gMaterial.texMat.z * 0.75f) + gMaterial.texMat.y;
	}
	else
		output.uv = input.uv;

	return(output);
}

float4 PSTextured(VS_TEXTURED_OUTPUT input) : SV_TARGET
{
	float4 cColor = gtxtTexture.Sample(gssWrap, input.uv);

	return(cColor);
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
Texture2D gtxtTerrainTexture : register(t14);
Texture2D gtxtDetailTexture : register(t15);
Texture2D gtxtAlphaTexture : register(t16);

float4 PSTerrain(VS_TEXTURED_OUTPUT input) : SV_TARGET
{
	float4 cColor = gtxtTerrainTexture.Sample(gssWrap, input.uv);
	return(cColor);
}

struct VS_TERRAIN_INPUT
{
	float3 position : POSITION;
	float4 color : COLOR;
	float2 uv0 : TEXCOORD0;
	float2 uv1 : TEXCOORD1;
};

struct VS_TERRAIN_OUTPUT
{
	float4 position : SV_POSITION;
	float4 color : COLOR;
	float2 uv0 : TEXCOORD0;
	float2 uv1 : TEXCOORD1;
};

VS_TERRAIN_OUTPUT VSTerrain(VS_TERRAIN_INPUT input)
{
	VS_TERRAIN_OUTPUT output;

	output.position = mul(mul(mul(float4(input.position, 1.0f), gmtxGameObject), gmtxView), gmtxProjection);
	output.color = input.color;
	output.uv0 = input.uv0;
	output.uv1 = input.uv1;

	return(output);
}

float4 PSTerrain(VS_TERRAIN_OUTPUT input) : SV_TARGET
{
	float4 cBaseTexColor = gtxtTerrainTexture.Sample(gssWrap, input.uv0);
	float4 cDetailTexColor = gtxtDetailTexture.Sample(gssWrap, input.uv1);
	//	float fAlpha = gtxtTerrainTexture.Sample(gssWrap, input.uv0);

	float4 cColor = cBaseTexColor * 0.5f + cDetailTexColor * 0.5f;
	//	float4 cColor = saturate(lerp(cBaseTexColor, cDetailTexColor, fAlpha));

	return(cColor);
}


//=====================================================================================

struct VS_RIPPLE_WATER_INPUT
{
	float3 position : POSITION;
	float4 color : COLOR;
	float2 uv0 : TEXCOORD0;
};

struct VS_RIPPLE_WATER_OUTPUT
{
	float4 position : SV_POSITION;
	float4 color : COLOR;
	float2 uv0 : TEXCOORD0;
};

VS_RIPPLE_WATER_OUTPUT VSRippleWater(VS_RIPPLE_WATER_INPUT input)
{
	VS_RIPPLE_WATER_OUTPUT output;

	//	input.position.y += sin(gfCurrentTime * 0.5f + input.position.x * 0.01f + input.position.z * 0.01f) * 35.0f;
	//	input.position.y += sin(input.position.x * 0.01f) * 45.0f + cos(input.position.z * 0.01f) * 35.0f;
	//	input.position.y += sin(gfCurrentTime * 0.5f + input.position.x * 0.01f) * 45.0f + cos(gfCurrentTime * 1.0f + input.position.z * 0.01f) * 35.0f;
	//	input.position.y += sin(gfCurrentTime * 0.5f + ((input.position.x * input.position.x) + (input.position.z * input.position.z)) * 0.01f) * 35.0f;
	//	input.position.y += sin(gfCurrentTime * 1.0f + (((input.position.x * input.position.x) + (input.position.z * input.position.z)) - (1000 * 1000) * 2) * 0.0001f) * 10.0f;

	//	input.position.y += sin(gfCurrentTime * 1.0f + (((input.position.x * input.position.x) + (input.position.z * input.position.z))) * 0.0001f) * 10.0f;
	input.position.y += sin(gMaterial.gfCurrentTime * 0.35f + input.position.x * 0.35f) * 2.95f + cos(gMaterial.gfCurrentTime * 0.30f + input.position.z * 0.35f) * 2.05f;
	output.position = mul(float4(input.position, 1.0f), gmtxGameObject);
	if (610.0f < output.position.y) output.position.y = 610.0f;
	output.position = mul(mul(output.position, gmtxView), gmtxProjection);

	//	output.color = input.color;
	output.color = (input.position.y / 200.0f) + 0.55f;
	output.uv0 = input.uv0;
	//	output.uv1 = input.uv1;

	return(output);
}

float4 PSRippleWater(VS_RIPPLE_WATER_OUTPUT input) : SV_TARGET
{
	float2 uv = input.uv0;

#ifdef _WITH_STATIC_MATRIX
	sf3x3TextureAnimation._m21 = gMaterial.gfCurrentTime * 0.00125f;
	uv = mul(float3(input.uv0, 1.0f), sf3x3TextureAnimation).xy;
#else
#ifdef _WITH_CONSTANT_BUFFER_MATRIX
	uv = mul(float3(input.uv0, 1.0f), (float3x3)gf4x4TextureAnimation).xy;
	//	uv = mul(float4(uv, 1.0f, 0.0f), gf4x4TextureAnimation).xy;
#else
	uv.y += gMaterial.gfCurrentTime * 0.0825f /*0.00125f*/;
	uv.x += gMaterial.gfCurrentTime * 0.00125f;
#endif
#endif
	//gssWrap
	//float4 cBaseTexColor = gtxtWaterBaseTexture.SampleLevel(gSamplerState, uv, 0);
	//float4 cDetail0TexColor = gtxtWaterDetail0Texture.SampleLevel(gSamplerState, uv * 10.0f, 0);
	//float4 cDetail1TexColor = gtxtWaterDetail1Texture.SampleLevel(gSamplerState, uv * 5.0f, 0);

	float4 cBaseTexColor = gtxtWaterBaseTexture.SampleLevel(gssWrap, uv, 0);
	float4 cDetail0TexColor = gtxtWaterDetail0Texture.SampleLevel(gssWrap, uv * 10.0f, 0);
	float4 cDetail1TexColor = gtxtWaterDetail1Texture.SampleLevel(gssWrap, uv * 5.0f, 0);

	float4 cColor = float4(0.0f, 0.0f, 0.0f, 1.0f);
	cColor = lerp(cBaseTexColor * cDetail0TexColor, cDetail1TexColor.r * 0.5f, 0.35f);

	return(cColor);
}