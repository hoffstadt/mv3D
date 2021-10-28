#pragma once

#include <string>
#include "mvMath.h"
#include "mvBuffers.h"
#include "mvVertexLayout.h"

struct mvObjMesh;
struct mvAssetManager;
struct mvGLTFModel;

struct mvMesh
{
    std::string    name;
    mvVertexLayout layout;
    mvVec3         pos                   = { 0.0f, 0.0f, 0.0f};
    mvVec3         rot                   = { 0.0f, 0.0f, 0.0f };
    mvVec3         scale                 = { 1.0f, 1.0f, 1.0f };
    mvAssetID      indexBuffer           = -1;
    mvAssetID      vertexBuffer          = -1;
    mvAssetID      diffuseTexture        = -1;
    mvAssetID      normalTexture         = -1;
    mvAssetID      specularTexture       = -1;
    mvAssetID      albedoTexture         = -1;
    mvAssetID      metalRoughnessTexture = -1;
    mvAssetID      phongMaterialID       = -1;
    mvAssetID      pbrMaterialID         = -1;
    mvAssetID      shadowMaterialID      = -1;
    b8             pbr                   = false;
};

mvMesh mvCreateTexturedCube(mvAssetManager& assetManager, f32 size = 1.0f);
mvMesh mvCreateTexturedQuad(mvAssetManager& assetManager, f32 size = 1.0f);

void mvLoadOBJAssets (mvAssetManager& assetManager, const std::string& root, const std::string& file);
void mvLoadGLTFAssets(mvAssetManager& assetManager, mvGLTFModel& model);
