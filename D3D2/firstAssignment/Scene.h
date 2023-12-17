//-----------------------------------------------------------------------------
// File: Scene.h
//-----------------------------------------------------------------------------

#pragma once

#include "Shader.h"
#include "Player.h"

#define MAX_LIGHTS			16 

#define POINT_LIGHT			1
#define SPOT_LIGHT			2
#define DIRECTIONAL_LIGHT	3

struct LIGHT
{
	XMFLOAT4				m_xmf4Ambient;
	XMFLOAT4				m_xmf4Diffuse;
	XMFLOAT4				m_xmf4Specular;
	XMFLOAT3				m_xmf3Position;
	float 					m_fFalloff;
	XMFLOAT3				m_xmf3Direction;
	float 					m_fTheta; //cos(m_fTheta)
	XMFLOAT3				m_xmf3Attenuation;
	float					m_fPhi; //cos(m_fPhi)
	bool					m_bEnable;
	int						m_nType;
	float					m_fRange;
	float					padding;
};

struct LIGHTS
{
	LIGHT					m_pLights[MAX_LIGHTS];
	XMFLOAT4				m_xmf4GlobalAmbient;
	int						m_nLights;
	UINT					renderMode;
};

class CScene
{
public:
	CScene();
	~CScene();

	bool OnProcessingMouseMessage(HWND hWnd, UINT nMessageID, WPARAM wParam, LPARAM lParam);
	bool OnProcessingKeyboardMessage(HWND hWnd, UINT nMessageID, WPARAM wParam, LPARAM lParam);

	virtual void CreateShaderVariables(ID3D12Device* pd3dDevice, ID3D12GraphicsCommandList* pd3dCommandList);
	virtual void UpdateShaderVariables(ID3D12GraphicsCommandList* pd3dCommandList);
	virtual void ReleaseShaderVariables();

	void BuildDefaultLightsAndMaterials();
	void BuildObjects(ID3D12Device* pd3dDevice, ID3D12GraphicsCommandList* pd3dCommandList);
	void ReleaseObjects();

	ID3D12RootSignature* CreateGraphicsRootSignature(ID3D12Device* pd3dDevice);
	ID3D12RootSignature* GetGraphicsRootSignature() { return(m_pd3dGraphicsRootSignature); }

	bool ProcessInput(UCHAR* pKeysBuffer);
	void AnimateObjects(float fTimeElapsed);
	void OnPrepareRender(ID3D12GraphicsCommandList* pd3dCommandList);
	void OnPreRender(ID3D12Device* pd3dDevice, ID3D12CommandQueue* pd3dCommandQueue, ID3D12Fence* pd3dFence, HANDLE hFenceEvent);
	void Render(ID3D12GraphicsCommandList* pd3dCommandList, CCamera* pCamera = NULL);

	void ReleaseUploadBuffers();

	CPlayer* m_pPlayer{ NULL };

public:
	ID3D12RootSignature* m_pd3dGraphicsRootSignature{ NULL };

	int									m_nGameObjects{};
	CGameObject** m_ppGameObjects{ NULL };

	int									m_nShaders{};
	CShader** m_ppShaders{ NULL };
	CObjectsShader* pObjectsShader{ NULL };
	CMultiSpriteObjectsShader* pMultiSpriteObjectShader{ NULL };

	CSkyBox* m_pSkyBox{ NULL };
	CHeightMapTerrain* m_pTerrain{ NULL };

	LIGHT* m_pLights{ NULL };
	int									m_nLights{};

	XMFLOAT4							m_xmf4GlobalAmbient;

	ID3D12Resource* m_pd3dcbLights{ NULL };
	LIGHTS* m_pcbMappedLights{ NULL };


	CRippleWater* m_pTerrainWater{ NULL };

	float* cuT{ nullptr };
	float* elT{ nullptr };
	UINT* x{ nullptr };
	//float* y{ nullptr };

	int							m_nEnvironmentMappingShaders{};
	CDynamicCubeMappingShader** m_ppEnvironmentMappingShaders{ NULL };
	CTextureToViewportShader* m_pShadowMapToViewport{ NULL };

	ID3D12Resource* m_pd3dcbMaterials{ NULL };

	bool start{ false };
	
};
