//
//  OpenCV.h
//  perspective-transform-animation
//
//  Created by imh on 2023/4/3.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface OpenCV : NSObject

+ (UIImage * __nullable)warpPerspective:(UIImage *)image tl:(CGPoint)topLeft tr:(CGPoint)topRight bl:(CGPoint)bottomLeft br:(CGPoint)bottomRight;

@end

NS_ASSUME_NONNULL_END
