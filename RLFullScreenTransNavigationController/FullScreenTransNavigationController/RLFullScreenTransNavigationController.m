//
//  RLFullScreenTransNavigationController.m
//  RLFullScreenTransNavigationController
//
//  Created by Roy lee on 16/7/13.
//  Copyright © 2016年 Roy lee. All rights reserved.
//

#import "RLFullScreenTransNavigationController.h"
#import <objc/runtime.h>

static const CGFloat PopMaskOpacity = 0.40f;   // 滑动返回时蒙版视图的起始透明度

@interface UIView (RLFrame)
@property (nonatomic, assign) CGFloat rl_x;
@end



@interface RLFullScreenTransNavigationController ()<UIGestureRecognizerDelegate,UINavigationControllerDelegate,UINavigationBarDelegate>

@property (nonatomic, assign) CGFloat startBackViewX;
@property (nonatomic, assign) BOOL firstTouch;
@property (nonatomic, strong) UIPanGestureRecognizer * fullscreenPopGestureRecognizer;
@property (nonatomic, strong) UIView * backgroundView;
@property (nonatomic, strong) NSMutableArray * screenShotsList;
@property (nonatomic, strong) UIImageView * lastScreenShotView;
@property (nonatomic, strong) UIView * blackMask;
@property (nonatomic, assign) CGPoint startTouch;
@property (nonatomic, assign) BOOL isMoving;

@end

@implementation RLFullScreenTransNavigationController


CGFloat kScreenWidth() {
    static CGFloat screenWidth = 0;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        screenWidth = [UIScreen mainScreen].bounds.size.width;
    });
    return screenWidth;
}

CGFloat kScreenHeight() {
    static CGFloat screenHeight = 0;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        screenHeight = [UIScreen mainScreen].bounds.size.width;
    });
    return screenHeight;
}

UIWindow * keyWindow() {
    UIWindow * window = [[UIApplication sharedApplication] keyWindow];
    if (window.windowLevel != UIWindowLevelNormal) {
        NSArray *windows = [[UIApplication sharedApplication] windows];
        for(UIWindow * tmpWin in windows) {
            if (tmpWin.windowLevel == UIWindowLevelNormal) {
                window = tmpWin;
                break;
            }
        }
    }
    return window;
}



- (void)dealloc {
    self.screenShotsList = nil;
    [_backgroundView removeFromSuperview];
    self.backgroundView = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype)initWithRootViewController:(UIViewController *)rootViewController {
    self = [super initWithRootViewController:rootViewController];
    if (self) {
        // 侧滑左侧阴影
        CAGradientLayer * gradientLayer = [CAGradientLayer layer];
        gradientLayer.frame = CGRectMake(- 10, 0, 10, kScreenHeight());
        [self.view.layer addSublayer:gradientLayer];
        
        gradientLayer.startPoint = CGPointMake(1, 0);
        gradientLayer.endPoint = CGPointMake(0, 0);
        gradientLayer.colors = @[(__bridge id)[UIColor colorWithWhite:0.2 alpha:0.3].CGColor,
                                 (__bridge id)[UIColor colorWithWhite:0.3 alpha:0.0].CGColor]
        ;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //屏蔽掉iOS7以后自带的滑动返回手势 否则有BUG
    if ([self respondsToSelector:@selector(interactivePopGestureRecognizer)]) {
        self.interactivePopGestureRecognizer.enabled = NO;
    }
    self.screenShotsList = [[NSMutableArray alloc]initWithCapacity:2];
    self.disableDragBack = NO;
    self.disableTransitionEffect = NO;
    self.firstTouch = YES;
    
    // 滑动返回手势
    self.fullscreenPopGestureRecognizer = [[UIPanGestureRecognizer alloc]initWithTarget:self
                                                                                 action:@selector(paningGestureReceive:)];
//    _fullscreenPopGestureRecognizer.delaysTouchesBegan = YES;
    _fullscreenPopGestureRecognizer.delegate = self;
    [self.view addGestureRecognizer:_fullscreenPopGestureRecognizer];
}

#pragma mark - lazy load
- (UIView *)backgroundView {
    if (!_backgroundView) {
        self.backgroundView = [[UIView alloc]initWithFrame:self.view.bounds];
        
        self.blackMask = [[UIView alloc]initWithFrame:self.view.bounds];
        _blackMask.backgroundColor = [UIColor blackColor];
        
        [_backgroundView addSubview:_blackMask];
        [self.view.superview insertSubview:_backgroundView belowSubview:self.view];
    }
    return _backgroundView;
}

#pragma mark - trasition
/**
 *  自定义导航栏的滑动push与pop之后，系统对于viewWillAppear: viewWillDisappear:的管理就不准确了
 */
- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated {
    if (nil == viewController) {
        NSLog(@"You are tring to push a nil viewController.............");
        return;
    }
    [self.screenShotsList addObject:[self capture]];
    if (animated) {
        self.lastScreenShotView = [[UIImageView alloc]initWithImage:self.screenShotsList.lastObject];
        [_lastScreenShotView removeFromSuperview];
        [self.backgroundView removeFromSuperview];
        [self.view.superview insertSubview:self.backgroundView belowSubview:self.view];
        [self.backgroundView insertSubview:_lastScreenShotView belowSubview:_blackMask];
        [_blackMask setAlpha:0];
        
        [super pushViewController:viewController animated:NO];
        
        CGFloat leftSlowOffset = 50.0f;
        CGFloat offsetRatio = 1 - leftSlowOffset/[UIScreen mainScreen].bounds.size.width;
        CGFloat durationRatio = offsetRatio * 0.65;
        _startBackViewX = startX;
        self.backgroundView.hidden = NO;
        self.view.rl_x = self.view.frame.size.width;
        [UIView animateKeyframesWithDuration:PushAnimationDuration delay:0.0f options:(UIViewKeyframeAnimationOptionCalculationModeLinear) animations:^{
            [UIView addKeyframeWithRelativeStartTime:0.0f relativeDuration:durationRatio animations:^{
                self.view.rl_x = leftSlowOffset;
                _blackMask.alpha   = PopMaskOpacity  * offsetRatio;
                _lastScreenShotView.rl_x = _startBackViewX * offsetRatio;;
            }];
            [UIView addKeyframeWithRelativeStartTime:durationRatio relativeDuration:1 - durationRatio animations:^{
                self.view.rl_x = 0;
                _blackMask.alpha = PopMaskOpacity;
                _lastScreenShotView.rl_x = _startBackViewX;
            }];
        } completion:^(BOOL finished) {
            _lastScreenShotView.rl_x = 0;
            self.backgroundView.hidden = YES;
        }];
    }else {
        [super pushViewController:viewController animated:animated];
    }
}

- (UIViewController *)popViewControllerAnimated:(BOOL)animated {
    if (!_disableTransitionEffect) {
        [self popViewController];
        return nil;
    }else{
        [self.screenShotsList removeLastObject];
        return [super popViewControllerAnimated:animated];
    }
}

- (NSArray<UIViewController *> *)popToViewController:(UIViewController *)viewController animated:(BOOL)animated {
    if (!_disableTransitionEffect) {
        [self popToViewController:viewController];
        return nil;
    }else{
        NSInteger index = [self.viewControllers indexOfObject:viewController];
        for (NSInteger i = index; i < _screenShotsList.count; i ++) {
            [_screenShotsList removeObjectAtIndex:index];
            i --;
        }
        return [super popToViewController:viewController animated:animated];
    }
}

- (NSArray<UIViewController *> *)popToRootViewControllerAnimated:(BOOL)animated {
    UIViewController * rootVC = self.viewControllers.firstObject;
    if (!_disableTransitionEffect) {
        if (_screenShotsList.count <= 0) {
            return [super popToRootViewControllerAnimated:animated];
        }
        [self popToViewController:rootVC];
        return nil;
    }else{
        for (NSInteger i = 0; i < self.screenShotsList.count; i ++) {
            [_screenShotsList removeObjectAtIndex:i];
            i --;
        }
        return [super popToRootViewControllerAnimated:animated];
    }
}

- (void)popViewController {
    self.backgroundView.hidden = NO;
    
    if (_lastScreenShotView) [_lastScreenShotView removeFromSuperview];
    
    // 加入指定页面返回
    UIViewController * lastVC = self.viewControllers.lastObject;
    NSInteger index = lastVC.indexOfViewControllerToPop;
    if (index == -1) {
        index = self.screenShotsList.count - 1;
    }
    UIImage *lastScreenShot = [self.screenShotsList objectAtIndex:index];
    _lastScreenShotView = [[UIImageView alloc]initWithImage:lastScreenShot];
    
    _startBackViewX = startX;
    [_lastScreenShotView setFrame:CGRectMake(_startBackViewX,
                                             _lastScreenShotView.frame.origin.y,
                                             _lastScreenShotView.frame.size.width,
                                             _lastScreenShotView.frame.size.height)];
    
    [self.backgroundView insertSubview:_lastScreenShotView belowSubview:_blackMask];
    
    [UIView animateWithDuration:PopAnimationDuration animations:^{
        [self moveViewWithX:kScreenWidth()];
    } completion:^(BOOL finished) {
        self.view.rl_x = 0;
        self.backgroundView.hidden = YES;
        // remove screenshots
        for (NSInteger i = index; i < self.screenShotsList.count; i ++) {
            [self.screenShotsList removeObjectAtIndex:index];
            [super popViewControllerAnimated:NO];   // 多次pop，直接popToVC有tabbar hidenWhenPush 变化的bug
            i --;
        }
    }];
}

- (void)popToViewController:(UIViewController *)viewController {
    UIViewController * lastVC = self.viewControllers.lastObject;
    lastVC.indexOfViewControllerToPop = [self.viewControllers indexOfObject:viewController];
    [self popViewController];
}

#pragma mark - Utility Methods -

- (UIImage *)capture {
    UIView * captureView = self.view;
    if (self.tabBarController.view) {
        captureView = self.tabBarController.view;
    }
    UIGraphicsBeginImageContextWithOptions(self.view.bounds.size, self.view.opaque, 0.0);
    [captureView.layer renderInContext:UIGraphicsGetCurrentContext()];
    
    UIImage * img = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    return img;
}

- (void)moveViewWithX:(float)x {
    
    x = x>self.view.bounds.size.width?self.view.bounds.size.width:x;
    x = x<0?0:x;
    
    self.view.rl_x = x;
    
    float alpha = PopMaskOpacity * (1 - x/kScreenWidth());
    
    _blackMask.alpha = alpha;
    
    CGFloat aa = fabs(_startBackViewX)/kScreenWidth();
    CGFloat y = x * aa;
    
    UIImage * lastScreenShot = [self.screenShotsList lastObject];
    CGFloat lastScreenShotViewHeight = lastScreenShot.size.height;
    CGFloat superviewHeight = _lastScreenShotView.superview.frame.size.height;
    CGFloat verticalPos = superviewHeight - lastScreenShotViewHeight;
    
    [_lastScreenShotView setFrame:CGRectMake(_startBackViewX + y,
                                             verticalPos,
                                             lastScreenShot.size.width,
                                             lastScreenShotViewHeight)];
}


#pragma mark - Gesture Recognizer -
// 手势不处理操作
- (BOOL)gestureRecognizerShouldBegin:(UIPanGestureRecognizer *)gestureRecognizer {
    if (self.viewControllers.count <= 1 || _disableDragBack){
        return NO;
    }
    // Ignore when the active view controller doesn't allow interactive pop.
    UIViewController *topViewController = self.viewControllers.lastObject;
    
    // Ignore when the beginning location is beyond max allowed initial distance to left edge.
    CGPoint beginningLocation = [gestureRecognizer locationInView:gestureRecognizer.view];
    CGFloat maxAllowedInitialDistance = topViewController.interactivePopMaxAllowedInitialDistanceToLeftEdge;
    if (maxAllowedInitialDistance > 0 && beginningLocation.x > maxAllowedInitialDistance) {
        return NO;
    }
    if (topViewController.interactivePopGestureRecognizerDisabled) {
        return NO;
    }
    
    // Ignore pan gesture when the navigation controller is currently in transition.
    if ([[self valueForKey:@"_isTransitioning"] boolValue]) {
        return NO;
    }
    
    // Prevent calling the handler when the gesture begins in an opposite direction.
    CGPoint translation = [gestureRecognizer translationInView:gestureRecognizer.view];
    if (translation.x <= 0) {
        return NO;
    }
    
    return YES;
}

- (void)paningGestureReceive:(UIPanGestureRecognizer *)recoginzer {
    if (self.viewControllers.count <= 1 || _disableDragBack) return;
    
    // hiden keyboard if the keyboard is showing
    [self.view endEditing:YES];
    
    CGPoint touchPoint = [recoginzer locationInView:keyWindow()];
    
    if (recoginzer.state == UIGestureRecognizerStateBegan) {
        
        _isMoving = YES;
        _startTouch = touchPoint;
        
        [self.backgroundView removeFromSuperview];
        [self.view.superview insertSubview:self.backgroundView belowSubview:self.view];
        [self.backgroundView setHidden:NO];
        
        if (_lastScreenShotView) [_lastScreenShotView removeFromSuperview];
        // 加入指定页面返回
        UIViewController * lastVC = self.viewControllers.lastObject;
        NSInteger index = lastVC.indexOfViewControllerToPop;
        if (index == -1) {
            index = self.screenShotsList.count - 1;
        }
        
        UIImage *lastScreenShot = [self.screenShotsList objectAtIndex:index];
        _lastScreenShotView = [[UIImageView alloc]initWithImage:lastScreenShot];
        
        _startBackViewX = startX;
        [_lastScreenShotView setFrame:CGRectMake(_startBackViewX,
                                                 _lastScreenShotView.frame.origin.y,
                                                 _lastScreenShotView.frame.size.height,
                                                 _lastScreenShotView.frame.size.width)];
        
        [self.backgroundView insertSubview:_lastScreenShotView belowSubview:_blackMask];
        
    }else if (recoginzer.state == UIGestureRecognizerStateEnded || recoginzer.state == UIGestureRecognizerStateCancelled){
        [self _panGestureRecognizerDidFinish:recoginzer];
    } else if (recoginzer.state == UIGestureRecognizerStateChanged) {
        
        if (_isMoving) {
            [self moveViewWithX:touchPoint.x - _startTouch.x];
        }
    }
    
}

// 当手势结束的时候，会根据当前滑动的速度，以及当前的位置综合去计算将要移动到的位置。
- (void)_panGestureRecognizerDidFinish:(UIPanGestureRecognizer *)panGestureRecognizer {
    // 获取手指离开时候的速度
    CGFloat velocityX = [panGestureRecognizer velocityInView:keyWindow()].x;
    CGPoint translation = [panGestureRecognizer translationInView:keyWindow()];
    
    // 根据松手后的速度假想滚动的位置
    CGFloat tempTargetX = MIN(MAX(translation.x + (velocityX * 0.2), 0), kScreenWidth());
    CGFloat gestureTargetX = (tempTargetX + translation.x) / 2;
    
    // 当前push/pop完成的百分比,根据这个百分比，可以计算得到剩余动画的时间。
    CGFloat completionPercent = gestureTargetX / kScreenWidth();
    CGFloat moveTargetX = 0;
    CGFloat duration;
    
    BOOL finishPop = NO;
    if (gestureTargetX > kScreenWidth() * 0.4 && velocityX > 0) {
        // 需要pop, pop的总时间是0.3, 完成了percent,还剩余1-percent
        duration = PopAnimationDuration * (1.0 - completionPercent);
        moveTargetX = kScreenWidth();
        finishPop = YES;
    } else {
        // 再push回去,如果已经pop了百分之percent,则时间就是completionPercent *0.3
        duration = completionPercent * PopAnimationDuration;
    }
    duration = MAX(MIN(duration, PopAnimationDuration), 0.01);
    
    [UIView animateWithDuration:duration animations:^{
        [self moveViewWithX:finishPop ? kScreenWidth() : 0];
    } completion:^(BOOL finished) {
        
        _isMoving = NO;
        if (finishPop) {
            UIViewController * lastVC = self.viewControllers.lastObject;
            NSInteger index = lastVC.indexOfViewControllerToPop;
            if (index == - 1) {
                index = self.screenShotsList.count - 1;
            }
            self.view.rl_x = 0;
            for (NSInteger i = index; i < self.screenShotsList.count; i ++) {
                [self.screenShotsList removeObjectAtIndex:index];
                [super popViewControllerAnimated:NO];
                i --;
            }
        }
        self.backgroundView.hidden = YES;
        
    }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end






@interface UIViewController ()

@end

@implementation UIViewController (FullScreenPopGesture)

- (CGFloat)interactivePopMaxAllowedInitialDistanceToLeftEdge {
#if CGFLOAT_IS_DOUBLE
    return [objc_getAssociatedObject(self, _cmd) doubleValue];
#else
    return [objc_getAssociatedObject(self, _cmd) floatValue];
#endif
}

- (void)setInteractivePopMaxAllowedInitialDistanceToLeftEdge:(CGFloat)distance {
    SEL key = @selector(interactivePopMaxAllowedInitialDistanceToLeftEdge);
    objc_setAssociatedObject(self, key, @(MAX(0, distance)), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)interactivePopGestureRecognizerDisabled {
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

- (void)setInteractivePopGestureRecognizerDisabled:(BOOL)interactivePopGestureRecognizerDisabled {
    SEL key = @selector(interactivePopGestureRecognizerDisabled);
    objc_setAssociatedObject(self, key, @(interactivePopGestureRecognizerDisabled), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSInteger)indexOfViewControllerToPop {
    NSNumber * index = objc_getAssociatedObject(self, _cmd);
    if (index) {
        return [index integerValue];
    }
    return -1;
}

- (void)setIndexOfViewControllerToPop:(NSInteger)indexOfViewControllerToPop {
    SEL key = @selector(indexOfViewControllerToPop);
    objc_setAssociatedObject(self, key, @(indexOfViewControllerToPop), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}


@end




@implementation UIView (RLFrame)

- (CGFloat)rl_x {
    return self.frame.origin.x;
}

- (void)setRl_x:(CGFloat)rl_x {
    CGRect frame   = self.frame;
    frame.origin.x = rl_x;
    self.frame = frame;
}

@end

