//
//  MNDealWithCode.h
//  TestAPI
//
//  Created by mining on 2018/8/22.
//  Copyright © 2018年 mining. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol DealScanCodeResultDelegate <NSObject>

@optional
- (void)getScanQRCodeResult:(NSString *) qrCodeResult;
- (void)getBrightnessValue:(float) brightnessValue;

@end

@interface MNDealWithCode : NSObject

+ (MNDealWithCode *)shared_mnDealWithCode;
- (UIImage *) createQRCodeWith:(NSString *) qrInfo in:(CGSize) size;

/**
 开始扫描二维码

 @param delegate 遵循DealScanCodeResultDelegate的UIViewController
 @param frame previewLayerFrame
 @param iFrame outPutIFrame
 @param belowOrAbove 0 below,1 above
 @param layer 图层必须在遵循delegate的ViewController中
 */
- (void)startScanQRCode:(UIViewController<DealScanCodeResultDelegate>*) delegate previewLayerFrame:(CGRect) frame outPutIFrame:(CGRect) iFrame belowOrAbove:(NSInteger) belowOrAbove withLayer:(CALayer *) layer;
- (void)stopScanQRCode;

@end
