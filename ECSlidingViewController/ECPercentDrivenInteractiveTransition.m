//
//  ECPercentDrivenInteractiveTransition.m
//  
//
//  Created by Michael Enriquez on 10/27/13.
//
//

#import "ECPercentDrivenInteractiveTransition.h"

@interface ECPercentDrivenInteractiveTransition ()
@property (nonatomic, assign) id<UIViewControllerContextTransitioning> transitionContext;
@end

@implementation ECPercentDrivenInteractiveTransition

- (void)startInteractiveTransition:(id<UIViewControllerContextTransitioning>)transitionContext {
    self.transitionContext = transitionContext;
    
    [CATransaction begin];
    [CATransaction setAnimationTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear]];
    [self.animationController animateTransition:transitionContext];
    [self updateInteractiveTransition:0];
    [CATransaction commit];
}

- (void)updateInteractiveTransition:(CGFloat)percentComplete {
    CGFloat boundedPercentage;
    if (percentComplete > 1.0) {
        boundedPercentage = 1.0;
    } else if (percentComplete < 0.0) {
        boundedPercentage = 0.0;
    } else {
        boundedPercentage = percentComplete;
    }
    
    _percentComplete = boundedPercentage;
    CALayer *layer = [self.transitionContext containerView].layer;
    CFTimeInterval pausedTime = [self.animationController transitionDuration:self.transitionContext] * _percentComplete;
    layer.speed = 0.0;
    layer.timeOffset = pausedTime;
    
    [self.transitionContext updateInteractiveTransition:_percentComplete];
}

- (void)cancelInteractiveTransition {
    CADisplayLink *displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(reversePausedAnimation:)];
    [displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    
    [self.transitionContext cancelInteractiveTransition];
}

- (void)finishInteractiveTransition {
    CALayer *layer = [self.transitionContext containerView].layer;
    CFTimeInterval pausedTime = [layer timeOffset];
    layer.speed = 1.0;
    layer.timeOffset = 0.0;
    layer.beginTime = 0.0;
    CFTimeInterval timeSincePause = [layer convertTime:CACurrentMediaTime() fromLayer:nil] - pausedTime;
    layer.beginTime = timeSincePause;
    
    [self.transitionContext finishInteractiveTransition];
}

#pragma mark - CADisplayLink action

- (void)reversePausedAnimation:(CADisplayLink *)displayLink {
    double percentInterval = displayLink.duration / [self.animationController transitionDuration:self.transitionContext];
    
    _percentComplete -= percentInterval;
    
    if (_percentComplete <= 0.0) {
        _percentComplete = 0.0;
        [displayLink invalidate];
    }
    
    [self updateInteractiveTransition:self.percentComplete];
    
    if (_percentComplete == 0.0) {
        CALayer *layer = [self.transitionContext containerView].layer;
        [layer removeAllAnimations];
        layer.speed = 1.0;
    }
}

@end
