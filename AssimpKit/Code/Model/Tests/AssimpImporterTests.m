
/*
 ---------------------------------------------------------------------------
 Assimp to Scene Kit Library (AssimpKit)
 ---------------------------------------------------------------------------
 Copyright (c) 2016, AssimpKit team
 All rights reserved.
 Redistribution and use of this software in source and binary forms,
 with or without modification, are permitted provided that the following
 conditions are met:
 * Redistributions of source code must retain the above
 copyright notice, this list of conditions and the
 following disclaimer.
 * Redistributions in binary form must reproduce the above
 copyright notice, this list of conditions and the
 following disclaimer in the documentation and/or other
 materials provided with the distribution.
 * Neither the name of the assimp team, nor the names of its
 contributors may be used to endorse or promote products
 derived from this software without specific prior
 written permission of the assimp team.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 ---------------------------------------------------------------------------
 */

#import <XCTest/XCTest.h>
#import "AssimpImporter.h"
#import "ModelLog.h"
#import "SCNAssimpAnimation.h"
#include "assimp/cimport.h"     // Plain-C interface
#include "assimp/light.h"       // Lights
#include "assimp/material.h"    // Materials
#include "assimp/postprocess.h" // Post processing flags
#include "assimp/scene.h"       // Output data structure

@interface AssimpImporterTests : XCTestCase

@property (strong, nonatomic) NSMutableDictionary *modelLogs;
@property (strong, nonatomic) NSString *testAssetsPath;

@end

@implementation AssimpImporterTests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each
    // test method in the class.
    self.modelLogs = [[NSMutableDictionary alloc] init];

    self.testAssetsPath = TEST_ASSETS_PATH;
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of
    // each test method in the class.
    [super tearDown];
}

#pragma mark - Check node geometry

- (void)checkNodeGeometry:(const struct aiNode *)aiNode
                 nodeName:(NSString *)nodeName
            withSceneNode:(SCNNode *)sceneNode
                  aiScene:(const struct aiScene *)aiScene
                  testLog:(ModelLog *)testLog
{
    int nVertices = 0;
    for (int i = 0; i < aiNode->mNumMeshes; i++)
    {
        int aiMeshIndex = aiNode->mMeshes[i];
        const struct aiMesh *aiMesh = aiScene->mMeshes[aiMeshIndex];
        nVertices += aiMesh->mNumVertices;
    }

    SCNGeometrySource *vertexSource =
        [sceneNode.geometry.geometrySources objectAtIndex:0];
    if (nVertices != vertexSource.vectorCount)
    {
        NSString *errorLog = [NSString
            stringWithFormat:
                @"Scene node %@ geometry does not have expected %d vertices",
                nodeName, nVertices];

        [testLog addErrorLog:errorLog];
    }
    SCNGeometrySource *normalSource =
        [sceneNode.geometry.geometrySources objectAtIndex:1];
    if (nVertices != normalSource.vectorCount)
    {
        NSString *errorLog = [NSString
            stringWithFormat:
                @"Scene node %@ geometry does not have expected %d normals",
                nodeName, nVertices];
        [testLog addErrorLog:errorLog];
    }

    SCNGeometrySource *texSource =
        [sceneNode.geometry.geometrySources objectAtIndex:2];
    if (nVertices != texSource.vectorCount)
    {
        {
            NSString *errorLog = [NSString
                stringWithFormat:@"Scene node %@ geometry does not have "
                                 @"expected %d tex coords",
                                 nodeName, nVertices];
            [testLog addErrorLog:errorLog];
        }
    }
}

#pragma mark - Check node materials

- (void)checkNode:(const struct aiNode *)aiNode
         material:(const struct aiMaterial *)aiMaterial
      textureType:(enum aiTextureType)aiTextureType
    withSceneNode:(SCNNode *)sceneNode
      scnMaterial:(SCNMaterial *)scnMaterial
        modelPath:(NSString *)modelPath
          testLog:(ModelLog *)testLog
{
    int nTextures = aiGetMaterialTextureCount(aiMaterial, aiTextureType);
    if (nTextures > 0)
    {
        NSString *texFileName;
        if (aiTextureType == aiTextureType_DIFFUSE)
        {
            texFileName = scnMaterial.diffuse.contents;
        }
        else if (aiTextureType == aiTextureType_SPECULAR)
        {
            texFileName = scnMaterial.specular.contents;
        }
        else if (aiTextureType == aiTextureType_AMBIENT)
        {
            texFileName = scnMaterial.ambient.contents;
        }
        else if (aiTextureType == aiTextureType_REFLECTION)
        {
            texFileName = scnMaterial.reflective.contents;
        }
        else if (aiTextureType == aiTextureType_EMISSIVE)
        {
            texFileName = scnMaterial.emission.contents;
        }
        else if (aiTextureType == aiTextureType_OPACITY)
        {
            texFileName = scnMaterial.transparent.contents;
        }
        else if (aiTextureType == aiTextureType_NORMALS)
        {
            texFileName = scnMaterial.normal.contents;
        }
        else if (aiTextureType == aiTextureType_LIGHTMAP)
        {
            texFileName = scnMaterial.ambientOcclusion.contents;
        }
        if (![[texFileName stringByDeletingLastPathComponent]
                isEqualToString:[modelPath stringByDeletingLastPathComponent]])
        {
            NSString *errorLog = [NSString
                stringWithFormat:@"The texture file name %@ is not a "
                                 @"file under the model path %@",
                                 [texFileName
                                     stringByDeletingLastPathComponent],
                                 [modelPath stringByDeletingLastPathComponent]];
            [testLog addErrorLog:errorLog];
        }
    }
    else
    {
        CGColorRef color;
        NSString *materialType;
        if (aiTextureType == aiTextureType_DIFFUSE)
        {
            color = (__bridge CGColorRef)[scnMaterial diffuse].contents;
            materialType = @"Diffuse";
        }
        else if (aiTextureType == aiTextureType_SPECULAR)
        {
            color = (__bridge CGColorRef)[scnMaterial specular].contents;
            materialType = @"Specular";
        }
        else if (aiTextureType == aiTextureType_AMBIENT)
        {
            color = (__bridge CGColorRef)[scnMaterial ambient].contents;
            materialType = @"Ambient";
        }
        else if (aiTextureType == aiTextureType_REFLECTION)
        {
            color = (__bridge CGColorRef)[scnMaterial reflective].contents;
            materialType = @"Reflective";
        }
        else if (aiTextureType == aiTextureType_EMISSIVE)
        {
            color = (__bridge CGColorRef)[scnMaterial emission].contents;
            materialType = @"Emission";
        }
        else if (aiTextureType == aiTextureType_OPACITY)
        {
            color = (__bridge CGColorRef)[scnMaterial transparent].contents;
            materialType = @"Transparent";
        }
        if (color == nil)
        {
            NSString *errorLog = [NSString
                stringWithFormat:@"The material color for %@ does not exist",
                                 materialType];
            [testLog addErrorLog:errorLog];
        }
    }
}

- (void)checkNodeMaterials:(const struct aiNode *)aiNode
                  nodeName:(NSString *)nodeName
             withSceneNode:(SCNNode *)sceneNode
                   aiScene:(const struct aiScene *)aiScene
                 modelPath:(NSString *)modelPath
                   testLog:(ModelLog *)testLog
{
    for (int i = 0; i < aiNode->mNumMeshes; i++)
    {
        int aiMeshIndex = aiNode->mMeshes[i];
        const struct aiMesh *aiMesh = aiScene->mMeshes[aiMeshIndex];
        const struct aiMaterial *aiMaterial =
            aiScene->mMaterials[aiMesh->mMaterialIndex];
        SCNMaterial *material = [sceneNode.geometry.materials objectAtIndex:i];
        [self checkNode:aiNode
                 material:aiMaterial
              textureType:aiTextureType_DIFFUSE
            withSceneNode:sceneNode
              scnMaterial:material
                modelPath:modelPath
                  testLog:testLog];
        [self checkNode:aiNode
                 material:aiMaterial
              textureType:aiTextureType_SPECULAR
            withSceneNode:sceneNode
              scnMaterial:material
                modelPath:modelPath
                  testLog:testLog];
        [self checkNode:aiNode
                 material:aiMaterial
              textureType:aiTextureType_AMBIENT
            withSceneNode:sceneNode
              scnMaterial:material
                modelPath:modelPath
                  testLog:testLog];
        [self checkNode:aiNode
                 material:aiMaterial
              textureType:aiTextureType_REFLECTION
            withSceneNode:sceneNode
              scnMaterial:material
                modelPath:modelPath
                  testLog:testLog];
        [self checkNode:aiNode
                 material:aiMaterial
              textureType:aiTextureType_EMISSIVE
            withSceneNode:sceneNode
              scnMaterial:material
                modelPath:modelPath
                  testLog:testLog];
        [self checkNode:aiNode
                 material:aiMaterial
              textureType:aiTextureType_OPACITY
            withSceneNode:sceneNode
              scnMaterial:material
                modelPath:modelPath
                  testLog:testLog];
        [self checkNode:aiNode
                 material:aiMaterial
              textureType:aiTextureType_NORMALS
            withSceneNode:sceneNode
              scnMaterial:material
                modelPath:modelPath
                  testLog:testLog];
        [self checkNode:aiNode
                 material:aiMaterial
              textureType:aiTextureType_LIGHTMAP
            withSceneNode:sceneNode
              scnMaterial:material
                modelPath:modelPath
                  testLog:testLog];
    }
}

#pragma mark - Check lights

- (void)checkLights:(const struct aiScene *)aiScene
          withScene:(SCNAssimpScene *)scene
            testLog:(ModelLog *)testLog
{
    for (int i = 0; i < aiScene->mNumLights; i++)
    {
        const struct aiLight *aiLight = aiScene->mLights[i];
        const struct aiString aiLightNodeName = aiLight->mName;
        NSString *lightNodeName = [NSString
            stringWithUTF8String:(const char *_Nonnull) & aiLightNodeName.data];
        SCNNode *lightNode =
            [scene.rootNode childNodeWithName:lightNodeName recursively:YES];
        if (lightNode == nil)
        {
            NSString *errorLog =
                [NSString stringWithFormat:@"The light node %@ does not exist",
                                           lightNodeName];
            [testLog addErrorLog:errorLog];
        }
        SCNLight *light = lightNode.light;
        if (light == nil)
        {
            NSString *errorLog = [NSString
                stringWithFormat:@"The light node does not have light"];
            [testLog addErrorLog:errorLog];
        }
        if (aiLight->mType == aiLightSource_DIRECTIONAL)
        {
            if (![light.type isEqualToString:SCNLightTypeDirectional])
            {
                NSString *errorLog = @"The light type is not directional light";
                [testLog addErrorLog:errorLog];
            }
        }
        else if (aiLight->mType == aiLightSource_POINT)
        {
            if (![light.type isEqualToString:SCNLightTypeOmni])
            {
                NSString *errorLog = @"The light type is not point light";
                [testLog addErrorLog:errorLog];
            }
        }
        else if (aiLight->mType == aiLightSource_SPOT)
        {
            if (![light.type isEqualToString:SCNLightTypeSpot])
            {
                NSString *errorLog = @"The light type is not spot light";
                [testLog addErrorLog:errorLog];
            }
        }
    }
}

#pragma mark - Check node

- (void)checkNode:(const struct aiNode *)aiNode
    withSceneNode:(SCNNode *)sceneNode
          aiScene:(const struct aiScene *)aiScene
        modelPath:(NSString *)modelPath
          testLog:(ModelLog *)testLog
{
    const struct aiString *aiNodeName = &aiNode->mName;
    NSString *nodeName =
        [NSString stringWithUTF8String:(const char *)&aiNodeName->data];
    if (![nodeName isEqualToString:sceneNode.name])
    {
        NSString *errorLog =
            [NSString stringWithFormat:@"aiNode %@ does not match SCNNode %@",
                                       nodeName, sceneNode.name];
        [testLog addErrorLog:errorLog];
    }
    if (aiNode->mNumMeshes > 0)
    {
        [self checkNodeGeometry:aiNode
                       nodeName:nodeName
                  withSceneNode:sceneNode
                        aiScene:aiScene
                        testLog:testLog];
        [self checkNodeMaterials:aiNode
                        nodeName:nodeName
                   withSceneNode:sceneNode
                         aiScene:aiScene
                       modelPath:modelPath
                         testLog:testLog];
    }
    for (int i = 0; i < aiNode->mNumChildren; i++)
    {
        const struct aiNode *aiChildNode = aiNode->mChildren[i];
        SCNNode *sceneChildNode = [sceneNode.childNodes objectAtIndex:i];
        [self checkNode:aiChildNode
            withSceneNode:sceneChildNode
                  aiScene:aiScene
                modelPath:modelPath
                  testLog:testLog];
    }
}

#pragma mark - Check cameras

- (void)checkCameras:(const struct aiScene *)aiScene
           withScene:(SCNAssimpScene *)scene
             testLog:(ModelLog *)testLog
{
    for (int i = 0; i < aiScene->mNumCameras; i++)
    {
        const struct aiCamera *aiCamera = aiScene->mCameras[i];
        const struct aiString aiCameraName = aiCamera->mName;
        NSString *cameraNodeName = [NSString
            stringWithUTF8String:(const char *_Nonnull) & aiCameraName.data];
        SCNNode *cameraNode =
            [scene.rootNode childNodeWithName:cameraNodeName recursively:YES];
        if (cameraNode == nil)
        {
            NSString *errorLog =
                [NSString stringWithFormat:@"The camera node %@ does not exist",
                                           cameraNode];
            [testLog addErrorLog:errorLog];
        }
        SCNCamera *camera = cameraNode.camera;
        if (camera == nil)
        {
            NSString *errorLog = @"The camera node does not have a camera";
            [testLog addErrorLog:errorLog];
        }
    }
}

#pragma mark - Check animations

- (void)checkPositionChannels:(const struct aiNodeAnim *)aiNodeAnim
                  aiAnimation:(const struct aiAnimation *)aiAnimation
                  channelKeys:(NSDictionary *)channelKeys
                     duration:(float)duration
                      testLog:(ModelLog *)testLog
{
    if (aiNodeAnim->mNumPositionKeys > 0)
    {
        CAKeyframeAnimation *posAnim = [channelKeys valueForKey:@"position"];
        if (posAnim.keyTimes.count != aiNodeAnim->mNumPositionKeys)
        {
            NSString *errorLog =
                [NSString stringWithFormat:@"The position animation contains "
                                           @"%lu channel key "
                                           @"times "
                                           @"instead of %d key times",
                                           posAnim.keyTimes.count,
                                           aiNodeAnim->mNumPositionKeys];
            [testLog addErrorLog:errorLog];
        }
        if (posAnim.values.count != aiNodeAnim->mNumPositionKeys)
        {
            NSString *errorLog =
                [NSString stringWithFormat:@"The position animation contains "
                                           @"%lu channel key "
                                           @"values "
                                           @"instead of %d key values",
                                           posAnim.values.count,
                                           aiNodeAnim->mNumPositionKeys];
            [testLog addErrorLog:errorLog];
        }
        if (posAnim.speed != 1)
        {
            NSString *errorLog = @"The position animation speed is not 1";
            [testLog addErrorLog:errorLog];
        }
        if (posAnim.duration != duration)
        {
            NSString *errorLog = [NSString
                stringWithFormat:@"The position animation duration is not %f",
                                 duration];
            [testLog addErrorLog:errorLog];
        }
        for (int k = 0; k < aiNodeAnim->mNumPositionKeys; k++)
        {
            const struct aiVectorKey *aiTranslationKey =
                &aiNodeAnim->mPositionKeys[k];
            const struct aiVector3D aiTranslation = aiTranslationKey->mValue;
            SCNVector3 posKey =
                [[posAnim.values objectAtIndex:k] SCNVector3Value];
            if (posKey.x != aiTranslation.x)
            {
                NSString *errorLog = [NSString
                    stringWithFormat:@"The channel num %d key has pos.x "
                                     @"value %f instead of %f",
                                     k, posKey.x, aiTranslation.x];
                [testLog addErrorLog:errorLog];
            }
            if (posKey.y != aiTranslation.y)
            {
                NSString *errorLog = [NSString
                    stringWithFormat:@"The channel num %d key has pos.y "
                                     @"value %f instead of %f",
                                     k, posKey.y, aiTranslation.y];
                [testLog addErrorLog:errorLog];
            }
            if (posKey.z != aiTranslation.z)
            {
                NSString *errorLog = [NSString
                    stringWithFormat:@"The channel num %d key has pos.z "
                                     @"value %f instead of %f",
                                     k, posKey.z, aiTranslation.z];
                [testLog addErrorLog:errorLog];
            }
            NSNumber *keyTime = [posAnim.keyTimes objectAtIndex:k];
            if (keyTime.floatValue != aiTranslationKey->mTime)
            {
                NSString *errorLog =
                    [NSString stringWithFormat:@"The channel num %d key has %f "
                                               @"key time instead "
                                               @"of %f",
                                               k, keyTime.floatValue,
                                               aiTranslationKey->mTime];
                [testLog addErrorLog:errorLog];
            }
        }
    }
}

- (void)checkRotationChannels:(const struct aiNodeAnim *)aiNodeAnim
                  aiAnimation:(const struct aiAnimation *)aiAnimation
                  channelKeys:(NSDictionary *)channelKeys
                     duration:(float)duration
                      testLog:(ModelLog *)testLog
{
    if (aiNodeAnim->mNumRotationKeys > 0)
    {
        CAKeyframeAnimation *rotationAnim =
            [channelKeys valueForKey:@"orientation"];
        if (rotationAnim.keyTimes.count != aiNodeAnim->mNumRotationKeys)
        {
            NSString *errorLog =
                [NSString stringWithFormat:@"The position animation contains "
                                           @"%lu channel key "
                                           @"times "
                                           @"instead of %d key times",
                                           rotationAnim.keyTimes.count,
                                           aiNodeAnim->mNumRotationKeys];
            [testLog addErrorLog:testLog];
        }
        if (rotationAnim.values.count != aiNodeAnim->mNumRotationKeys)
        {
            NSString *errorLog =
                [NSString stringWithFormat:@"The position animation contains "
                                           @"%lu channel key "
                                           @"values "
                                           @"instead of %d key values",
                                           rotationAnim.values.count,
                                           aiNodeAnim->mNumRotationKeys];
            [testLog addErrorLog:errorLog];
        }
        if (rotationAnim.speed != 1)
        {
            NSString *errorLog = @"The position animation speed is not 1";
            [testLog addErrorLog:errorLog];
        }
        if (rotationAnim.duration != duration)
        {
            NSString *errorLog = [NSString
                stringWithFormat:@"The position animation duration is not %f",
                                 duration];
            [testLog addErrorLog:errorLog];
        }
        for (int k = 0; k < aiNodeAnim->mNumPositionKeys; k++)
        {
            const struct aiQuatKey *aiQuatKey = &aiNodeAnim->mRotationKeys[k];
            const struct aiQuaternion aiQuaternion = aiQuatKey->mValue;
            SCNVector4 quatKey =
                [[rotationAnim.values objectAtIndex:k] SCNVector4Value];
            if (quatKey.x != aiQuaternion.x)
            {
                NSString *errorLog = [NSString
                    stringWithFormat:@"The channel num %d key has quat.x "
                                     @"value %f instead of %f",
                                     k, quatKey.x, aiQuaternion.x];
                [testLog addErrorLog:errorLog];
            }
            if (quatKey.y != aiQuaternion.y)
            {
                NSString *errorLog = [NSString
                    stringWithFormat:@"The channel num %d key has quat.y "
                                     @"value %f instead of %f",
                                     k, quatKey.y, aiQuaternion.y];
                [testLog addErrorLog:errorLog];
            }
            if (quatKey.z != aiQuaternion.z)
            {
                NSString *errorLog = [NSString
                    stringWithFormat:@"The channel num %d key has quat.z "
                                     @"value %f instead of %f",
                                     k, quatKey.z, aiQuaternion.z];
                [testLog addErrorLog:errorLog];
            }
            if (quatKey.w != aiQuaternion.w)
            {
                NSString *errorLog = [NSString
                    stringWithFormat:@"The channel num %d key has quat.w "
                                     @"value %f instead of %f",
                                     k, quatKey.w, aiQuaternion.w];
                [testLog addErrorLog:errorLog];
            }
            NSNumber *keyTime = [rotationAnim.keyTimes objectAtIndex:k];
            if (keyTime.floatValue != aiQuatKey->mTime)
            {
                NSString *errorLog = [NSString
                    stringWithFormat:@"The channel num %d key has %f "
                                     @"key time instead "
                                     @"of %f",
                                     k, keyTime.floatValue, aiQuatKey->mTime];
                [testLog addErrorLog:errorLog];
            }
        }
    }
}

- (void)checkScalingChannels:(const struct aiNodeAnim *)aiNodeAnim
                 aiAnimation:(const struct aiAnimation *)aiAnimation
                 channelKeys:(NSDictionary *)channelKeys
                    duration:(float)duration
                     testLog:(ModelLog *)testLog
{
    if (aiNodeAnim->mNumScalingKeys > 0)
    {
        CAKeyframeAnimation *scaleAnim = [channelKeys valueForKey:@"position"];
        if (scaleAnim.keyTimes.count != aiNodeAnim->mNumPositionKeys)
        {
            NSString *errorLog =
                [NSString stringWithFormat:@"The position animation contains "
                                           @"%lu channel key "
                                           @"times "
                                           @"instead of %d key times",
                                           scaleAnim.keyTimes.count,
                                           aiNodeAnim->mNumPositionKeys];
            [testLog addErrorLog:errorLog];
        }
        if (scaleAnim.values.count != aiNodeAnim->mNumPositionKeys)
        {
            NSString *errorLog =
                [NSString stringWithFormat:@"The position animation contains "
                                           @"%lu channel key "
                                           @"values "
                                           @"instead of %d key values",
                                           scaleAnim.values.count,
                                           aiNodeAnim->mNumPositionKeys];
            [testLog addErrorLog:errorLog];
        }
        if (scaleAnim.speed != 1)
        {
            NSString *errorLog = @"The position animation speed is not 1";
            [testLog addErrorLog:errorLog];
        }
        if (scaleAnim.duration != duration)
        {
            NSString *errorLog = [NSString
                stringWithFormat:@"The position animation duration is not %f",
                                 duration];
            [testLog addErrorLog:errorLog];
        }
        for (int k = 0; k < aiNodeAnim->mNumPositionKeys; k++)
        {
            const struct aiVectorKey *aiScaleKey =
                &aiNodeAnim->mPositionKeys[k];
            const struct aiVector3D aiScale = aiScaleKey->mValue;
            SCNVector3 scaleKey =
                [[scaleAnim.values objectAtIndex:k] SCNVector3Value];
            if (scaleKey.x != aiScale.x)
            {
                NSString *errorLog = [NSString
                    stringWithFormat:@"The channel num %d key has pos.x "
                                     @"value %f instead of %f",
                                     k, scaleKey.x, aiScale.x];
                [testLog addErrorLog:errorLog];
            }
            if (scaleKey.y != aiScale.y)
            {
                NSString *errorLog = [NSString
                    stringWithFormat:@"The channel num %d key has pos.y "
                                     @"value %f instead of %f",
                                     k, scaleKey.y, aiScale.y];
                [testLog addErrorLog:errorLog];
            }
            if (scaleKey.z != aiScale.z)
            {
                NSString *errorLog = [NSString
                    stringWithFormat:@"The channel num %d key has pos.z "
                                     @"value %f instead of %f",
                                     k, scaleKey.z, aiScale.z];
                [testLog addErrorLog:errorLog];
            }
            NSNumber *keyTime = [scaleAnim.keyTimes objectAtIndex:k];
            if (keyTime.floatValue != aiScaleKey->mTime)
            {
                NSString *errorLog = [NSString
                    stringWithFormat:@"The channel num %d key has %f "
                                     @"key time instead "
                                     @"of %f",
                                     k, keyTime.floatValue, aiScaleKey->mTime];
                [testLog addErrorLog:errorLog];
            }
        }
    }
}
- (void)checkAnimations:(const struct aiScene *)aiScene
              withScene:(SCNAssimpScene *)scene
              modelPath:(NSString *)modelPath
                testLog:(ModelLog *)testLog
{
    if (aiScene->mNumAnimations > 0)
    {
        for (int i = 0; i < aiScene->mNumAnimations; i++)
        {
            NSInteger actualAnimations = scene.animations.allKeys.count;
            int expectedAnimations = aiScene->mNumAnimations;
            if (actualAnimations != expectedAnimations)
            {
                NSString *errorLog = [NSString
                    stringWithFormat:@"The scene contains %ld animations "
                                     @"instead of expected %d animations",
                                     (long)actualAnimations,
                                     expectedAnimations];
                [testLog addErrorLog:errorLog];
            }
            const struct aiAnimation *aiAnimation = aiScene->mAnimations[i];
            NSString *animKey = [[[modelPath lastPathComponent]
                stringByDeletingPathExtension] stringByAppendingString:@"-1"];
            SCNAssimpAnimation *animation = [scene animationForKey:animKey];
            if (animation == nil)
            {
                NSString *errorLog = [NSString
                    stringWithFormat:
                        @"The scene does not contain animation with key %@",
                        animKey];
                [testLog addErrorLog:errorLog];
            }
            if (![animation.key isEqualToString:animKey])
            {
                NSString *errorLog = [NSString
                    stringWithFormat:
                        @"The animation does not have the correct key %@",
                        animKey];
                [testLog addErrorLog:errorLog];
            }
            for (int j = 0; j < aiAnimation->mNumChannels; j++)
            {
                const struct aiNodeAnim *aiNodeAnim = aiAnimation->mChannels[j];
                const struct aiString *aiNodeName = &aiNodeAnim->mNodeName;
                NSString *name =
                    [NSString stringWithUTF8String:aiNodeName->data];
                NSDictionary *channelKeys =
                    [animation.frameAnims valueForKey:name];
                if (channelKeys == nil)
                {
                    NSString *errorLog = [NSString
                        stringWithFormat:@"The channel keys for bone %@ "
                                         @"channel does not exist",
                                         name];
                    [testLog addErrorLog:errorLog];
                }

                float duration;
                if (aiAnimation->mTicksPerSecond != 0)
                {
                    duration =
                        aiAnimation->mDuration / aiAnimation->mTicksPerSecond;
                }
                else
                {
                    duration = aiAnimation->mDuration;
                }

                [self checkPositionChannels:aiNodeAnim
                                aiAnimation:aiAnimation
                                channelKeys:channelKeys
                                   duration:duration
                                    testLog:testLog];

                [self checkRotationChannels:aiNodeAnim
                                aiAnimation:aiAnimation
                                channelKeys:channelKeys
                                   duration:duration
                                    testLog:testLog];

                [self checkScalingChannels:aiNodeAnim
                               aiAnimation:aiAnimation
                               channelKeys:channelKeys
                                  duration:duration
                                   testLog:testLog];
            }
        }
    }
}

#pragma mark - Check model

- (void)checkModel:(NSString *)path testLog:(ModelLog *)testLog
{
    const char *pFile = [path UTF8String];
    const struct aiScene *aiScene = aiImportFile(pFile, aiProcess_FlipUVs);
    // If the import failed, report it
    if (!aiScene)
    {
        NSString *errorString =
            [NSString stringWithUTF8String:aiGetErrorString()];
        [testLog addErrorLog:errorString];
        return;
    }

    AssimpImporter *importer = [[AssimpImporter alloc] init];
    SCNAssimpScene *scene = [importer importScene:path];

    [self checkNode:aiScene->mRootNode
        withSceneNode:[scene.rootNode.childNodes objectAtIndex:0]
              aiScene:aiScene
            modelPath:path
              testLog:testLog];

    [self checkLights:aiScene withScene:scene testLog:testLog];

    [self checkCameras:aiScene withScene:scene testLog:testLog];

    [self checkAnimations:aiScene
                withScene:scene
                modelPath:path
                  testLog:testLog];
}

#pragma mark - Test all models

- (NSArray *)getModelFiles
{
    // -------------------------------------------------------------
    // All asset directories by owner: Apple, OpenFrameworks, Assimp
    // -------------------------------------------------------------
    NSString *appleAssets =
        [self.testAssetsPath stringByAppendingString:@"/apple"];
    NSString *ofAssets = [self.testAssetsPath stringByAppendingString:@"/of"];
    NSString *assimpAssets =
        [self.testAssetsPath stringByAppendingString:@"/assimp"];
    NSArray *assetDirs =
        [NSArray arrayWithObjects:appleAssets, ofAssets, assimpAssets, nil];

    // ---------------------------------------------------------
    // Asset subdirectories sorted by open and proprietary files
    // ---------------------------------------------------------
    NSArray *subDirs =
        [NSArray arrayWithObjects:@"/models", @"/models-proprietary", nil];

    // ------------------------------------------------------
    // Read the valid extensions that are currently supported
    // ------------------------------------------------------
    NSString *validExtsFile =
        [self.testAssetsPath stringByAppendingString:@"/valid-extensions.txt"];
    NSArray *validExts = [[NSString
        stringWithContentsOfFile:validExtsFile
                        encoding:NSUTF8StringEncoding
                           error:nil] componentsSeparatedByString:@"\n"];

    // -----------------------------------------------
    // Generate a list of model files that we can test
    // -----------------------------------------------
    NSMutableArray *modelFilePaths = [[NSMutableArray alloc] init];
    NSFileManager *fileManager = [NSFileManager defaultManager];

    for (NSString *assetDir in assetDirs)
    {
        for (NSString *subDir in subDirs)
        {
            NSString *assetSubDir = [assetDir stringByAppendingString:subDir];
            NSLog(@"========== Scanning asset dir: %@", assetSubDir);
            NSMutableArray *modelFiles =
                [fileManager subpathsOfDirectoryAtPath:assetSubDir error:nil];
            for (NSString *modelFile in modelFiles)
            {
                BOOL isDir = NO;
                NSString *modelFilePath =
                    [[assetSubDir stringByAppendingString:@"/"]
                        stringByAppendingString:modelFile];

                if ([fileManager fileExistsAtPath:modelFilePath
                                      isDirectory:&isDir])
                {
                    if (!isDir)
                    {
                        NSString *fileExt =
                            [[modelFilePath lastPathComponent] pathExtension];
                        if (![fileExt isEqualToString:@""] &&
                            ([validExts
                                 containsObject:fileExt.uppercaseString] ||
                             [validExts
                                 containsObject:fileExt.lowercaseString]))
                        {
                            [modelFilePaths addObject:modelFilePath];
                        }
                    }
                }
            }
        }
    }

    return modelFilePaths;
}

- (void)testAssimpModelFormats
{
    int numFilesTested = 0;
    int numFilesPassed = 0;
    NSArray *modelFiles = [self getModelFiles];
    for (NSString *modelFilePath in modelFiles)
    {
        NSLog(@"$$$$$$$$$$$ TESTING %@ file", modelFilePath);
        ModelLog *testLog = [[ModelLog alloc] init];
        [self checkModel:modelFilePath testLog:testLog];
        ++numFilesTested;
        if ([testLog testPassed])
        {
            ++numFilesPassed;
        }
        else
        {
            NSLog(@" The model testing failed with "
                  @"errors: %@",
                  [testLog getErrors]);
        }
    }
    float passPercent = numFilesPassed * 100.0 / numFilesTested;
    NSLog(@" NUM OF FILES TESTED             : %d", numFilesTested);
    NSLog(@" NUM OF FILES PASSED VERIFICATION: %d", numFilesPassed);
    NSLog(@" PASS PERCENT                    : %f", passPercent);
    XCTAssertGreaterThan(passPercent, 90,
                         @"The 3D file format model test verification is %f "
                         @"instead of the expected > 90 percent",
                         passPercent);
}

@end
