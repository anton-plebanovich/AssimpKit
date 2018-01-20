
/*
 ---------------------------------------------------------------------------
 Assimp to Scene Kit Library (AssimpKit)
 ---------------------------------------------------------------------------
 Copyright (c) 2016-17, Deepak Surti, Ison Apps, AssimpKit team
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
 * Neither the name of the AssimpKit team, nor the names of its
 contributors may be used to endorse or promote products
 derived from this software without specific prior
 written permission of the AssimpKit team.
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

static NSArray<NSURL *> *c_folders = nil;

#import "SCNTextureInfo.h"
#import <ImageIO/ImageIO.h>
#import <CoreImage/CoreImage.h>

@interface SCNTextureInfo ()

@property (nonatomic) NSURL *baseURL;

#pragma mark - Texture material

/**
 The material name which is the owner of this texture.
 */
@property (nonatomic, readwrite) NSString *materialName;

#pragma mark - Texture color and resources

/**
 A Boolean value that determines whether a color is applied to a material 
 property.
 */
@property bool applyColor;

/**
 The actual color to be applied to a material property.
 */
@property CGColorRef color;

/**
 A profile that specifies the interpretation of a color to be applied to
 a material property.
 */
@property CGColorSpaceRef colorSpace;

#pragma mark - Embedded texture

/**
 A Boolean value that determines if embedded texture is applied to a
 material property.
 */
@property bool applyEmbeddedTexture;

/**
 The index of the embedded texture in the array of assimp scene textures.
 */
@property int embeddedTextureIndex;

#pragma mark - External texture

/**
 A Boolean value that determines if an external texture is applied to a 
 material property.
 */
@property bool applyExternalTexture;

/**
 The path to the external texture resource on the disk.
 */
@property NSString* externalTexturePath;

#pragma mark - Texture image resources

/**
 An opaque type that represents the external texture image source.
 */
@property CGImageSourceRef imageSource;


/**
 An abstraction for the raw image data of an embedded texture image source that 
 eliminates the need to manage raw memory buffer.
 */
@property CGDataProviderRef imageDataProvider;


/**
 A bitmap image representing either an external or embedded texture applied to 
 a material property.
 */
@property CGImageRef image;

@end

#pragma mark -

@implementation SCNTextureInfo

+ (void)setTexturesFolders:(NSArray<NSURL *> *)folders {
    c_folders = folders;
}

#pragma mark - Creating a texture info

/**
 Create a texture metadata object for a material property.
 
 @param aiMeshIndex The index of the mesh to which this texture is applied.
 @param aiTextureType The texture type: diffuse, specular etc.
 @param aiScene The assimp scene.
 @param path The path to the scene file to load.
 @return A new texture info.
 */
-(instancetype)initWithMeshIndex:(int)aiMeshIndex
                         baseURL:(NSURL *)baseURL
                     textureType:(enum aiTextureType)aiTextureType
                         inScene:(const struct aiScene *)aiScene
                          atPath:(NSString*)path
{
    self = [super init];
    if(self) {
        self.baseURL = baseURL;
        self.imageSource = NULL;
        self.imageDataProvider = NULL;
        self.image = NULL;
        self.colorSpace = NULL;
        self.color = NULL;
        const struct aiMesh *aiMesh = aiScene->mMeshes[aiMeshIndex];
        const struct aiMaterial *aiMaterial =
            aiScene->mMaterials[aiMesh->mMaterialIndex];
        struct aiString name;
        aiGetMaterialString(aiMaterial, AI_MATKEY_NAME, &name);
        self.textureType = aiTextureType;
        self.materialName =
            [NSString stringWithUTF8String:(const char *_Nonnull) & name.data];
        DLog(@" Material name is %@", self.materialName);
        [self checkTextureTypeForMaterial:aiMaterial
                          withTextureType:aiTextureType
                                  inScene:aiScene
                                   atPath:path];
        return self;
    }
    return nil;
}

#pragma mark - Inspect texture metadata

/**
 Inspects the material texture properties to determine if color, embedded 
 texture or external texture should be applied to the material property.

 @param aiMaterial The assimp material.
 @param aiTextureType The material property: diffuse, specular etc.
 @param aiScene The assimp scene.
 @param path The path to the scene file to load.
 */
- (void)checkTextureTypeForMaterial:(const struct aiMaterial *)aiMaterial
                    withTextureType:(enum aiTextureType)aiTextureType
                            inScene:(const struct aiScene *)aiScene
                             atPath:(NSString *)path
{
    int nTextures = aiGetMaterialTextureCount(aiMaterial, aiTextureType);
    DLog(@" has textures : %d", nTextures);
    DLog(@" has embedded textures: %d", aiScene->mNumTextures);
    if(nTextures == 0 && aiScene->mNumTextures == 0) {
        self.applyColor = true;
        [self extractColorForMaterial:aiMaterial
                      withTextureType:aiTextureType];
    }
    else
    {
        if(nTextures == 0) {
            self.applyColor = true;
            [self extractColorForMaterial:aiMaterial
                          withTextureType:aiTextureType];
        }
        else
        {
            struct aiString aiPath;
            aiGetMaterialTexture(aiMaterial, aiTextureType, 0, &aiPath, NULL, NULL,
                                 NULL, NULL, NULL, NULL);
            NSString *texFilePath = [NSString
                stringWithUTF8String:(const char *_Nonnull) & aiPath.data];
            DLog(@" tex file path is: %@", texFilePath);
            NSString *texFileName = [texFilePath lastPathComponent];
            
            if(texFileName == nil || [texFileName isEqualToString:@""]) {
                self.applyColor = true;
                [self extractColorForMaterial:aiMaterial
                              withTextureType:aiTextureType];
            }
            else if ([texFileName hasPrefix:@"*"] && aiScene->mNumTextures > 0)
            {
                self.applyEmbeddedTexture = true;
                self.embeddedTextureIndex =
                [texFilePath substringFromIndex:1].intValue;
                DLog(@" Embedded texture index : %d", self.embeddedTextureIndex);
                [self generateCGImageForEmbeddedTextureAtIndex:self.embeddedTextureIndex
                    inScene:aiScene];
            }
            else {
                self.applyExternalTexture = true;
                DLog(@"  tex file name is %@", texFileName);
                NSString *sceneDir = [[path stringByDeletingLastPathComponent]
                    stringByAppendingString:@"/"];
                NSURL *baseURL = [NSURL fileURLWithPath:sceneDir];
                self.externalTexturePath = [self generateCGImageForExternalTextureAtBaseURL:baseURL fileName:texFileName];
            }
        }
    }
}

#pragma mark - Generate textures

/**
 Generates a bitmap image representing the embedded texture.

 @param index The index of the texture in assimp scene's textures.
 @param aiScene The assimp scene.
 */
- (void)generateCGImageForEmbeddedTextureAtIndex:(int)index
                                         inScene:(const struct aiScene *)aiScene
{
    DLog(@" Generating embedded texture ");
    const struct aiTexture *aiTexture = aiScene->mTextures[index];
    NSData *imageData = [NSData dataWithBytes:aiTexture->pcData
                                       length:aiTexture->mWidth];
    self.imageDataProvider =
        CGDataProviderCreateWithCFData((CFDataRef)imageData);
    NSString* format = [NSString stringWithUTF8String:aiTexture->achFormatHint];
    if([format isEqualToString:@"png"]) {
        DLog(@" Created png embedded texture ");
        self.image = CGImageCreateWithPNGDataProvider(
            self.imageDataProvider, NULL, true, kCGRenderingIntentDefault);
    }
    if([format isEqualToString:@"jpg"]) {
        DLog(@" Created jpg embedded texture");
        self.image = CGImageCreateWithJPEGDataProvider(
            self.imageDataProvider, NULL, true, kCGRenderingIntentDefault);
    }
}

- (NSString *)generateCGImageForExternalTextureAtBaseURL:(NSURL *)baseURL fileName:(NSString *)_fileName {
    NSString *fileName = [_fileName componentsSeparatedByString:@"\\"].lastObject.lowercaseString;
    
    DLog(@" Generating external texture");
    NSURL *realImageUrl = [self getFilePathWithBaseURL:baseURL fileName:fileName];
    
    if (!realImageUrl && [fileName containsString:@"_"]) {
        NSString *fixedFileName = [fileName stringByReplacingOccurrencesOfString:@"_" withString:@"-"];
        realImageUrl = [self getFilePathWithBaseURL:baseURL fileName:fixedFileName];
    }
    
    self.imageSource = CGImageSourceCreateWithURL((CFURLRef)realImageUrl, NULL);
    self.image = CGImageSourceCreateImageAtIndex(self.imageSource, 0, NULL);
    
    return realImageUrl.path;
}

- (NSURL *)getFilePathWithBaseURL:(NSURL *)baseURL fileName:(NSString *)fileName {
    NSURL *fileURL = [self getFilePathRecursiveWithBaseURL:baseURL fileName:fileName];
    if (fileURL) {
        return fileURL;
    }
    
    // Check baseURL
    if (self.baseURL) {
        if (![self.baseURL isEqual:baseURL]) {
            if (self.baseURL.hasDirectoryPath) {
                NSURL *fileUrl = [self getFilePathRecursiveWithBaseURL:self.baseURL fileName:fileName];
                if (fileUrl) {
                    return fileUrl;
                }
            } else {
                if ([self.baseURL.lastPathComponent.lowercaseString isEqualToString:fileName]) {
                    return self.baseURL;
                }
            }
        }
    }
    
    // Check additional folders
    for (NSURL *folder in c_folders) {
        if ([folder isEqual:baseURL]) {
            continue;
        }
        
        if (!folder.hasDirectoryPath) {
            if ([folder.lastPathComponent.lowercaseString isEqualToString:fileName]) {
                return folder;
            } else {
                continue;
            }
        }
        
        NSURL *fileUrl = [self getFilePathRecursiveWithBaseURL:folder fileName:fileName];
        if (fileUrl) {
            return fileUrl;
        }
    }
    
    return nil;
}

- (NSURL *)getFilePathRecursiveWithBaseURL:(NSURL *)baseURL fileName:(NSString *)fileName {
    NSArray<NSURL *> *contents = [NSFileManager.defaultManager contentsOfDirectoryAtURL:baseURL includingPropertiesForKeys:nil options:0 error:nil];
    
    // Check files first
    for (NSURL *content in contents) {
        if (content.hasDirectoryPath) {
            continue;
        }
        
        if ([content.lastPathComponent.lowercaseString hasPrefix:fileName]) {
            return content;
        }
    }
    
    // Check subdirectories
    for (NSURL *content in contents) {
        if (!content.hasDirectoryPath) {
            continue;
        }
        
        NSURL *fileUrl = [self getFilePathRecursiveWithBaseURL:content fileName:fileName];
        if (fileUrl) {
            return fileUrl;
        }
    }
    
    return nil;
}

#pragma mark - Extract color

-(void)extractColorForMaterial:(const struct aiMaterial *)aiMaterial
                      withTextureType:(enum aiTextureType)aiTextureType
{
    DLog(@" Extracting color");
    struct aiColor4D color;
    color.r = 0.0f;
    color.g = 0.0f;
    color.b = 0.0f;
    int matColor = -100;
    if(aiTextureType == aiTextureType_DIFFUSE) {
        matColor =
        aiGetMaterialColor(aiMaterial, AI_MATKEY_COLOR_DIFFUSE, &color);
    }
    if(aiTextureType == aiTextureType_SPECULAR) {
        matColor =
        aiGetMaterialColor(aiMaterial, AI_MATKEY_COLOR_SPECULAR, &color);
    }
    if(aiTextureType == aiTextureType_AMBIENT) {
        matColor =
        aiGetMaterialColor(aiMaterial, AI_MATKEY_COLOR_AMBIENT, &color);
    }
    if(aiTextureType == aiTextureType_REFLECTION) {
        matColor =
        aiGetMaterialColor(aiMaterial, AI_MATKEY_COLOR_REFLECTIVE, &color);
    }
    if(aiTextureType == aiTextureType_EMISSIVE) {
        matColor =
        aiGetMaterialColor(aiMaterial, AI_MATKEY_COLOR_EMISSIVE, &color);
    }
    if(aiTextureType == aiTextureType_OPACITY) {
        matColor =
        aiGetMaterialColor(aiMaterial, AI_MATKEY_COLOR_TRANSPARENT, &color);
    }
    if (AI_SUCCESS == matColor)
    {
            self.colorSpace = CGColorSpaceCreateDeviceRGB();
            CGFloat components[4] = {color.r, color.g, color.b, color.a};
            self.color = CGColorCreate(self.colorSpace, components);
    }
}

#pragma mark - Texture resources

/**
 Returns the color or the bitmap image to be applied to the material property.

 @return Returns either a color or a bitmap image.
 */
-(id)getMaterialPropertyContents {
    if (self.applyEmbeddedTexture || self.applyExternalTexture) {
        return (id)self.image;
    } else {
        return (id)self.color;
    }
}

/**
 Releases the graphics resources used to generate color or bitmap image to be
 applied to a material property.

 This method must be called by the client to avoid memory leaks!
 */
-(void)releaseContents {
    if(self.imageSource != NULL) {
        CFRelease(self.imageSource);
    }
    if(self.imageDataProvider != NULL) {
        CGDataProviderRelease(self.imageDataProvider);
    }
    if(self.image != NULL) {
        CGImageRelease(self.image);
    }
    if(self.colorSpace != NULL)
    {
        CGColorSpaceRelease(self.colorSpace);
    }
    if(self.color != NULL) {
        CGColorRelease(self.color);
    }
}

@end
