//
//  TZImageManager.m
//  TZImagePickerController
//
//  Created by 谭真 on 16/1/4.
//  Copyright © 2016年 谭真. All rights reserved.
//

#import "TZImageManager.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import "TZAssetModel.h"
#import "TZImagePickerController.h"

@interface TZImageManager ()
@end

@implementation TZImageManager

+ (instancetype)manager {
    static TZImageManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[self alloc] init];
        manager.cachingImageManager = [[PHCachingImageManager alloc] init];
    });
    return manager;
}


/// Return YES if Authorized 返回YES如果得到了授权
- (BOOL)authorizationStatusAuthorized {
    if (iOS8Later) {
        if ([PHPhotoLibrary authorizationStatus] == PHAuthorizationStatusAuthorized) return YES;
    } else {
//        if ([ALAssetsLibrary authorizationStatus] == ALAuthorizationStatusAuthorized) return YES;
    }
    return NO;
}

#pragma mark - Get Album

/// Get Album 获得相册/相册数组
- (void)getCameraRollAlbum:(BOOL)allowPickingVideo allowPickingImage:(BOOL)allowPickingImage completion:(void (^)(TZAlbumModel *))completion{
    __block TZAlbumModel *model;
    if (iOS8Later) {
        PHFetchOptions *option = [[PHFetchOptions alloc] init];
        if (!allowPickingVideo) option.predicate = [NSPredicate predicateWithFormat:@"mediaType == %ld", PHAssetMediaTypeImage];
        if (!allowPickingImage) option.predicate = [NSPredicate predicateWithFormat:@"mediaType == %ld",
                                                    PHAssetMediaTypeVideo];
        option.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:YES]];
        
        PHFetchResult *smartAlbums = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum subtype:PHAssetCollectionSubtypeSmartAlbumUserLibrary options:nil];
        for (PHAssetCollection *collection in smartAlbums) {
            if ([collection.localizedTitle isEqualToString:@"Camera Roll"] || [collection.localizedTitle isEqualToString:@"相机胶卷"] ||  [collection.localizedTitle isEqualToString:@"所有照片"]) {
                PHFetchResult *fetchResult = [PHAsset fetchAssetsInAssetCollection:collection options:option];
                model = [self modelWithResult:fetchResult name:collection.localizedTitle];
                if (completion) completion(model);
                break;
            }
        }
    }

}

- (void)getAllAlbums:(BOOL)allowPickingVideo allowPickingImage:(BOOL)allowPickingImage completion:(void (^)(NSArray<TZAlbumModel *> *))completion{
    NSMutableArray *albumArr = [NSMutableArray array];
    if (iOS8Later) {
        PHFetchOptions *option = [[PHFetchOptions alloc] init];
        if (!allowPickingVideo) option.predicate = [NSPredicate predicateWithFormat:@"mediaType == %ld", PHAssetMediaTypeImage];
        if (!allowPickingImage) option.predicate = [NSPredicate predicateWithFormat:@"mediaType == %ld",
                                                    PHAssetMediaTypeVideo];
        option.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:YES]];
        
        PHAssetCollectionSubtype smartAlbumSubtype = PHAssetCollectionSubtypeSmartAlbumUserLibrary | PHAssetCollectionSubtypeSmartAlbumRecentlyAdded | PHAssetCollectionSubtypeSmartAlbumVideos;
        // For iOS 9, We need to show ScreenShots Album && SelfPortraits Album
        if (iOS9Later) {
            smartAlbumSubtype = PHAssetCollectionSubtypeSmartAlbumUserLibrary | PHAssetCollectionSubtypeSmartAlbumRecentlyAdded | PHAssetCollectionSubtypeSmartAlbumScreenshots | PHAssetCollectionSubtypeSmartAlbumSelfPortraits | PHAssetCollectionSubtypeSmartAlbumVideos;
        }
        PHFetchResult *smartAlbums = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum subtype:smartAlbumSubtype options:nil];
        for (PHAssetCollection *collection in smartAlbums) {
            PHFetchResult *fetchResult = [PHAsset fetchAssetsInAssetCollection:collection options:option];
            if (fetchResult.count < 1) continue;
            if ([collection.localizedTitle containsString:@"Deleted"] || [collection.localizedTitle isEqualToString:@"最近删除"]) continue;
            if ([collection.localizedTitle isEqualToString:@"Camera Roll"] || [collection.localizedTitle isEqualToString:@"相机胶卷"]) {
                [albumArr insertObject:[self modelWithResult:fetchResult name:collection.localizedTitle] atIndex:0];
            } else {
                [albumArr addObject:[self modelWithResult:fetchResult name:collection.localizedTitle]];
            }
        }
        
        PHFetchResult *albums = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeAlbum subtype:PHAssetCollectionSubtypeAlbumRegular | PHAssetCollectionSubtypeAlbumSyncedAlbum options:nil];
        for (PHAssetCollection *collection in albums) {
            PHFetchResult *fetchResult = [PHAsset fetchAssetsInAssetCollection:collection options:option];
            if (fetchResult.count < 1) continue;
            if ([collection.localizedTitle isEqualToString:@"My Photo Stream"] || [collection.localizedTitle isEqualToString:@"我的照片流"]) {
                [albumArr insertObject:[self modelWithResult:fetchResult name:collection.localizedTitle] atIndex:1];
            } else {
                [albumArr addObject:[self modelWithResult:fetchResult name:collection.localizedTitle]];
            }
        }
        if (completion && albumArr.count > 0) completion(albumArr);
    }

}

#pragma mark - Get Assets

/// Get Assets 获得照片数组
- (void)getAssetsFromFetchResult:(id)result allowPickingVideo:(BOOL)allowPickingVideo allowPickingImage:(BOOL)allowPickingImage completion:(void (^)(NSArray<TZAssetModel *> *))completion {
    NSMutableArray *photoArr = [NSMutableArray array];
    if ([result isKindOfClass:[PHFetchResult class]]) {
        PHFetchResult *fetchResult = (PHFetchResult *)result;
        [fetchResult enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            PHAsset *asset = (PHAsset *)obj;
            TZAssetModelMediaType type = TZAssetModelMediaTypePhoto;
            if (asset.mediaType == PHAssetMediaTypeVideo)      type = TZAssetModelMediaTypeVideo;
            else if (asset.mediaType == PHAssetMediaTypeAudio) type = TZAssetModelMediaTypeAudio;
            else if (asset.mediaType == PHAssetMediaTypeImage) {
                if (iOS9_1Later) {
                    // if (asset.mediaSubtypes == PHAssetMediaSubtypePhotoLive) type = TZAssetModelMediaTypeLivePhoto;
                }
            }
            if (!allowPickingVideo && type == TZAssetModelMediaTypeVideo) return;
            if (!allowPickingImage && type == TZAssetModelMediaTypePhoto) return;
            
            NSString *timeLength = type == TZAssetModelMediaTypeVideo ? [NSString stringWithFormat:@"%0.0f",asset.duration] : @"";
            timeLength = [self getNewTimeFromDurationSecond:timeLength.integerValue];
            [photoArr addObject:[TZAssetModel modelWithAsset:asset type:type timeLength:timeLength]];
        }];
        if (completion) completion(photoArr);
    }

}

///  Get asset at index 获得下标为index的单个照片
- (void)getAssetFromFetchResult:(id)result atIndex:(NSInteger)index allowPickingVideo:(BOOL)allowPickingVideo allowPickingImage:(BOOL)allowPickingImage completion:(void (^)(TZAssetModel *))completion {
    if ([result isKindOfClass:[PHFetchResult class]]) {
        PHFetchResult *fetchResult = (PHFetchResult *)result;
        PHAsset *asset = fetchResult[index];
        
        TZAssetModelMediaType type = TZAssetModelMediaTypePhoto;
        if (asset.mediaType == PHAssetMediaTypeVideo)      type = TZAssetModelMediaTypeVideo;
        else if (asset.mediaType == PHAssetMediaTypeAudio) type = TZAssetModelMediaTypeAudio;
        else if (asset.mediaType == PHAssetMediaTypeImage) {
            if (iOS9_1Later) {
                // if (asset.mediaSubtypes == PHAssetMediaSubtypePhotoLive) type = TZAssetModelMediaTypeLivePhoto;
            }
        }
        NSString *timeLength = type == TZAssetModelMediaTypeVideo ? [NSString stringWithFormat:@"%0.0f",asset.duration] : @"";
        timeLength = [self getNewTimeFromDurationSecond:timeLength.integerValue];
        TZAssetModel *model = [TZAssetModel modelWithAsset:asset type:type timeLength:timeLength];
        if (completion) completion(model);
    }
}

- (NSString *)getNewTimeFromDurationSecond:(NSInteger)duration {
    NSString *newTime;
    if (duration < 10) {
        newTime = [NSString stringWithFormat:@"0:0%zd",duration];
    } else if (duration < 60) {
        newTime = [NSString stringWithFormat:@"0:%zd",duration];
    } else {
        NSInteger min = duration / 60;
        NSInteger sec = duration - (min * 60);
        if (sec < 10) {
            newTime = [NSString stringWithFormat:@"%zd:0%zd",min,sec];
        } else {
            newTime = [NSString stringWithFormat:@"%zd:%zd",min,sec];
        }
    }
    return newTime;
}

/// Get photo bytes 获得一组照片的大小
- (void)getPhotosBytesWithArray:(NSArray *)photos completion:(void (^)(NSString *totalBytes))completion {
    __block NSInteger dataLength = 0;
    __block NSInteger assetCount = 0;
    for (NSInteger i = 0; i < photos.count; i++) {
        TZAssetModel *model = photos[i];
        if ([model.asset isKindOfClass:[PHAsset class]]) {
            [[PHImageManager defaultManager] requestImageDataForAsset:model.asset options:nil resultHandler:^(NSData * _Nullable imageData, NSString * _Nullable dataUTI, UIImageOrientation orientation, NSDictionary * _Nullable info) {
                if (model.type != TZAssetModelMediaTypeVideo) dataLength += imageData.length;
                assetCount ++;
                if (assetCount >= photos.count) {
                    NSString *bytes = [self getBytesFromDataLength:dataLength];
                    if (completion) completion(bytes);
                }
            }];
        }

    }
}

- (NSString *)getBytesFromDataLength:(NSInteger)dataLength {
    NSString *bytes;
    if (dataLength >= 0.1 * (1024 * 1024)) {
        bytes = [NSString stringWithFormat:@"%0.1fM",dataLength/1024/1024.0];
    } else if (dataLength >= 1024) {
        bytes = [NSString stringWithFormat:@"%0.0fK",dataLength/1024.0];
    } else {
        bytes = [NSString stringWithFormat:@"%zdB",dataLength];
    }
    return bytes;
}

#pragma mark - Get Photo

/// Get photo 获得照片本身
- (void)getPhotoWithAsset:(id)asset completion:(void (^)(UIImage *, NSDictionary *, BOOL isDegraded))completion {
    [self getPhotoWithAsset:asset photoWidth:[UIScreen mainScreen].bounds.size.width completion:completion];
}

- (void)getPhotoWithAsset:(id)asset photoWidth:(CGFloat)photoWidth completion:(void (^)(UIImage *, NSDictionary *, BOOL isDegraded))completion {
    if (photoWidth > 600) photoWidth = 600.0;
    if ([asset isKindOfClass:[PHAsset class]]) {
        PHAsset *phAsset = (PHAsset *)asset;
        CGFloat aspectRatio = phAsset.pixelWidth / (CGFloat)phAsset.pixelHeight;
        CGFloat multiple = [UIScreen mainScreen].scale;
        CGFloat pixelWidth = photoWidth * multiple;
        CGFloat pixelHeight = pixelWidth / aspectRatio;
        
        [[PHImageManager defaultManager] requestImageForAsset:asset targetSize:CGSizeMake(pixelWidth, pixelHeight) contentMode:PHImageContentModeAspectFit options:nil resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
            BOOL downloadFinined = (![[info objectForKey:PHImageCancelledKey] boolValue] && ![info objectForKey:PHImageErrorKey]);
            if (downloadFinined && result) {
                result = [self fixOrientation:result];
                if (completion) completion(result,info,[[info objectForKey:PHImageResultIsDegradedKey] boolValue]);
            }
            // Download image from iCloud / 从iCloud下载图片
            if ([info objectForKey:PHImageResultIsInCloudKey] && !result) {
                PHImageRequestOptions *option = [[PHImageRequestOptions alloc]init];
                option.networkAccessAllowed = YES;
                [[PHImageManager defaultManager] requestImageDataForAsset:asset options:option resultHandler:^(NSData * _Nullable imageData, NSString * _Nullable dataUTI, UIImageOrientation orientation, NSDictionary * _Nullable info) {
                    UIImage *resultImage = [UIImage imageWithData:imageData scale:0.1];
                    resultImage = [self scaleImage:resultImage toSize:CGSizeMake(pixelWidth, pixelHeight)];
                    if (resultImage) {
                        resultImage = [self fixOrientation:resultImage];
                        if (completion) completion(resultImage,info,[[info objectForKey:PHImageResultIsDegradedKey] boolValue]);
                    }
                }];
            }
        }];
    }

}

- (void)getPostImageWithAlbumModel:(TZAlbumModel *)model completion:(void (^)(UIImage *))completion {
    if (iOS8Later) {
        [[TZImageManager manager] getPhotoWithAsset:[model.result lastObject] photoWidth:80 completion:^(UIImage *photo, NSDictionary *info, BOOL isDegraded) {
            if (completion) completion(photo);
        }];
    }
//    else {
//        ALAssetsGroup *group = model.result;
//        UIImage *postImage = [UIImage imageWithCGImage:group.posterImage];
//        if (completion) completion(postImage);
//    }
}

/// Get Original Photo / 获取原图
- (void)getOriginalPhotoWithAsset:(id)asset completion:(void (^)(UIImage *photo,NSDictionary *info))completion {
    if ([asset isKindOfClass:[PHAsset class]]) {
        PHImageRequestOptions *option = [[PHImageRequestOptions alloc]init];
        option.networkAccessAllowed = YES;
        [[PHImageManager defaultManager] requestImageForAsset:asset targetSize:PHImageManagerMaximumSize contentMode:PHImageContentModeAspectFit options:option resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
            BOOL downloadFinined = (![[info objectForKey:PHImageCancelledKey] boolValue] && ![info objectForKey:PHImageErrorKey]);
            if (downloadFinined && result) {
                result = [self fixOrientation:result];
                if (completion) completion(result,info);
            }
        }];
    }

}

#pragma mark - Save photo

- (void)savePhotoWithImage:(UIImage *)image completion:(void (^)())completion {
    NSData *data = UIImageJPEGRepresentation(image, 0.9);
    if (iOS8Later) {
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            [[PHAssetCreationRequest creationRequestForAsset] addResourceWithType:PHAssetResourceTypePhoto data:data options:nil];
        } completionHandler:^(BOOL success, NSError * _Nullable error) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                if (success && completion) {
                    completion();
                } else if (error) {
                    NSLog(@"保存照片出错:%@",error.localizedDescription);
                }
            });
        }];
    }

}

#pragma mark - Get Video

//- (void)getVideoWithAsset:(id)asset completion:(void (^)(AVPlayerItem * _Nullable, NSDictionary * _Nullable))completion {
//    if ([asset isKindOfClass:[PHAsset class]]) {
//        [[PHImageManager defaultManager] requestPlayerItemForVideo:asset options:nil resultHandler:^(AVPlayerItem * _Nullable playerItem, NSDictionary * _Nullable info) {
//            if (completion) completion(playerItem,info);
//        }];
//    }
//
//}

#pragma mark - Export video

//- (void)getVideoOutputPathWithAsset:(id)asset completion:(void (^)(NSString *outputPath))completion {
//    if ([asset isKindOfClass:[PHAsset class]]) {
//        PHVideoRequestOptions* options = [[PHVideoRequestOptions alloc] init];
//        options.version = PHVideoRequestOptionsVersionOriginal;
//        options.deliveryMode = PHVideoRequestOptionsDeliveryModeAutomatic;
//        options.networkAccessAllowed = YES;
//        [[PHImageManager defaultManager] requestAVAssetForVideo:asset options:options resultHandler:^(AVAsset* avasset, AVAudioMix* audioMix, NSDictionary* info){
//            // NSLog(@"Info:\n%@",info);
//            AVURLAsset* myAsset = (AVURLAsset*)avasset;
//            // NSLog(@"AVAsset URL: %@",myAsset.URL);
//            
//            NSArray *compatiblePresets = [AVAssetExportSession exportPresetsCompatibleWithAsset:myAsset];
//            // NSLog(@"%@",compatiblePresets);
//            
//            if ([compatiblePresets containsObject:AVAssetExportPresetHighestQuality]) {
//                AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:myAsset presetName:AVAssetExportPresetMediumQuality];
//                NSDateFormatter *formater = [[NSDateFormatter alloc] init];
//                [formater setDateFormat:@"yyyy-MM-dd-HH:mm:ss"];
//                NSString *outputPath = [NSHomeDirectory() stringByAppendingFormat:@"/tmp/output-%@.mp4", [formater stringFromDate:[NSDate date]]];
//                NSLog(@"video outputPath = %@",outputPath);
//                
//                exportSession.outputURL = [NSURL fileURLWithPath:outputPath];
//                exportSession.outputFileType = AVFileTypeMPEG4;
//                exportSession.shouldOptimizeForNetworkUse = YES;
//                [exportSession exportAsynchronouslyWithCompletionHandler:^(void) {
//                    switch (exportSession.status) {
//                        case AVAssetExportSessionStatusUnknown:
//                            NSLog(@"AVAssetExportSessionStatusUnknown"); break;
//                        case AVAssetExportSessionStatusWaiting:
//                            NSLog(@"AVAssetExportSessionStatusWaiting"); break;
//                        case AVAssetExportSessionStatusExporting:
//                            NSLog(@"AVAssetExportSessionStatusExporting"); break;
//                        case AVAssetExportSessionStatusCompleted:
//                            NSLog(@"AVAssetExportSessionStatusCompleted");
//                            if (completion) {
//                                completion(outputPath);
//                            }
//                            break;
//                        case AVAssetExportSessionStatusFailed:
//                            NSLog(@"AVAssetExportSessionStatusFailed"); break;
//                        default: break;
//                    }
//                }];
//            }
//        }];
//    } else {
//        NSLog(@"iOS8以前的系统，导出视频代码暂未更新...");
//    }
//}

#pragma mark - Private Method

- (TZAlbumModel *)modelWithResult:(id)result name:(NSString *)name{
    TZAlbumModel *model = [[TZAlbumModel alloc] init];
    model.result = result;
    model.name = [self getNewAlbumName:name];
    if ([result isKindOfClass:[PHFetchResult class]]) {
        PHFetchResult *fetchResult = (PHFetchResult *)result;
        model.count = fetchResult.count;
    }
//    else if ([result isKindOfClass:[ALAssetsGroup class]])
//    {
//        ALAssetsGroup *group = (ALAssetsGroup *)result;
//        model.count = [group numberOfAssets];
//    }
    return model;
}

- (NSString *)getNewAlbumName:(NSString *)name {
    if (iOS8Later) {
        NSString *newName;
        if ([name rangeOfString:@"Roll"].location != NSNotFound)         newName = @"相机胶卷";
        else if ([name rangeOfString:@"Stream"].location != NSNotFound)  newName = @"我的照片流";
        else if ([name rangeOfString:@"Added"].location != NSNotFound)   newName = @"最近添加";
        else if ([name rangeOfString:@"Selfies"].location != NSNotFound) newName = @"自拍";
        else if ([name rangeOfString:@"shots"].location != NSNotFound)   newName = @"截屏";
        else if ([name rangeOfString:@"Videos"].location != NSNotFound)  newName = @"视频";
        else if ([name rangeOfString:@"Panoramas"].location != NSNotFound)  newName = @"全景照片";
        else if ([name rangeOfString:@"Favorites"].location != NSNotFound)  newName = @"个人收藏";
        else newName = name;
        return newName;
    } else {
        return name;
    }
}

- (UIImage *)scaleImage:(UIImage *)image toSize:(CGSize)size {
    if (image.size.width > size.width) {
        UIGraphicsBeginImageContext(size);
        [image drawInRect:CGRectMake(0, 0, size.width, size.height)];
        UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        return newImage;
    } else {
        return image;
    }
}

- (UIImage *)fixOrientation:(UIImage *)aImage {
    if (!self.shouldFixOrientation) return aImage;
    
    // No-op if the orientation is already correct
    if (aImage.imageOrientation == UIImageOrientationUp)
        return aImage;
    
    // We need to calculate the proper transformation to make the image upright.
    // We do it in 2 steps: Rotate if Left/Right/Down, and then flip if Mirrored.
    CGAffineTransform transform = CGAffineTransformIdentity;
    
    switch (aImage.imageOrientation) {
        case UIImageOrientationDown:
        case UIImageOrientationDownMirrored:
            transform = CGAffineTransformTranslate(transform, aImage.size.width, aImage.size.height);
            transform = CGAffineTransformRotate(transform, M_PI);
            break;
            
        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
            transform = CGAffineTransformTranslate(transform, aImage.size.width, 0);
            transform = CGAffineTransformRotate(transform, M_PI_2);
            break;
            
        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
            transform = CGAffineTransformTranslate(transform, 0, aImage.size.height);
            transform = CGAffineTransformRotate(transform, -M_PI_2);
            break;
        default:
            break;
    }
    
    switch (aImage.imageOrientation) {
        case UIImageOrientationUpMirrored:
        case UIImageOrientationDownMirrored:
            transform = CGAffineTransformTranslate(transform, aImage.size.width, 0);
            transform = CGAffineTransformScale(transform, -1, 1);
            break;
            
        case UIImageOrientationLeftMirrored:
        case UIImageOrientationRightMirrored:
            transform = CGAffineTransformTranslate(transform, aImage.size.height, 0);
            transform = CGAffineTransformScale(transform, -1, 1);
            break;
        default:
            break;
    }
    
    // Now we draw the underlying CGImage into a new context, applying the transform
    // calculated above.
    CGContextRef ctx = CGBitmapContextCreate(NULL, aImage.size.width, aImage.size.height,
                                             CGImageGetBitsPerComponent(aImage.CGImage), 0,
                                             CGImageGetColorSpace(aImage.CGImage),
                                             CGImageGetBitmapInfo(aImage.CGImage));
    CGContextConcatCTM(ctx, transform);
    switch (aImage.imageOrientation) {
        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
            // Grr...
            CGContextDrawImage(ctx, CGRectMake(0,0,aImage.size.height,aImage.size.width), aImage.CGImage);
            break;
            
        default:
            CGContextDrawImage(ctx, CGRectMake(0,0,aImage.size.width,aImage.size.height), aImage.CGImage);
            break;
    }
    
    // And now we just create a new UIImage from the drawing context
    CGImageRef cgimg = CGBitmapContextCreateImage(ctx);
    UIImage *img = [UIImage imageWithCGImage:cgimg];
    CGContextRelease(ctx);
    CGImageRelease(cgimg);
    return img;
}

@end
