
struct mvPointLight
{
    float3 viewLightPos;
    //-------------------------- ( 16 bytes )

    float3 diffuseColor;
    float diffuseIntensity;
    //-------------------------- ( 16 bytes )

    float attConst;
    float attLin;
    float attQuad;
    //-------------------------- ( 16 bytes )

    //-------------------------- ( 4*16 = 64 bytes )
};

struct mvMaterial
{
    float4 albedo;
    //-------------------------- ( 16 bytes )
    
    float metalness;
    float roughness;
    float radiance;
    float fresnel;
    //-------------------------- ( 16 bytes )
    
    bool useAlbedoMap;
    bool useNormalMap;
    bool useRoughnessMap;
    bool useMetalMap;
    //-------------------------- ( 16 bytes )
    
    float3 emisiveFactor;
    bool useEmissiveMap;
    //-------------------------- ( 16 bytes )
    
    bool hasAlpha;
    bool useOcclusionMap;
    float occlusionStrength;
    float alphaCutoff;
    //-------------------------- ( 4 * 16 = 64 bytes )
};

struct mvDirectionalLight
{
    float diffuseIntensity;
    float3 viewLightDir;
    //-------------------------- ( 16 bytes )
    
    float3 diffuseColor;
    //-------------------------- ( 16 bytes )
    
    //-------------------------- ( 2*16 = 32 bytes )
};

struct mvGlobalInfo
{

    float3 ambientColor;
    bool useShadows;
    
    bool useOmniShadows;
    bool useSkybox;
    bool useAlbedo;
    bool useMetalness;
    //-------------------------- ( 16 bytes )
    
    bool useRoughness;
    bool useIrradiance;
    bool useReflection;
    bool useEmissiveMap;
    
    float4x4 projection;
    float4x4 model;
    float4x4 view;
    
    float3 camPos;
    bool useOcclusionMap;
    //-------------------------- ( 1*16 = 16 bytes )
    
    bool useNormalMap;
    bool usePCF;
    int pcfRange;
};

//-----------------------------------------------------------------------------
// textures
//-----------------------------------------------------------------------------
Texture2D   AlbedoTexture        : register(t0);
Texture2D   NormalTexture        : register(t1);
Texture2D   MetalRoughnessTexture: register(t2);
Texture2D   EmmissiveTexture     : register(t3);
Texture2D   OcclusionTexture     : register(t4);
Texture2D   DirectionalShadowMap : register(t5);
TextureCube ShadowMap            : register(t6);
TextureCube Environment          : register(t7);

//-----------------------------------------------------------------------------
// samplers
//-----------------------------------------------------------------------------
SamplerState           Sampler            : register(s0);
SamplerComparisonState DShadowSampler     : register(s1);
SamplerComparisonState OShadowSampler     : register(s2);
SamplerState           EnvironmentSampler : register(s3);

//-----------------------------------------------------------------------------
// constant buffers
//-----------------------------------------------------------------------------
cbuffer mvPointLightCBuf       : register(b0) { mvPointLight PointLight; };
cbuffer mvMaterialCBuf         : register(b1) { mvMaterial material; };
cbuffer mvDirectionalLightCBuf : register(b2) { mvDirectionalLight DirectionalLight; };
cbuffer mvGlobalCBuf           : register(b3) { mvGlobalInfo ginfo; };

struct VSOut
{   
    float4 Pos              : SV_Position;
    float3 WorldPos         : POSITION0;
    float3 WorldNormal      : NORMAL0;
    float2 UV               : TEXCOORD0;
    float4 dshadowWorldPos  : dshadowPosition; // directional light pos
    float4 oshadowWorldPos  : oshadowPosition; // point light pos
    float3x3 TBN            : TangentBasis;
    bool frontFace          : SV_IsFrontFace;
};

#include <tonemapping.hlsli>
#include <functions.hlsli>
#include <brdf.hlsli>
#include <punctual.hlsli>
#include <ibl.hlsli>
#include <material_info.hlsli>

NormalInfo getNormalInfo(VSOut input)
{
    
    float2 UV = input.UV;
    float3 uv_dx = ddx(float3(UV, 0.0));
    float3 uv_dy = ddy(float3(UV, 0.0));

    float3 t_ = (uv_dy.y * ddx(input.Pos).xyz - uv_dx.y * ddy(input.Pos).xyz) /
        (uv_dx.x * uv_dy.y - uv_dy.x * uv_dx.y);

    float3 n, t, b, ng;

    // Compute geometrical TBN:
    // Trivial TBN computation, present as vertex attribute.
    // Normalize eigenvectors as matrix is linearly interpolated.
    float3x3 TBN = transpose(input.TBN);
    t = normalize(TBN[0]);
    b = normalize(TBN[1]);
    ng = normalize(TBN[2]);
    
    // For a back-facing surface, the tangential basis vectors are negated.
    if (!input.frontFace)
    {
        t *= -1.0;
        b *= -1.0;
        ng *= -1.0;
    }

    // Compute normals:
    NormalInfo normalInfo;
    normalInfo.ng = ng;
    normalInfo.n = ng;
    if (material.useNormalMap && ginfo.useNormalMap)
    {
        
        normalInfo.ntex = NormalTexture.Sample(Sampler, input.UV).xyz * 2.0 - 1.0;
        normalInfo.ntex.y = -normalInfo.ntex.y;
        //float u_NormalScale = -1.0;
        //normalInfo.ntex *= float3(u_NormalScale, u_NormalScale, 1.0);
        normalInfo.ntex = normalize(normalInfo.ntex);
        normalInfo.n = normalize(mul(input.TBN, normalInfo.ntex));
        //normalInfo.n = normalize(mul(float3x3(t, b, ng), normalInfo.ntex));
        //return normalize(mul(input.TBN, tangentNormal));
        
    }

    normalInfo.t = t;
    normalInfo.b = b;
    return normalInfo;
}

float4 main(VSOut input) : SV_Target
{
    float4 finalColor;
    float4 baseColor = getBaseColor(input);
    
    if (baseColor.a < material.alphaCutoff)
    {
        discard;
    }
    
    clip(baseColor.a < 0.1f ? -1 : 1); // bail if highly translucent
    
    float3 v = normalize(ginfo.camPos - input.WorldPos);
    NormalInfo normalInfo = getNormalInfo(input);
    
    float3 n = normalInfo.n;
    float3 t = normalInfo.t;
    float3 b = normalInfo.b;

    float NdotV = clampedDot(n, v);
    float TdotV = clampedDot(t, v);
    float BdotV = clampedDot(b, v);
    
    MaterialInfo materialInfo;
    materialInfo.baseColor = baseColor.rgb;
    
    // The default index of refraction of 1.5 yields a dielectric normal incidence reflectance of 0.04.
    materialInfo.ior = 1.5;
    materialInfo.f0 = float3(0.04.xxx);
    materialInfo.specularWeight = 1.0;
    
#ifdef MATERIAL_IOR
    materialInfo = getIorInfo(materialInfo);
#endif

#ifdef MATERIAL_SPECULARGLOSSINESS
    materialInfo = getSpecularGlossinessInfo(materialInfo);
#endif

//#ifdef MATERIAL_METALLICROUGHNESS
    materialInfo = getMetallicRoughnessInfo(input, materialInfo);
//#endif

#ifdef MATERIAL_SHEEN
    materialInfo = getSheenInfo(materialInfo);
#endif

#ifdef MATERIAL_CLEARCOAT
    materialInfo = getClearCoatInfo(materialInfo, normalInfo);
#endif

#ifdef MATERIAL_SPECULAR
    materialInfo = getSpecularInfo(materialInfo);
#endif

#ifdef MATERIAL_TRANSMISSION
    materialInfo = getTransmissionInfo(materialInfo);
#endif

#ifdef MATERIAL_VOLUME
    materialInfo = getVolumeInfo(materialInfo);
#endif
    
    materialInfo.perceptualRoughness = clamp(materialInfo.perceptualRoughness, 0.0, 1.0);
    materialInfo.metallic = clamp(materialInfo.metallic, 0.0, 1.0);

    // Roughness is authored as perceptual roughness; as is convention,
    // convert to material roughness by squaring the perceptual roughness.
    materialInfo.alphaRoughness = materialInfo.perceptualRoughness * materialInfo.perceptualRoughness;

    // Compute reflectance.
    float reflectance = max(max(materialInfo.f0.r, materialInfo.f0.g), materialInfo.f0.b);

    // Anything less than 2% is physically impossible and is instead considered to be shadowing. Compare to "Real-Time-Rendering" 4th editon on page 325.
    materialInfo.f90 = float3(1.0.xxx);

    // LIGHTING
    float3 f_specular = float3(0.0.xxx);
    float3 f_diffuse = float3(0.0.xxx);
    float3 f_emissive = float3(0.0.xxx);
    float3 f_clearcoat = float3(0.0.xxx);
    float3 f_sheen = float3(0.0.xxx);
    float3 f_transmission = float3(0.0.xxx);

    float albedoSheenScaling = 1.0;
    
    // Calculate lighting contribution from image based lighting source (IBL)
#ifdef USE_IBL
    f_specular += getIBLRadianceGGX(n, v, materialInfo.perceptualRoughness, materialInfo.f0, materialInfo.specularWeight);
    f_diffuse += getIBLRadianceLambertian(n, v, materialInfo.perceptualRoughness, materialInfo.c_diff, materialInfo.f0, materialInfo.specularWeight);

#ifdef MATERIAL_CLEARCOAT
    f_clearcoat += getIBLRadianceGGX(materialInfo.clearcoatNormal, v, materialInfo.clearcoatRoughness, materialInfo.clearcoatF0, 1.0);
#endif

#ifdef MATERIAL_SHEEN
    f_sheen += getIBLRadianceCharlie(n, v, materialInfo.sheenRoughnessFactor, materialInfo.sheenColorFactor);
#endif
#endif

#if (defined(MATERIAL_TRANSMISSION) || defined(MATERIAL_VOLUME)) && (defined(USE_PUNCTUAL) || defined(USE_IBL))
    f_transmission += materialInfo.transmissionFactor * getIBLVolumeRefraction(
        n, v,
        materialInfo.perceptualRoughness,
        materialInfo.baseColor, materialInfo.f0, materialInfo.f90,
        v_Position, u_ModelMatrix, u_ViewMatrix, u_ProjectionMatrix,
        materialInfo.ior, materialInfo.thickness, materialInfo.attenuationColor, materialInfo.attenuationDistance);
#endif

    float ao = 1.0;
    // Apply optional PBR terms for additional (optional) shading
    if (material.useOcclusionMap && ginfo.useOcclusionMap)
    {
        ao = OcclusionTexture.Sample(Sampler, input.UV).r;
        
        f_diffuse = lerp(f_diffuse, f_diffuse * ao, material.occlusionStrength);
        // apply ambient occlusion to all lighting that is not punctual
        f_specular = lerp(f_specular, f_specular * ao, material.occlusionStrength);
        f_sheen = lerp(f_sheen, f_sheen * ao, material.occlusionStrength);
        f_clearcoat = lerp(f_clearcoat, f_clearcoat * ao, material.occlusionStrength);
    }
     
    {
        //Light light = u_Lights[i];

        float3 pointToLight = -DirectionalLight.viewLightDir;

        // BSTF
        float3 l = normalize(pointToLight);   // Direction from surface point to light
        float3 h = normalize(l + v);          // Direction of the vector between l and v, called halfway vector
        float NdotL = clampedDot(n, l);
        float NdotV = clampedDot(n, v);
        float NdotH = clampedDot(n, h);
        float LdotH = clampedDot(l, h);
        float VdotH = clampedDot(v, h);
        if (NdotL > 0.0 || NdotV > 0.0)
        {
            // Calculation of analytical light
            // https://github.com/KhronosGroup/glTF/tree/master/specification/2.0#acknowledgments AppendixB
            //float3 intensity = getLighIntensity(pointToLight);
            float3 intensity = DirectionalLight.diffuseIntensity * DirectionalLight.diffuseColor;
            f_diffuse += intensity * NdotL *  BRDF_lambertian(materialInfo.f0, materialInfo.f90, materialInfo.c_diff, materialInfo.specularWeight, VdotH);
            f_specular += intensity * NdotL * BRDF_specularGGX(materialInfo.f0, materialInfo.f90, materialInfo.alphaRoughness, materialInfo.specularWeight, VdotH, NdotL, NdotV, NdotH);

#ifdef MATERIAL_SHEEN
            f_sheen += intensity * getPunctualRadianceSheen(materialInfo.sheenColorFactor, materialInfo.sheenRoughnessFactor, NdotL, NdotV, NdotH);
            albedoSheenScaling = min(1.0 - max3(materialInfo.sheenColorFactor) * albedoSheenScalingLUT(NdotV, materialInfo.sheenRoughnessFactor),
                1.0 - max3(materialInfo.sheenColorFactor) * albedoSheenScalingLUT(NdotL, materialInfo.sheenRoughnessFactor));
#endif

#ifdef MATERIAL_CLEARCOAT
            f_clearcoat += intensity * getPunctualRadianceClearCoat(materialInfo.clearcoatNormal, v, l, h, VdotH,
                materialInfo.clearcoatF0, materialInfo.clearcoatF90, materialInfo.clearcoatRoughness);
#endif
        }

        // BDTF
#ifdef MATERIAL_TRANSMISSION
        // If the light ray travels through the geometry, use the point it exits the geometry again.
        // That will change the angle to the light source, if the material refracts the light ray.
        vec3 transmissionRay = getVolumeTransmissionRay(n, v, materialInfo.thickness, materialInfo.ior, u_ModelMatrix);
        pointToLight -= transmissionRay;
        l = normalize(pointToLight);

        vec3 intensity = getLighIntensity(light, pointToLight);
        vec3 transmittedLight = intensity * getPunctualRadianceTransmission(n, v, l, materialInfo.alphaRoughness, materialInfo.f0, materialInfo.f90, materialInfo.baseColor, materialInfo.ior);

#ifdef MATERIAL_VOLUME
        transmittedLight = applyVolumeAttenuation(transmittedLight, length(transmissionRay), materialInfo.attenuationColor, materialInfo.attenuationDistance);
#endif

        f_transmission += materialInfo.transmissionFactor * transmittedLight;
#endif
    }
    
    f_emissive = material.emisiveFactor;
    if (material.useEmissiveMap && ginfo.useEmissiveMap)
    {
        f_emissive *= pow(abs(EmmissiveTexture.Sample(Sampler, input.UV).rgb), float3(2.2, 2.2, 2.2));
    }
    else if (material.useEmissiveMap)
    {
        f_emissive = float3(0.0, 0.0, 0.0);
    }
    float3 color = float3(0.0.xxx);
    
    // Layer blending
    float clearcoatFactor = 0.0;
    float3 clearcoatFresnel = float3(0.0.xxx);

#ifdef MATERIAL_CLEARCOAT
    clearcoatFactor = materialInfo.clearcoatFactor;
    clearcoatFresnel = F_Schlick(materialInfo.clearcoatF0, materialInfo.clearcoatF90, clampedDot(materialInfo.clearcoatNormal, v));
    f_clearcoat = f_clearcoat * clearcoatFactor;
#endif

#ifdef MATERIAL_TRANSMISSION
    vec3 diffuse = mix(f_diffuse, f_transmission, materialInfo.transmissionFactor);
#else
    float3 diffuse = f_diffuse;
#endif

    color = f_emissive + diffuse + f_specular;
    color = f_sheen + color * albedoSheenScaling;
    color = color * (1.0 - clearcoatFactor * clearcoatFresnel) + f_clearcoat;
    
#ifdef LINEAR_OUTPUT
    finalColor = float4(color.rgb, baseColor.a);
#else
    finalColor = float4(toneMap(color), baseColor.a);
    //finalColor = float4(pow(color.rgb, float3(0.4545, 0.4545, 0.4545)), baseColor.a);
#endif

    return finalColor;
    
}