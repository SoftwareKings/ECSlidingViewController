//
//  MEFoldAnimationController.m
//  TransitionFun
//
//  Created by Michael Enriquez on 10/28/13.
//  Copyright (c) 2013 Mike Enriquez. All rights reserved.
//

#import "MEFoldAnimationController.h"
#import "ECSlidingViewController.h"

@interface MEFoldAnimationController ()
- (void)foldLayers:(CALayer *)leftSide rightSide:(CALayer *)rightSide;
- (void)unfoldLayers:(CALayer *)leftSide rightSide:(CALayer *)rightSide;
@end

@implementation MEFoldAnimationController

#pragma mark - UIViewControllerAnimatedTransitioning

- (NSTimeInterval)transitionDuration:(id <UIViewControllerContextTransitioning>)transitionContext {
    return 0.25;
}

- (void)animateTransition:(id<UIViewControllerContextTransitioning>)transitionContext {
    UIViewController *topViewController = [transitionContext viewControllerForKey:ECTransitionContextTopViewControllerKey];
    UIViewController *toViewController  = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
    UIView *containerView    = [transitionContext containerView];
    CGRect topViewFinalFrame = [transitionContext finalFrameForViewController:topViewController];
    BOOL isResetting = NO;
    
    CATransform3D transform = CATransform3DIdentity;
    transform.m34 = -0.002;
    containerView.layer.sublayerTransform = transform;
    
    UIViewController *underViewController;
    
    if (topViewController == toViewController) {
        underViewController = [transitionContext viewControllerForKey:ECTransitionContextUnderLeftControllerKey];
        isResetting = YES;
    } else {
        underViewController = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
        isResetting = NO;
    }
        
    CGRect underViewInitialFrame = [transitionContext initialFrameForViewController:underViewController];
    UIView *underView = underViewController.view;
    
    underView.frame = underViewInitialFrame;
    [underView removeFromSuperview];

    CGFloat underViewHalfwayPoint = underView.bounds.size.width / 2;
    CGRect leftSideFrame = CGRectMake(0, 0, underViewHalfwayPoint, underView.bounds.size.height);
    CGRect rightSideFrame = CGRectMake(underViewHalfwayPoint, 0, underViewHalfwayPoint, underView.bounds.size.height);
    
    UIView *leftSideView = [underView resizableSnapshotViewFromRect:leftSideFrame
                                                 afterScreenUpdates:YES
                                                      withCapInsets:UIEdgeInsetsZero];
    UIView *rightSideView = [underView resizableSnapshotViewFromRect:rightSideFrame
                                                  afterScreenUpdates:YES
                                                       withCapInsets:UIEdgeInsetsZero];
    
    leftSideView.layer.anchorPoint = CGPointMake(0, 0.5);
    leftSideView.frame = leftSideFrame;
    
    rightSideView.layer.frame       = rightSideFrame;
    rightSideView.layer.anchorPoint = CGPointMake(1, 0);
    
    if (isResetting) {
        [self unfoldLayers:leftSideView.layer rightSide:rightSideView.layer];
    } else {
        [self foldLayers:leftSideView.layer rightSide:rightSideView.layer];
    }
    
    [containerView insertSubview:leftSideView belowSubview:topViewController.view];
    [containerView insertSubview:rightSideView aboveSubview:topViewController.view];
    
    NSTimeInterval duration = [self transitionDuration:transitionContext];
    [UIView animateWithDuration:duration animations:^{
        [UIView setAnimationCurve:UIViewAnimationCurveLinear];
        
        topViewController.view.frame = topViewFinalFrame;
        
        if (isResetting) {
            [self foldLayers:leftSideView.layer rightSide:rightSideView.layer];
        } else {
            [self unfoldLayers:leftSideView.layer rightSide:rightSideView.layer];
        }
    } completion:^(BOOL finished) {
        [leftSideView removeFromSuperview];
        [rightSideView removeFromSuperview];

        BOOL topViewReset = (isResetting && ![transitionContext transitionWasCancelled]) || (!isResetting && [transitionContext transitionWasCancelled]);
        
        if ([transitionContext transitionWasCancelled]) {
            topViewController.view.frame = [transitionContext initialFrameForViewController:topViewController];
        } else {
            topViewController.view.frame = [transitionContext finalFrameForViewController:topViewController];
        }
        
        if (topViewReset) {
            [underView removeFromSuperview];
        } else {
            if ([transitionContext transitionWasCancelled]) {
                underView.frame = [transitionContext initialFrameForViewController:underViewController];
            } else {
                underView.frame = [transitionContext finalFrameForViewController:underViewController];
            }
            [containerView insertSubview:underView belowSubview:topViewController.view];
        }
        
        [transitionContext completeTransition:finished];
    }];
}

#pragma mark - Private

- (void)foldLayers:(CALayer *)leftSide rightSide:(CALayer *)rightSide {
    leftSide.transform = CATransform3DMakeRotation(M_PI_2, 0.0, 1.0, 0.0);
    
    rightSide.position  = CGPointMake(0, 0);
    rightSide.transform = CATransform3DMakeRotation(-M_PI_2, 0.0, 1.0, 0.0);
}

- (void)unfoldLayers:(CALayer *)leftSide rightSide:(CALayer *)rightSide {
    leftSide.transform = CATransform3DMakeRotation(0, 0.0, 1.0, 0.0);
    
    rightSide.position  = CGPointMake(rightSide.bounds.size.width * 2, 0);
    rightSide.transform = CATransform3DMakeRotation(0, 0.0, 1.0, 0.0);
}

@end
