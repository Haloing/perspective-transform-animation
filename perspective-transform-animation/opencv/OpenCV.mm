//
//  OpenCV.m
//  perspective-transform-animation
//
//  Created by imh on 2023/4/3.
//

#import "OpenCV.h"
#import <UIKit/UIKit.h>

#include <iostream>
#import <opencv2/imgcodecs/ios.h>
#import <opencv2/core.hpp>
#import <opencv2/highgui.hpp>
#import <opencv2/imgproc.hpp>

using namespace cv;
using namespace std;

@implementation OpenCV

+ (UIImage * __nullable)warpPerspective:(UIImage *)image tl:(CGPoint)topLeft tr:(CGPoint)topRight bl:(CGPoint)bottomLeft br:(CGPoint)bottomRight {
    
    cv::Mat src = [self cvMatFromUIImage:image];
    if (src.empty()) {
        printf("colud not read image...\n");
        return nil;
    }
    
    // 误差系数
    double ecoefficient = 0;
    // 计算宽高
    double leftHeight = sqrt(pow((topLeft.x - bottomLeft.x), 2) + pow((topLeft.y - bottomLeft.y), 2));
    double rightHeight = sqrt(pow((topRight.x - bottomRight.x), 2) + pow((topRight.y - bottomRight.y), 2));
    double maxHeight = max(leftHeight, rightHeight) - ecoefficient * 2;
    
    double upWidth = sqrt(pow((topLeft.x - topRight.x), 2) + pow((topLeft.y - topRight.y), 2));
    double downWidth = sqrt(pow((bottomLeft.x - bottomRight.x), 2) + pow((bottomLeft.y - bottomRight.y), 2));
    double maxWidth = max(upWidth, downWidth) - ecoefficient * 2;
    
    cv::Point2f SrcAffinePts[4] = {
        cv::Point2f(topLeft.x + ecoefficient, topLeft.y + ecoefficient),
        cv::Point2f(topRight.x - ecoefficient, topRight.y + ecoefficient) ,
        cv::Point2f(bottomLeft.x + ecoefficient, bottomLeft.y - ecoefficient),
        cv::Point2f(bottomRight.x - ecoefficient, bottomRight.y - ecoefficient)
    };
    
    cv::Point2f DstAffinePts[4] = {
        cv::Point2f(0,0),
        cv::Point2f(maxWidth,0),
        cv::Point2f(0,maxHeight),
        cv::Point2f(maxWidth,maxHeight)
    };
    
    cv::Mat M = getPerspectiveTransform(SrcAffinePts, DstAffinePts);
    cout << "M= " << endl << " " << M << endl << endl;
    
    cv::Mat DstImg;
    cv::warpPerspective(src, DstImg, M, cv::Size(maxWidth, maxHeight));
    
    UIImage *img = [self UIImageFromCVMat:DstImg];
    return img;
}

+ (cv::Mat)cvMatFromUIImage:(UIImage *)image {
    BOOL hasAlpha = NO;
    CGImageRef imageRef = image.CGImage;
    CGImageAlphaInfo alphaInfo = (CGImageAlphaInfo)(CGImageGetAlphaInfo(imageRef) & kCGBitmapAlphaInfoMask);
    if (alphaInfo == kCGImageAlphaPremultipliedLast ||
        alphaInfo == kCGImageAlphaPremultipliedFirst ||
        alphaInfo == kCGImageAlphaLast ||
        alphaInfo == kCGImageAlphaFirst) {
        hasAlpha = YES;
    }
    
    cv::Mat cvMat;
    CGBitmapInfo bitmapInfo;
    CGFloat cols = CGImageGetWidth(imageRef);
    CGFloat rows = CGImageGetHeight(imageRef);
    
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(imageRef);
    size_t numberOfComponents = CGColorSpaceGetNumberOfComponents(colorSpace);
    if (numberOfComponents == 1){// check whether the UIImage is greyscale already
        cvMat = cv::Mat(rows, cols, CV_8UC1); // 8 bits per component, 1 channels
        bitmapInfo = kCGImageAlphaNone | kCGBitmapByteOrderDefault;
    }
    else {
        cvMat = cv::Mat(rows, cols, CV_8UC4); // 8 bits per component, 4 channels (color channels + alpha)
        bitmapInfo = kCGBitmapByteOrder32Host;
        // kCGImageAlphaNone is not supported in CGBitmapContextCreate.
        // Since the original image here has no alpha info, use kCGImageAlphaNoneSkipLast
        // to create bitmap graphics contexts without alpha info.
        bitmapInfo |= hasAlpha ? kCGImageAlphaPremultipliedFirst : kCGImageAlphaNoneSkipFirst;
    }
    
    CGContextRef contextRef = CGBitmapContextCreate(cvMat.data,                 // Pointer to  data
                                                    cols,                       // Width of bitmap
                                                    rows,                       // Height of bitmap
                                                    8,                          // Bits per component
                                                    cvMat.step[0],              // Bytes per row
                                                    colorSpace,                 // Colorspace
                                                    bitmapInfo                  // Bitmap info flags
                                                    );
    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), imageRef);     // decode
    CGContextRelease(contextRef);
    return cvMat;
}

+ (UIImage *)UIImageFromCVMat:(cv::Mat &)cvMat {
    CGColorSpaceRef colorSpace;
    CGBitmapInfo bitmapInfo;
    size_t elemsize = cvMat.elemSize();
    if (elemsize == 1) {
        colorSpace = CGColorSpaceCreateDeviceGray();
        bitmapInfo = kCGImageAlphaNone | kCGBitmapByteOrderDefault;
    }
    else {
        colorSpace = CGColorSpaceCreateDeviceRGB();
        bitmapInfo = kCGBitmapByteOrder32Host;
        bitmapInfo |= (elemsize == 4) ? kCGImageAlphaPremultipliedFirst : kCGImageAlphaNone;
    }
    
    NSData *data = [NSData dataWithBytes:cvMat.data length:elemsize * cvMat.total()];
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    // Creating CGImage from cv::Mat
    CGImageRef imageRef = CGImageCreate(cvMat.cols,                 // width
                                        cvMat.rows,                 // height
                                        8,                          // bits per component
                                        8 * cvMat.elemSize(),       // bits per pixel
                                        cvMat.step[0],              // bytesPerRow
                                        colorSpace,                 // colorspace
                                        bitmapInfo,                 // bitmap info
                                        provider,                   // CGDataProviderRef
                                        NULL,                       // decode
                                        false,                      // should interpolate
                                        kCGRenderingIntentDefault   // intent
                                        );
    
    UIImage *finalImage = [UIImage imageWithCGImage:imageRef];
    
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    
    return finalImage;
}

@end
