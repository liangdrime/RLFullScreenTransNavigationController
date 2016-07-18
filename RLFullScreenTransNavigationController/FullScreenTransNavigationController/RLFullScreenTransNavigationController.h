//
//  RLFullScreenTransNavigationController.h
//  RLFullScreenTransNavigationController
//
//  Created by Roy lee on 16/7/13.
//  Copyright © 2016年 Roy lee. All rights reserved.
//

#import <UIKit/UIKit.h>

#define startX   (- kScreenWidth() * 0.3)
static const CGFloat PopAnimationDuration   = 0.30f;   // 滑动返回时动画时间
static const CGFloat PushAnimationDuration  = 0.45f;   // push动画时间

@interface RLFullScreenTransNavigationController : UINavigationController

@property (nonatomic, assign) BOOL disableDragBack;
@property (nonatomic, assign) BOOL disableTransitionEffect;
@property (nonatomic, assign) CGFloat interactivePopMaxAllowedInitialDistanceToLeftEdge;
@property (nonatomic, readonly, strong) UIPanGestureRecognizer * fullscreenPopGestureRecognizer;

@end




@interface UIViewController (FullScreenPopGesture)

@property (nonatomic, assign) CGFloat interactivePopMaxAllowedInitialDistanceToLeftEdge;
@property (nonatomic, assign) BOOL interactivePopGestureRecognizerDisabled;
@property (nonatomic, assign) NSInteger indexOfViewControllerToPop;   // 设置返回层级的index，默认是-1，返回上一级

@end
