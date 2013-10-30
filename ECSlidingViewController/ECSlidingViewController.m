//
//  ECSlidingViewController.m
//  ECSlidingViewController
//
//  Created by Michael Enriquez on 10/11/13.
//  Copyright (c) 2013 Mike Enriquez. All rights reserved.
//

#import "ECSlidingViewController.h"

@implementation UIViewController(SlidingViewExtension)

- (ECSlidingViewController *)slidingViewController {
    UIViewController *viewController = self.parentViewController ? self.parentViewController : self.presentingViewController;
    while (!(viewController == nil || [viewController isKindOfClass:[ECSlidingViewController class]])) {
        viewController = viewController.parentViewController ? viewController.parentViewController : viewController.presentingViewController;
    }
    
    return (ECSlidingViewController *)viewController;
}

@end

@interface ECSlidingViewController()
@property (nonatomic, assign) ECSlidingViewControllerOperation currentOperation;
@property (nonatomic, strong) ECSlidingAnimationController *defaultAnimationController;
@property (nonatomic, strong) ECSlidingInteractiveTransition *defaultInteractiveTransition;
@property (nonatomic, strong) id<UIViewControllerAnimatedTransitioning> currentAnimationController;
@property (nonatomic, strong) id<UIViewControllerInteractiveTransitioning> currentInteractiveTransition;
@property (nonatomic, assign) CGFloat currentAnimationPercentage;
@property (nonatomic, assign) BOOL preserveLeftPeekAmount;
@property (nonatomic, assign) BOOL preserveRightPeekAmount;
@property (nonatomic, assign) BOOL transitionWasCancelled;
@property (nonatomic, assign) BOOL isAnimated;
@property (nonatomic, assign) BOOL isInteractive;
@property (nonatomic, copy) void (^animationComplete)();
- (void)setup;

- (CGRect)topViewCalculatedFrameForPosition:(ECSlidingViewControllerTopViewPosition)position;
- (CGRect)underLeftViewCalculatedFrame;
- (CGRect)underRightViewCalculatedFrame;
- (ECSlidingViewControllerOperation)operationFromPosition:(ECSlidingViewControllerTopViewPosition)fromPosition
                                               toPosition:(ECSlidingViewControllerTopViewPosition)toPosition;
- (void)animateOperation:(ECSlidingViewControllerOperation)operation;
- (BOOL)operationIsValid:(ECSlidingViewControllerOperation)operation;
@end

@implementation ECSlidingViewController

#pragma mark - Constructors

- (id)init {
    return [self initWithTopViewController:nil];
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self setup];
    }
    
    return self;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        [self setup];
    }
    
    return self;
}

- (id)initWithTopViewController:(UIViewController *)topViewController {
    self = [self initWithNibName:nil bundle:nil];
    if (self) {
        self.topViewController = topViewController;
    }
    
    return self;
}

- (void)setup {
    self.anchorLeftPeekAmount    = 44;
    self.anchorRightRevealAmount = 276;
    _currentTopViewPosition = ECSlidingViewControllerTopViewPositionCentered;
    self.underLeftViewLayout  = ECSlidingViewLayoutTopContainer | ECSlidingViewLayoutBottomContainer | ECSlidingViewLayoutWidthReveal;
    self.underRightViewLayout = ECSlidingViewLayoutTopContainer | ECSlidingViewLayoutBottomContainer | ECSlidingViewLayoutWidthReveal;
    self.topViewLayout        = ECSlidingViewLayoutTopContainer | ECSlidingViewLayoutBottomContainer;
}

#pragma mark - UIViewController

- (void)awakeFromNib {
    if (self.topViewControllerStoryboardId) {
        self.topViewController = [self.storyboard instantiateViewControllerWithIdentifier:self.topViewControllerStoryboardId];
    }
    
    if (self.underLeftViewControllerStoryboardId) {
        self.underLeftViewController = [self.storyboard instantiateViewControllerWithIdentifier:self.underLeftViewControllerStoryboardId];
    }
    
    if (self.underRightViewControllerStoryboardId) {
        self.underRightViewController = [self.storyboard instantiateViewControllerWithIdentifier:self.underRightViewControllerStoryboardId];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    if (!self.topViewController) [NSException raise:@"Missing topViewController"
                                             format:@"Set the topViewController before loading ECSlidingViewController"];
    self.topViewController.view.frame = [self topViewCalculatedFrameForPosition:self.currentTopViewPosition];
    [self.view addSubview:self.topViewController.view];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.topViewController beginAppearanceTransition:YES animated:animated];
    
    if (self.currentTopViewPosition == ECSlidingViewControllerTopViewPositionAnchoredLeft) {
        [self.underRightViewController beginAppearanceTransition:YES animated:animated];
    } else if (self.currentTopViewPosition == ECSlidingViewControllerTopViewPositionAnchoredRight) {
        [self.underLeftViewController beginAppearanceTransition:YES animated:animated];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.topViewController endAppearanceTransition];
    
    if (self.currentTopViewPosition == ECSlidingViewControllerTopViewPositionAnchoredLeft) {
        [self.underRightViewController endAppearanceTransition];
    } else if (self.currentTopViewPosition == ECSlidingViewControllerTopViewPositionAnchoredRight) {
        [self.underLeftViewController endAppearanceTransition];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.topViewController beginAppearanceTransition:NO animated:animated];
    
    if (self.currentTopViewPosition == ECSlidingViewControllerTopViewPositionAnchoredLeft) {
        [self.underRightViewController beginAppearanceTransition:NO animated:animated];
    } else if (self.currentTopViewPosition == ECSlidingViewControllerTopViewPositionAnchoredRight) {
        [self.underLeftViewController beginAppearanceTransition:NO animated:animated];
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self.topViewController endAppearanceTransition];
    
    if (self.currentTopViewPosition == ECSlidingViewControllerTopViewPositionAnchoredLeft) {
        [self.underRightViewController endAppearanceTransition];
    } else if (self.currentTopViewPosition == ECSlidingViewControllerTopViewPositionAnchoredRight) {
        [self.underLeftViewController endAppearanceTransition];
    }
}

- (void)viewWillLayoutSubviews {
    if (self.currentOperation == ECSlidingViewControllerOperationNone) {
        self.topViewController.view.frame = [self topViewCalculatedFrameForPosition:self.currentTopViewPosition];
        self.underLeftViewController.view.frame = [self underLeftViewCalculatedFrame];
        self.underRightViewController.view.frame = [self underRightViewCalculatedFrame];
    }
}

- (void)viewDidLayoutSubviews {
    if (self.currentOperation == ECSlidingViewControllerOperationNone) {
        self.topViewController.view.frame = [self topViewCalculatedFrameForPosition:self.currentTopViewPosition];
        self.underLeftViewController.view.frame = [self underLeftViewCalculatedFrame];
        self.underRightViewController.view.frame = [self underRightViewCalculatedFrame];
    }
}

- (BOOL)shouldAutomaticallyForwardAppearanceMethods {
    return NO;
}

- (BOOL)shouldAutomaticallyForwardRotationMethods {
    return YES;
}

#pragma mark - Properties

- (void)setTopViewController:(UIViewController *)topViewController {
    UIViewController *oldTopViewController = _topViewController;
    
    [oldTopViewController.view removeFromSuperview];
    [oldTopViewController willMoveToParentViewController:nil];
    [oldTopViewController beginAppearanceTransition:NO animated:NO];
    [oldTopViewController removeFromParentViewController];
    [oldTopViewController endAppearanceTransition];
    
    _topViewController = topViewController;
    
    if (_topViewController) {
        [self addChildViewController:_topViewController];
        [_topViewController didMoveToParentViewController:self];
        
        if ([self isViewLoaded]) {
            [_topViewController beginAppearanceTransition:YES animated:NO];
            _topViewController.view.frame = [self topViewCalculatedFrameForPosition:self.currentTopViewPosition];
            [self.view addSubview:_topViewController.view];
            [_topViewController endAppearanceTransition];
        }
    }
}

- (void)setUnderLeftViewController:(UIViewController *)underLeftViewController {
    UIViewController *oldUnderLeftViewController = _underLeftViewController;
    
    [oldUnderLeftViewController.view removeFromSuperview];
    [oldUnderLeftViewController willMoveToParentViewController:nil];
    [oldUnderLeftViewController beginAppearanceTransition:NO animated:NO];
    [oldUnderLeftViewController removeFromParentViewController];
    [oldUnderLeftViewController endAppearanceTransition];
    
    _underLeftViewController = underLeftViewController;
    
    if (_underLeftViewController) {
        [self addChildViewController:_underLeftViewController];
        [_underLeftViewController didMoveToParentViewController:self];
    }
}

- (void)setUnderRightViewController:(UIViewController *)underRightViewController {
    UIViewController *oldUnderRightViewController = _underRightViewController;
    
    [oldUnderRightViewController.view removeFromSuperview];
    [oldUnderRightViewController willMoveToParentViewController:nil];
    [oldUnderRightViewController beginAppearanceTransition:NO animated:NO];
    [oldUnderRightViewController removeFromParentViewController];
    [oldUnderRightViewController endAppearanceTransition];
    
    _underRightViewController = underRightViewController;
    
    if (_underRightViewController) {
        [self addChildViewController:_underRightViewController];
        [_underRightViewController didMoveToParentViewController:self];
    }
}

- (void)setAnchorLeftPeekAmount:(CGFloat)anchorLeftPeekAmount {
    _anchorLeftPeekAmount   = anchorLeftPeekAmount;
    _anchorLeftRevealAmount = CGFLOAT_MAX;
    self.preserveLeftPeekAmount = YES;
}

- (void)setAnchorLeftRevealAmount:(CGFloat)anchorLeftRevealAmount {
    _anchorLeftRevealAmount = anchorLeftRevealAmount;
    _anchorLeftPeekAmount   = CGFLOAT_MAX;
    self.preserveLeftPeekAmount = NO;
}

- (void)setAnchorRightPeekAmount:(CGFloat)anchorRightPeekAmount {
    _anchorRightPeekAmount   = anchorRightPeekAmount;
    _anchorRightRevealAmount = CGFLOAT_MAX;
    self.preserveRightPeekAmount = YES;
}

- (void)setAnchorRightRevealAmount:(CGFloat)anchorRightRevealAmount {
    _anchorRightRevealAmount = anchorRightRevealAmount;
    _anchorRightPeekAmount   = CGFLOAT_MAX;
    self.preserveRightPeekAmount = NO;
}

- (CGFloat)anchorLeftPeekAmount {
    if (_anchorLeftPeekAmount == CGFLOAT_MAX && _anchorLeftRevealAmount != CGFLOAT_MAX) {
        return CGRectGetWidth(self.view.bounds) - _anchorLeftRevealAmount;
    } else if (_anchorLeftPeekAmount != CGFLOAT_MAX && _anchorLeftRevealAmount == CGFLOAT_MAX) {
        return _anchorLeftPeekAmount;
    } else {
        return CGFLOAT_MAX;
    }
}

- (CGFloat)anchorLeftRevealAmount {
    if (_anchorLeftRevealAmount == CGFLOAT_MAX && _anchorLeftPeekAmount != CGFLOAT_MAX) {
        return CGRectGetWidth(self.view.bounds) - _anchorLeftPeekAmount;
    } else if (_anchorLeftRevealAmount != CGFLOAT_MAX && _anchorLeftPeekAmount == CGFLOAT_MAX) {
        return _anchorLeftRevealAmount;
    } else {
        return CGFLOAT_MAX;
    }
}

- (CGFloat)anchorRightPeekAmount {
    if (_anchorRightPeekAmount == CGFLOAT_MAX && _anchorRightRevealAmount != CGFLOAT_MAX) {
        return CGRectGetWidth(self.view.bounds) - _anchorRightRevealAmount;
    } else if (_anchorRightPeekAmount != CGFLOAT_MAX && _anchorRightRevealAmount == CGFLOAT_MAX) {
        return _anchorRightPeekAmount;
    } else {
        return CGFLOAT_MAX;
    }
}

- (CGFloat)anchorRightRevealAmount {
    if (_anchorRightRevealAmount == CGFLOAT_MAX && _anchorRightPeekAmount != CGFLOAT_MAX) {
        return CGRectGetWidth(self.view.bounds) - _anchorRightPeekAmount;
    } else if (_anchorRightRevealAmount != CGFLOAT_MAX && _anchorRightPeekAmount == CGFLOAT_MAX) {
        return _anchorRightRevealAmount;
    } else {
        return CGFLOAT_MAX;
    }
}

- (ECSlidingAnimationController *)defaultAnimationController {
    if (_defaultAnimationController) return _defaultAnimationController;
    
    _defaultAnimationController = [[ECSlidingAnimationController alloc] init];
    
    return _defaultAnimationController;
}

- (ECSlidingInteractiveTransition *)defaultInteractiveTransition {
    if (_defaultInteractiveTransition) return _defaultInteractiveTransition;
    
    _defaultInteractiveTransition = [[ECSlidingInteractiveTransition alloc] initWithSlidingViewController:self];
    _defaultInteractiveTransition.animationController = self.defaultAnimationController;
    
    return _defaultInteractiveTransition;
}

- (UIPanGestureRecognizer *)panGesture {
    if (_panGesture) return _panGesture;
    
    _panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(detectPanGestureRecognizer:)];
    
    return _panGesture;
}

#pragma mark - Public

- (void)anchorTopViewToRightAnimated:(BOOL)animated {
    [self anchorTopViewToRightAnimated:animated onComplete:nil];
}

- (void)anchorTopViewToLeftAnimated:(BOOL)animated {
    [self anchorTopViewToLeftAnimated:animated onComplete:nil];
}

- (void)resetTopViewAnimated:(BOOL)animated {
    [self resetTopViewAnimated:animated onComplete:nil];
}

- (void)anchorTopViewToRightAnimated:(BOOL)animated onComplete:(void (^)())complete {
    self.isAnimated = animated;
    self.animationComplete = complete;
    ECSlidingViewControllerOperation operation = [self operationFromPosition:self.currentTopViewPosition toPosition:ECSlidingViewControllerTopViewPositionAnchoredRight];
    [self animateOperation:operation];
}

- (void)anchorTopViewToLeftAnimated:(BOOL)animated onComplete:(void (^)())complete {
    self.isAnimated = animated;
    self.animationComplete = complete;
    ECSlidingViewControllerOperation operation = [self operationFromPosition:self.currentTopViewPosition toPosition:ECSlidingViewControllerTopViewPositionAnchoredLeft];
    [self animateOperation:operation];
}

- (void)resetTopViewAnimated:(BOOL)animated onComplete:(void(^)())complete {
    self.isAnimated = animated;
    self.animationComplete = complete;
    ECSlidingViewControllerOperation operation = [self operationFromPosition:self.currentTopViewPosition toPosition:ECSlidingViewControllerTopViewPositionCentered];
    [self animateOperation:operation];
}

#pragma mark - Private

- (CGRect)topViewCalculatedFrameForPosition:(ECSlidingViewControllerTopViewPosition)position {
    CGRect containerViewFrame = self.view.bounds;
    
    if (self.topViewLayout & ECSlidingViewLayoutTopTopLayoutGuide) {
        CGFloat topLayoutGuideLength = [self.topLayoutGuide length];
        containerViewFrame.origin.y     = topLayoutGuideLength;
        containerViewFrame.size.height -= topLayoutGuideLength;
    }
    
    if (self.topViewLayout & ECSlidingViewLayoutBottomBottomLayoutGuide) {
        CGFloat bottomLayoutGuideLength = [self.bottomLayoutGuide length];
        containerViewFrame.size.height -= bottomLayoutGuideLength;
    }
    
    switch(position) {
        case ECSlidingViewControllerTopViewPositionCentered:
            return containerViewFrame;
        case ECSlidingViewControllerTopViewPositionAnchoredLeft:
            containerViewFrame.origin.x = -self.anchorLeftRevealAmount;
            return containerViewFrame;
        case ECSlidingViewControllerTopViewPositionAnchoredRight:
            containerViewFrame.origin.x = self.anchorRightRevealAmount;
            return containerViewFrame;
        default:
            return CGRectZero;
    }
}

- (CGRect)underLeftViewCalculatedFrame {
    CGRect containerViewFrame = self.view.bounds;
    
    if (self.underLeftViewLayout & ECSlidingViewLayoutTopTopLayoutGuide) {
        CGFloat topLayoutGuideLength    = [self.topLayoutGuide length];
        containerViewFrame.origin.y     = topLayoutGuideLength;
        containerViewFrame.size.height -= topLayoutGuideLength;
    }
    
    if (self.underLeftViewLayout & ECSlidingViewLayoutBottomBottomLayoutGuide) {
        CGFloat bottomLayoutGuideLength = [self.bottomLayoutGuide length];
        containerViewFrame.size.height -= bottomLayoutGuideLength;
    }
    
    if (self.underLeftViewLayout & ECSlidingViewLayoutWidthReveal) {
        containerViewFrame.size.width = self.anchorRightRevealAmount;
    }
    
    return containerViewFrame;
}

- (CGRect)underRightViewCalculatedFrame {
    CGRect containerViewFrame = self.view.bounds;
    
    if (self.underRightViewLayout & ECSlidingViewLayoutTopTopLayoutGuide) {
        CGFloat topLayoutGuideLength    = [self.topLayoutGuide length];
        containerViewFrame.origin.y     = topLayoutGuideLength;
        containerViewFrame.size.height -= topLayoutGuideLength;
    }
    
    if (self.underRightViewLayout & ECSlidingViewLayoutBottomBottomLayoutGuide) {
        CGFloat bottomLayoutGuideLength = [self.bottomLayoutGuide length];
        containerViewFrame.size.height -= bottomLayoutGuideLength;
    }
    
    if (self.underRightViewLayout & ECSlidingViewLayoutWidthReveal) {
        containerViewFrame.origin.x   = self.anchorLeftPeekAmount;
        containerViewFrame.size.width = self.anchorLeftRevealAmount;
    }
    
    return containerViewFrame;
}

- (ECSlidingViewControllerOperation)operationFromPosition:(ECSlidingViewControllerTopViewPosition)fromPosition
                                               toPosition:(ECSlidingViewControllerTopViewPosition)toPosition {
    if (fromPosition == ECSlidingViewControllerTopViewPositionCentered &&
        toPosition   == ECSlidingViewControllerTopViewPositionAnchoredLeft) {
        return ECSlidingViewControllerOperationAnchorLeft;
    } else if (fromPosition == ECSlidingViewControllerTopViewPositionCentered &&
               toPosition   == ECSlidingViewControllerTopViewPositionAnchoredRight) {
        return ECSlidingViewControllerOperationAnchorRight;
    } else if (fromPosition == ECSlidingViewControllerTopViewPositionAnchoredLeft &&
               toPosition   == ECSlidingViewControllerTopViewPositionCentered) {
        return ECSlidingViewControllerOperationResetFromLeft;
    } else if (fromPosition == ECSlidingViewControllerTopViewPositionAnchoredRight &&
               toPosition   == ECSlidingViewControllerTopViewPositionCentered) {
        return ECSlidingViewControllerOperationResetFromRight;
    } else {
        return ECSlidingViewControllerOperationNone;
    }
}

- (void)animateOperation:(ECSlidingViewControllerOperation)operation {
    if (![self operationIsValid:operation]) return;
    
    self.currentOperation = operation;
    
    self.currentAnimationController = [self.delegate slidingViewController:self
                                           animationControllerForOperation:operation
                                                         topViewController:self.topViewController];
    
    if (self.currentAnimationController) {
        self.currentInteractiveTransition = [self.delegate slidingViewController:self
                                     interactionControllerForAnimationController:self.currentAnimationController];
        if (self.currentInteractiveTransition) {
            _isInteractive = YES;
        } else {
            self.defaultInteractiveTransition.animationController = self.currentAnimationController;
            self.currentInteractiveTransition = self.defaultInteractiveTransition;
        }
    } else {
        self.currentAnimationController = self.defaultAnimationController;
        
        self.defaultInteractiveTransition.animationController = self.currentAnimationController;
        self.currentInteractiveTransition = self.defaultInteractiveTransition;
    }
    
    UIViewController *viewControllerWillAppear;
    UIViewController *viewControllerWillDisappear;
    
    if (self.currentOperation == ECSlidingViewControllerOperationAnchorLeft) {
        viewControllerWillAppear = self.underRightViewController;
    } else if (self.currentOperation == ECSlidingViewControllerOperationAnchorRight) {
        viewControllerWillAppear = self.underLeftViewController;
    } else if (self.currentOperation == ECSlidingViewControllerOperationResetFromLeft) {
        viewControllerWillDisappear = self.underRightViewController;
    } else if (self.currentOperation == ECSlidingViewControllerOperationResetFromRight) {
        viewControllerWillDisappear = self.underLeftViewController;
    }
    
    [viewControllerWillAppear beginAppearanceTransition:YES animated:_isAnimated];
    [viewControllerWillDisappear beginAppearanceTransition:NO animated:_isAnimated];

    [CATransaction begin];
    [CATransaction setCompletionBlock:^{
        [viewControllerWillDisappear endAppearanceTransition];
        [viewControllerWillAppear endAppearanceTransition];
        
        if (_transitionWasCancelled) {
            [viewControllerWillDisappear beginAppearanceTransition:YES animated:_isAnimated];
            [viewControllerWillDisappear endAppearanceTransition];
            [viewControllerWillAppear beginAppearanceTransition:NO animated:_isAnimated];
            [viewControllerWillAppear endAppearanceTransition];
        }
    }];
    if ([self isInteractive]) {
        [self.currentInteractiveTransition startInteractiveTransition:self];
    } else {
        [self.currentAnimationController animateTransition:self];
    }
    [CATransaction commit];
}

- (BOOL)operationIsValid:(ECSlidingViewControllerOperation)operation {
    if (self.currentTopViewPosition == ECSlidingViewControllerTopViewPositionAnchoredLeft) {
        if (operation == ECSlidingViewControllerOperationResetFromLeft) return YES;
    } else if (self.currentTopViewPosition == ECSlidingViewControllerTopViewPositionAnchoredRight) {
        if (operation == ECSlidingViewControllerOperationResetFromRight) return YES;
    } else if (self.currentTopViewPosition == ECSlidingViewControllerTopViewPositionCentered) {
        if (operation == ECSlidingViewControllerOperationAnchorLeft  && self.underRightViewController) return YES;
        if (operation == ECSlidingViewControllerOperationAnchorRight && self.underLeftViewController)  return YES;
    }
    
    return NO;
}

#pragma mark - UIPanGestureRecognizer action

- (void)detectPanGestureRecognizer:(UIPanGestureRecognizer *)recognizer {
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        _isInteractive = YES;
    }
    
    [self.defaultInteractiveTransition updateTopViewHorizontalCenterWithRecognizer:recognizer];
}

#pragma mark - UIViewControllerContextTransitioning

- (UIView *)containerView {
    return self.view;
}

- (BOOL)isAnimated {
    return _isAnimated;
}

- (BOOL)isInteractive {
    return _isInteractive;
}

- (BOOL)transitionWasCancelled {
    return _transitionWasCancelled;
}

- (UIModalPresentationStyle)presentationStyle {
    return UIModalPresentationCustom;
}

- (void)updateInteractiveTransition:(CGFloat)percentComplete {
    
}

- (void)finishInteractiveTransition {
    _transitionWasCancelled = NO;
}

- (void)cancelInteractiveTransition {
    _transitionWasCancelled = YES;
}

- (void)completeTransition:(BOOL)didComplete {
    if (self.currentOperation == ECSlidingViewControllerOperationNone) return;
    
    if ([self.currentAnimationController respondsToSelector:@selector(animationEnded:)]) {
        [self.currentAnimationController animationEnded:didComplete];
    }
    
    if (self.animationComplete) self.animationComplete();
    self.animationComplete = nil;
    
    if ([self transitionWasCancelled]) {
        if (self.currentOperation == ECSlidingViewControllerOperationAnchorLeft) {
            _currentTopViewPosition = ECSlidingViewControllerTopViewPositionCentered;
        } else if (self.currentOperation == ECSlidingViewControllerOperationAnchorRight) {
            _currentTopViewPosition = ECSlidingViewControllerTopViewPositionCentered;
        } else if (self.currentOperation == ECSlidingViewControllerOperationResetFromLeft) {
            _currentTopViewPosition = ECSlidingViewControllerTopViewPositionAnchoredLeft;
        } else if (self.currentOperation == ECSlidingViewControllerOperationResetFromRight) {
            _currentTopViewPosition = ECSlidingViewControllerTopViewPositionAnchoredRight;
        }
    } else {
        if (self.currentOperation == ECSlidingViewControllerOperationAnchorLeft) {
            _currentTopViewPosition = ECSlidingViewControllerTopViewPositionAnchoredLeft;
        } else if (self.currentOperation == ECSlidingViewControllerOperationAnchorRight) {
            _currentTopViewPosition = ECSlidingViewControllerTopViewPositionAnchoredRight;
        } else if (self.currentOperation == ECSlidingViewControllerOperationResetFromLeft) {
            _currentTopViewPosition = ECSlidingViewControllerTopViewPositionCentered;
        } else if (self.currentOperation == ECSlidingViewControllerOperationResetFromRight) {
            _currentTopViewPosition = ECSlidingViewControllerTopViewPositionCentered;
        }
    }
    
    _transitionWasCancelled = NO;
    _isInteractive = NO;
    self.currentOperation = ECSlidingViewControllerOperationNone;
    self.topViewController.view.frame = [self topViewCalculatedFrameForPosition:self.currentTopViewPosition];
}

- (UIViewController *)viewControllerForKey:(NSString *)key {
    if ([key isEqualToString:ECTransitionContextTopViewControllerKey]) {
        return self.topViewController;
    } else if ([key isEqualToString:ECTransitionContextUnderLeftControllerKey]) {
        return self.underLeftViewController;
    } else if ([key isEqualToString:ECTransitionContextUnderRightControllerKey]) {
        return self.underRightViewController;
    }
    
    if (self.currentOperation == ECSlidingViewControllerOperationAnchorLeft) {
        if (key == UITransitionContextFromViewControllerKey) return self.topViewController;
        if (key == UITransitionContextToViewControllerKey)   return self.underRightViewController;
    } else if (self.currentOperation == ECSlidingViewControllerOperationAnchorRight) {
        if (key == UITransitionContextFromViewControllerKey) return self.topViewController;
        if (key == UITransitionContextToViewControllerKey)   return self.underLeftViewController;
    } else if (self.currentOperation == ECSlidingViewControllerOperationResetFromLeft) {
        if (key == UITransitionContextFromViewControllerKey) return self.underLeftViewController;
        if (key == UITransitionContextToViewControllerKey)   return self.topViewController;
    } else if (self.currentOperation == ECSlidingViewControllerOperationResetFromRight) {
        if (key == UITransitionContextFromViewControllerKey) return self.underRightViewController;
        if (key == UITransitionContextToViewControllerKey)   return self.topViewController;
    }
    
    return nil;
}

- (CGRect)initialFrameForViewController:(UIViewController *)vc {
    if (self.currentOperation == ECSlidingViewControllerOperationAnchorLeft) {
        if ([vc isEqual:self.topViewController]) return [self topViewCalculatedFrameForPosition:ECSlidingViewControllerTopViewPositionCentered];
        if ([vc isEqual:self.underRightViewController]) return [self underRightViewCalculatedFrame];
    } else if (self.currentOperation == ECSlidingViewControllerOperationAnchorRight) {
        if ([vc isEqual:self.topViewController]) return [self topViewCalculatedFrameForPosition:ECSlidingViewControllerTopViewPositionCentered];
        if ([vc isEqual:self.underLeftViewController])  return [self underLeftViewCalculatedFrame];
    } else if (self.currentOperation == ECSlidingViewControllerOperationResetFromLeft) {
        if ([vc isEqual:self.topViewController])        return [self topViewCalculatedFrameForPosition:ECSlidingViewControllerTopViewPositionAnchoredLeft];
        if ([vc isEqual:self.underRightViewController]) return [self underRightViewCalculatedFrame];
    } else if (self.currentOperation == ECSlidingViewControllerOperationResetFromRight) {
        if ([vc isEqual:self.topViewController])        return [self topViewCalculatedFrameForPosition:ECSlidingViewControllerTopViewPositionAnchoredRight];
        if ([vc isEqual:self.underLeftViewController])  return [self underLeftViewCalculatedFrame];
    }
    
    return CGRectZero;
}

- (CGRect)finalFrameForViewController:(UIViewController *)vc {
    if (self.currentOperation == ECSlidingViewControllerOperationAnchorLeft) {
        if (vc == self.topViewController)        return [self topViewCalculatedFrameForPosition:ECSlidingViewControllerTopViewPositionAnchoredLeft];
        if (vc == self.underRightViewController) return [self underRightViewCalculatedFrame];
    } else if (self.currentOperation == ECSlidingViewControllerOperationAnchorRight) {
        if (vc == self.topViewController) return [self topViewCalculatedFrameForPosition:ECSlidingViewControllerTopViewPositionAnchoredRight];
        if (vc == self.underLeftViewController)  return [self underLeftViewCalculatedFrame];
    } else if (self.currentOperation == ECSlidingViewControllerOperationResetFromLeft) {
        if (vc == self.topViewController) return [self topViewCalculatedFrameForPosition:ECSlidingViewControllerTopViewPositionCentered];
    } else if (self.currentOperation == ECSlidingViewControllerOperationResetFromRight) {
        if (vc == self.topViewController) return [self topViewCalculatedFrameForPosition:ECSlidingViewControllerTopViewPositionCentered];
    }
    
    return CGRectZero;
}

@end
