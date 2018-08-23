//
//  MNDealWithCode.m
//  TestAPI
//
//  Created by mining on 2018/8/22.
//  Copyright © 2018年 mining. All rights reserved.
//

#import "MNDealWithCode.h"
#import <AVFoundation/AVFoundation.h>

@interface MNDealWithCode() <AVCaptureMetadataOutputObjectsDelegate,AVCaptureVideoDataOutputSampleBufferDelegate>

@property (weak, nonatomic) id<DealScanCodeResultDelegate> delegate;
@property (assign, nonatomic) CGRect previewLayerFrame;
@property (assign, nonatomic) CGRect outPutIFrame;

@end


@implementation MNDealWithCode {
    AVCaptureDevice * captureDevice;
    //管理输入流
    AVCaptureDeviceInput * captureDeviceInput;
    //管理输出流
    AVCaptureMetadataOutput * captureMetadataOutput;
    AVCaptureVideoDataOutput  *output;
    //管理输入(AVCaptureInput)和输出(AVCaptureOutput)流，包含开启和停止会话方法
    AVCaptureSession * captureSession;
    //显示捕获到的相机输出流
    AVCaptureVideoPreviewLayer * captureVideoPreviewLayer;
    
    UIViewController *addedViewController;
}

+ (MNDealWithCode *)shared_mnDealWithCode
{
    static MNDealWithCode *mnDealWithCode;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mnDealWithCode = [[MNDealWithCode alloc] init];
    });
    
    return mnDealWithCode;
}

#pragma mark - 生成二维码
- (CIImage *) createQRCode:(NSString *)qrInfo {
    CIFilter *filter = [CIFilter filterWithName:@"CIQRCodeGenerator"];
    [filter setDefaults];
    NSString *string = qrInfo;
    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
    [filter setValue:data forKeyPath:@"inputMessage"];
    CIImage *image = [filter outputImage];
    return image;
}

- (UIImage *) createQRCodeWith:(NSString *) qrInfo in:(CGSize)size {
    CIImage *image = [self createQRCode:qrInfo];
    CGRect extent = CGRectIntegral(image.extent);
    CGFloat scale = MIN(size.width/CGRectGetWidth(extent), size.height/CGRectGetHeight(extent));
    
    // 1.创建bitmap;
    size_t width = CGRectGetWidth(extent) * scale;
    size_t height = CGRectGetHeight(extent) * scale;
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceGray();
    CGContextRef bitmapRef = CGBitmapContextCreate(nil, width, height, 8, 0, cs, (CGBitmapInfo)kCGImageAlphaNone);
    CIContext *context = [CIContext contextWithOptions:nil];
    CGImageRef bitmapImage = [context createCGImage:image fromRect:extent];
    CGContextSetInterpolationQuality(bitmapRef, kCGInterpolationNone);
    CGContextScaleCTM(bitmapRef, scale, scale);
    CGContextDrawImage(bitmapRef, extent, bitmapImage);
    
    // 2.保存bitmap到图片
    CGImageRef scaledImage = CGBitmapContextCreateImage(bitmapRef);
    CGContextRelease(bitmapRef);
    CGImageRelease(bitmapImage);
    return [UIImage imageWithCGImage:scaledImage];
}

#pragma mark - 扫描二维码
- (void)startScanQRCode:(UIViewController<DealScanCodeResultDelegate>*) delegate previewLayerFrame:(CGRect) frame outPutIFrame:(CGRect) iFrame belowOrAbove:(NSInteger) belowOrAbove withLayer:(CALayer *) layer{
    self.delegate = delegate;
    self.previewLayerFrame = frame;
    self.outPutIFrame = iFrame;
    
    addedViewController = delegate;
    
    captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    captureDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:captureDevice error:nil];
    
    captureMetadataOutput = [[AVCaptureMetadataOutput alloc]init];
    [captureMetadataOutput setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
    [captureMetadataOutput setRectOfInterest:[self transformCropRect:self.outPutIFrame]];
    
    
    output = [[AVCaptureVideoDataOutput alloc]init];
    [output setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
    
    captureSession = [[AVCaptureSession alloc]init];
    [captureSession setSessionPreset:AVCaptureSessionPreset1920x1080];
    
    if ([captureSession canAddInput:captureDeviceInput])
    {
        [captureSession addInput:captureDeviceInput];
    }
    
    if ([captureSession canAddOutput:captureMetadataOutput])
    {
        [captureSession addOutput:captureMetadataOutput];
        [captureSession addOutput:output];
    }
    captureMetadataOutput.metadataObjectTypes = [NSArray arrayWithObject:AVMetadataObjectTypeQRCode];
    // Preview
    captureVideoPreviewLayer =[AVCaptureVideoPreviewLayer layerWithSession:captureSession];
    captureVideoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    captureVideoPreviewLayer.frame = self.previewLayerFrame;
    
    if (0 == belowOrAbove) {
        [addedViewController.view.layer insertSublayer:captureVideoPreviewLayer below:layer];
    } else if (1 == belowOrAbove) {
        [addedViewController.view.layer insertSublayer:captureVideoPreviewLayer above:layer];
    }
    

    [captureSession startRunning];
}

- (void)stopScanQRCode {
    [captureSession stopRunning];
}

- (CGRect)transformCropRect:(CGRect)cropRect
{
    CGRect vcFrame = addedViewController.view.frame;
    CGSize size = self.previewLayerFrame.size;
    CGFloat p1 = size.height/size.width;
    CGFloat p2 = 1920.0/1080.0;  //Using the 1080p image output
    
    if (p1 < p2) {
        CGFloat fixHeight = vcFrame.size.width * 1920.0 / 1080.0;
        CGFloat fixPadding = (fixHeight - size.height)/2;
        return CGRectMake((cropRect.origin.y + fixPadding)/fixHeight,
                          cropRect.origin.x/size.width,
                          cropRect.size.height/fixHeight,
                          cropRect.size.width/size.width);
    } else {
        CGFloat fixWidth = vcFrame.size.height * 1080.0 / 1920.0;
        CGFloat fixPadding = (fixWidth - size.width)/2;
        return CGRectMake(cropRect.origin.y/size.height,
                          (cropRect.origin.x + fixPadding)/fixWidth,
                          cropRect.size.height/size.height,
                          cropRect.size.width/fixWidth);
    }
}

#pragma mark - AVCaptureMetadataOutputObjectsDelegate
- (void)captureOutput:(AVCaptureOutput *)output didOutputMetadataObjects:(NSArray<__kindof AVMetadataObject *> *)metadataObjects fromConnection:(AVCaptureConnection *)connection {
    if ([metadataObjects count] >0)
    {
        AVMetadataMachineReadableCodeObject * metadataObject = [metadataObjects objectAtIndex:0];
        NSString *strValue = metadataObject.stringValue;
        if ([self.delegate respondsToSelector:@selector(getScanQRCodeResult:)]) {
            [self.delegate getScanQRCodeResult:strValue];
        }
    }
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    CFDictionaryRef metadataDict = CMCopyDictionaryOfAttachments(NULL, sampleBuffer, kCMAttachmentMode_ShouldPropagate);
    NSDictionary *metadata = [[NSMutableDictionary alloc] initWithDictionary:(__bridge NSDictionary *)metadataDict];
    CFRelease(metadataDict);
    NSDictionary *exifMetadata = [[metadata objectForKey:(NSString *)kCGImagePropertyExifDictionary] mutableCopy];
    float brightnessValue = [[exifMetadata objectForKey:(NSString *)kCGImagePropertyExifBrightnessValue] floatValue];
    if ([self.delegate respondsToSelector:@selector(getBrightnessValue:)]) {
        [self.delegate getBrightnessValue:brightnessValue];
    }
}
@end
