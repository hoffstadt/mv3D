#include "mvMaterials.h"
#include "mvAssetManager.h"

mvMaterial
create_material(mvAssetManager& am, const std::string& vs, const std::string& ps, mvMaterialData& materialData)
{
	mvMaterial material{};

	mvPipelineInfo pipelineInfo{};
	pipelineInfo.pixelShader = ps;
	pipelineInfo.vertexShader = vs;
	pipelineInfo.depthBias = 0;
	pipelineInfo.slopeBias = 0.0f;
	pipelineInfo.clamp = 0.0f;
	pipelineInfo.cull = !materialData.hasAlpha;

	pipelineInfo.layout = create_vertex_layout(
		{
			mvVertexElement::Position3D,
			mvVertexElement::Normal,
			mvVertexElement::Texture2D,
			mvVertexElement::Tangent,
			mvVertexElement::Bitangent
		}
	);

	std::string hash = ps + vs +
		std::to_string(materialData.albedo.x) +
		std::to_string(materialData.albedo.y) +
		std::to_string(materialData.albedo.z) +
		std::to_string(materialData.albedo.w) +
		std::to_string(materialData.metalness) +
		std::to_string(materialData.roughness) +
		std::to_string(materialData.emisiveFactor.x) +
		std::to_string(materialData.emisiveFactor.y) +
		std::to_string(materialData.emisiveFactor.z) +
		std::to_string(materialData.radiance) +
		std::to_string(materialData.fresnel) +
		std::string(materialData.hasAlpha ? "T" : "F") +
		std::string(materialData.useAlbedoMap ? "T" : "F") +
		std::string(materialData.useNormalMap ? "T" : "F") +
		std::string(materialData.useRoughnessMap ? "T" : "F") +
		std::string(materialData.useOcclusionMap ? "T" : "F") +
		std::string(materialData.useEmissiveMap ? "T" : "F") +
		std::string(materialData.useMetalMap ? "T" : "F");

	material.pipeline = mvGetMaterialAssetID(&am, hash);
	if (material.pipeline == -1)
	{
		material.pipeline = register_asset(&am, hash, finalize_pipeline(pipelineInfo));
	}

	material.colorSampler = create_sampler();
	material.data = materialData;
	material.buffer = create_const_buffer(&material.data, sizeof(mvMaterialData));

	return material;
}