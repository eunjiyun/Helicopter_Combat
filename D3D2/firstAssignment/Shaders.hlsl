struct MATERIAL
{
	float4					m_cAmbient;
	float4					m_cDiffuse;
	float4					m_cSpecular; //a = power
	//float4					m_cEmissive;
	float3					texMat;
	uint gnTexturesMask;
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
