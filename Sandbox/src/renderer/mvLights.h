#pragma once

#include "mvMath.h"
#include "mvTypes.h"
#include "mvMesh.h"
#include "mvCamera.h"
#include "mvBuffers.h"

struct PointLightInfo
{

    mvVec4 viewLightPos = { 0.0f, 15.0f, 0.0f, 1.0f };
    //-------------------------- ( 16 bytes )

    mvVec3 diffuseColor = { 1.0f, 1.0f, 1.0f };
    f32    diffuseIntensity = 1.0f;
    //-------------------------- ( 16 bytes )

    f32  attConst = 1.0f;
    f32  attLin = 0.045f;
    f32  attQuad = 0.0075f;
    char _pad1[4];
    //-------------------------- ( 16 bytes )

    //-------------------------- ( 4*16 = 64 bytes )
};

struct DirectionLightInfo
{

    f32    diffuseIntensity = 1.0f;
    mvVec3 viewLightDir = { 0.0f, -1.0f, 0.0f };
    //-------------------------- ( 16 bytes )

    mvVec3 diffuseColor = { 1.0f, 1.0f, 1.0f };
    f32    padding = 0.0f;
    //-------------------------- ( 16 bytes )

    //-------------------------- ( 2*16 = 32 bytes )
};

struct mvPointLight
{
    mvCamera       camera{};
    mvConstBuffer  buffer{};
    PointLightInfo info{};
    mvMesh         mesh{};
};

struct mvDirectionalLight
{
    mvConstBuffer      buffer{};
    DirectionLightInfo info{};
};

mvPointLight       create_point_light(mvAssetManager& am);
mvDirectionalLight create_directional_light(mvAssetManager& am);