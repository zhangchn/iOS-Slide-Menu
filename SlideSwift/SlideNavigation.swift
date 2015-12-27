//
//  SlideNavigation.swift
//  SlideMenu
//
//  Created by ZhangChen on 10/12/15.
//  Copyright © 2015 Aryan Ghassemi. All rights reserved.
//

import UIKit

enum SSlideMenu {
    case MenuLeft
    case MenuRight
}

protocol SlideNavigationControllerAnimator : NSObjectProtocol {
    func prepareMenuForAnimation(menu : SSlideMenu)
    func animate(menu : SSlideMenu, withProgress progress:CGFloat)
    func clear()
}

protocol SSlideNavigationControllerDelegate {
    func slideNavigationControllerShouldDisplayRightMenu() -> Bool
    func slideNavigationControllerShouldDisplayLeftMenu() -> Bool
}

let MENU_SLIDE_ANIMATION_DURATION = 0.3
let MENU_DEFAULT_SLIDE_OFFSET = 60

var singletonInstance : SlideNavigationController?
let SlideNavigationControllerDidOpen = "SlideNavigationControllerDidOpen"
let SlideNavigationControllerDidClose = "SlideNavigationControllerDidClose"
let SlideNavigationControllerDidReveal = "SlideNavigationControllerDidReveal"

class SlideNavigationController: UINavigationController, UINavigationControllerDelegate, UIGestureRecognizerDelegate {
    enum PopType {
        case All
        case Root
    }
    
    var avoidSwitchingToSameClassViewController = true
    var enableSwipeGesture: Bool = true {
        didSet(oldValue) {
            if enableSwipeGesture {
                self.view.addGestureRecognizer(panRecognizer)
            } else {
                self.view.removeGestureRecognizer(panRecognizer)
            }
        }
    }
    var enableShadow :Bool = true {
        didSet(oldValue) {
            if enableShadow {
                let layer = self.view.layer
                layer.shadowColor = UIColor.blackColor().CGColor
                layer.shadowRadius = 10
                layer.shadowOpacity = 1
                layer.shadowPath = UIBezierPath(rect: self.view.bounds).CGPath
                layer.shouldRasterize = true
                layer.rasterizationScale = UIScreen.mainScreen().scale
            } else {
                self.view.layer.shadowOpacity = 0
                self.view.layer.shadowRadius = 0
            }
        }
    }
    
    var rightMenu : UIViewController? {
        willSet(newMenu) {
            rightMenu?.view.removeFromSuperview()
        }
    }
    var leftMenu : UIViewController? {
        willSet(newMenu) {
            leftMenu?.view.removeFromSuperview()
        }
    }
    var leftBarButtonItem : UIBarButtonItem!
    var rightBarButtonItem : UIBarButtonItem!
    
    var portraitSlideOffset = CGFloat(MENU_DEFAULT_SLIDE_OFFSET)
    var landscapeSlideOffset = CGFloat(MENU_DEFAULT_SLIDE_OFFSET)
    var panGestureSideOffset = CGFloat(0)
    var menuRevealAnimator : protocol<SlideNavigationControllerAnimator>? {
        willSet(newAnimator) {
            menuRevealAnimator?.clear()
        }
    }
    var menuRevealAnimationDuration = NSTimeInterval(MENU_SLIDE_ANIMATION_DURATION)
    var menuRevealAnimationOption = UIViewAnimationOptions.CurveEaseOut
    
    
    private lazy var tapRecognizer : UITapGestureRecognizer! = UITapGestureRecognizer(target: self, action: "tapDetected:")
    private lazy var panRecognizer : UIPanGestureRecognizer = UIPanGestureRecognizer(target: self, action: "panDetected:")
    
    private var draggingPoint = CGPointZero
    
    private var menuNeedsLayout = false
    private var lastRevealedMenu : SSlideMenu?
    
    static var sharedInstance: SlideNavigationController? {
        get { return singletonInstance }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        delegate = self
        setUp()
    }
    override init(rootViewController: UIViewController) {
        super.init(rootViewController: rootViewController)
        delegate = self
        setUp()
    }
    
    override init(navigationBarClass: AnyClass?, toolbarClass: AnyClass?) {
        super.init(navigationBarClass: navigationBarClass, toolbarClass: toolbarClass)
        delegate = self
        setUp()
    }
    func setUp() {
        singletonInstance = self
    }
    
    override func viewWillLayoutSubviews() {
        if !enableShadow {
            self.view.layer.shadowPath = UIBezierPath(rect: self.view.bounds).CGPath
        }
        enableSwipeGesture = false
        if menuNeedsLayout {
            self.updateMenuFrameAndTransformAccordingToOrientation()
            
            if UIDevice.currentDevice().systemVersion.compare("8.0", options:.NumericSearch, range: nil, locale: nil) != NSComparisonResult.OrderedAscending {
                let menu: SSlideMenu = horizontalLocation > 0 ? .MenuLeft : .MenuRight
                open(menu, withDuration: 0, andCompletion: nil)
            }
            
            menuNeedsLayout = false
        }
    }
    
    override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)
        menuNeedsLayout = true
    }
    
    override func willRotateToInterfaceOrientation(toInterfaceOrientation: UIInterfaceOrientation, duration: NSTimeInterval) {
        super.willRotateToInterfaceOrientation(toInterfaceOrientation, duration: duration)
        menuNeedsLayout = true
    }
    
    func bounce(menu: SSlideMenu, withCompletion completion:(()->Void)?) {
        prepareMenuForReveal(menu)
        let movementDirection = (menu == .MenuLeft) ? CGFloat(1) : CGFloat(-1)
        UIView.animateWithDuration(0.16, delay: 0, options: UIViewAnimationOptions.CurveEaseOut, animations: {self.moveHorizontallyToLocation(30 * movementDirection)}) { (_) -> Void in
            UIView.animateWithDuration(0.1, delay: 0, options: .CurveEaseIn, animations: {self.moveHorizontallyToLocation(0)}) { (_) -> Void in
                UIView.animateWithDuration(0.12, delay: 0, options: .CurveEaseOut, animations: {self.moveHorizontallyToLocation(16 * movementDirection) }) { (_) -> Void in
                    UIView.animateWithDuration(0.08, delay: 0, options: .CurveEaseIn, animations: { self.moveHorizontallyToLocation(0) }) { (_) -> Void in
                        UIView.animateWithDuration(0.08, delay: 0, options: .CurveEaseOut, animations: { self.moveHorizontallyToLocation(6 * movementDirection)}) { (_) -> Void in
                            UIView.animateWithDuration(0.06, delay: 0, options: .CurveEaseIn, animations: { () -> Void in
                                self.moveHorizontallyToLocation(0)
                                }) { (_) -> Void in
                                    completion?()
                            }
                        }
                    }
                }
            }
        }
    }
    
    func switchToViewController(viewController: UIViewController, withSlideOutAnimation: Bool, popType: PopType, andCompletion completion: (()->Void)?) {
        if avoidSwitchingToSameClassViewController && topViewController?.dynamicType === viewController.self {
            closeMenuWithCompletion(completion)
            return
        }
        let switchAndCallCompletion = { (closeMenuBeforeCallingCompletion: Bool) -> Void in
            if popType == .All {
                self.viewControllers = [viewController]
            } else {
                super.popToRootViewControllerAnimated(false)
                super.pushViewController(viewController, animated: false)
            }
            
            if closeMenuBeforeCallingCompletion {
                self.closeMenuWithCompletion(completion)
            } else {
                completion?()
            }
        }
        if isMenuOpen {
            if withSlideOutAnimation {
                UIView.animateWithDuration(menuRevealAnimationDuration, delay: 0, options: menuRevealAnimationOption, animations: { let width = self.horizontalLocation; let moveLocation = self.horizontalLocation > 0 ? width : -1 * width; self.moveHorizontallyToLocation(moveLocation)}, completion: { (_)-> Void in switchAndCallCompletion(true)})
            } else {
                switchAndCallCompletion(true)
            }
        } else {
            switchAndCallCompletion(false)
        }
    }
    func switchToViewController(viewController: UIViewController, withCompletion completion:(()->Void)?) {
        self.switchToViewController(viewController, withSlideOutAnimation: true, popType: .Root, andCompletion: completion)
    }
    func popToRootAndSwitch(toViewController: UIViewController, withSlideOutAnimation:Bool, andCompletion completion:(()->Void)? ) {
        self.switchToViewController(toViewController, withSlideOutAnimation: withSlideOutAnimation, popType: .Root, andCompletion: completion)
    }
    func popToRootAndSwitch(toViewController: UIViewController, withCompletioncompletion completion:(()->Void)? ) {
        self.switchToViewController(toViewController, withSlideOutAnimation: true, popType: .Root, andCompletion: completion)
    }
    
    func popAllAndSwitch(toViewController: UIViewController, withSlideOutAnimation: Bool, andCompletion completion: (()->Void)? ) {
        self.switchToViewController(toViewController, withSlideOutAnimation: withSlideOutAnimation, popType: .All, andCompletion: completion)
    }
    
    func popAllAndSwitch(toViewController: UIViewController, withCompletion completion: (()->Void)?) {
        self.switchToViewController(toViewController, withSlideOutAnimation: true, popType: .All, andCompletion: completion)
    }
    
    func toggleLeftMenu() {
        toggle(.MenuLeft, withCompletion: nil)
    }
    func toggleRightMenu() {
        toggle(.MenuRight, withCompletion: nil)
    }
    func toggle(menu: SSlideMenu, withCompletion completion:(()->Void)?) {
        if isMenuOpen {
            closeMenuWithCompletion(completion)
        } else {
            self.open(menu, withCompletion: completion)
        }
    }
    
    private var horizontalLocation : CGFloat {
        get {
            let rect = view.frame
            let orient = UIApplication.sharedApplication().statusBarOrientation
            if UIDevice.currentDevice().systemVersion.compare("8.0", options:.NumericSearch, range: nil, locale: nil) != NSComparisonResult.OrderedAscending {
                return rect.origin.x
            } else {
                if UIInterfaceOrientationIsLandscape(orient) {
                    return orient == .LandscapeRight ? rect.origin.y : rect.origin.y * -1
                } else {
                    return orient == .Portrait ? rect.origin.x : rect.origin.x * -1
                }
            }
        }
    }
    
    private var horizontalSize : CGFloat {
        get {
            let rect = view.frame
            let orient = UIApplication.sharedApplication().statusBarOrientation
            if UIDevice.currentDevice().systemVersion.compare("8.0", options:.NumericSearch, range: nil, locale: nil) != NSComparisonResult.OrderedAscending {
                return rect.size.width
            } else {
                if UIInterfaceOrientationIsLandscape(orient) {
                    return rect.size.height
                } else {
                    return rect.size.width
                }
            }
        }
    }
    
    
    func postNotification(name: String, forMenu menu: SSlideMenu) {
        let menuString = menu == .MenuLeft ? "left" : "right"
        let userInfo = ["menu" : menuString]
        NSNotificationCenter.defaultCenter().postNotificationName(name, object: nil, userInfo: userInfo)
    }
    
    // UINavigationControllerDelegate
    
    func navigationController(navigationController: UINavigationController, willShowViewController viewController: UIViewController, animated: Bool) {
        if self.shouldDisplayMenu(.MenuLeft, forViewController: viewController) {
            viewController.navigationItem.leftBarButtonItem = barButtonItemForMenu(.MenuLeft)
        }
        if self.shouldDisplayMenu(.MenuRight, forViewController: viewController) {
            viewController.navigationItem.rightBarButtonItem = barButtonItemForMenu(.MenuRight)
        }
    }
    
    
    var isMenuOpen : Bool {
        get {
            return self.horizontalLocation != 0
        }
    }
    
    func closeMenuWithCompletion(completion: (()->Void)?) {
        closeMenu(menuRevealAnimationDuration, completion:completion)
    }
    
    func open(menu: SSlideMenu, withCompletion completion: (()->Void)?) {
        open(menu, withDuration: self.menuRevealAnimationDuration, andCompletion:completion)
    }
    
    // IBActions
    func leftMenuSelected(sender: AnyObject?) {
        if isMenuOpen {
            closeMenuWithCompletion(nil)
        } else {
            open(.MenuLeft, withCompletion:nil)
        }
    }
    func rightMenuSelected(sender: AnyObject?) {
        if isMenuOpen {
            closeMenuWithCompletion(nil)
        } else {
            open(.MenuRight, withCompletion:nil)
        }
    }
    // Private Methods
    private var initialRectForMenu : CGRect {
        get {
            var rect = self.view.frame
            rect.origin.x = 0
            rect.origin.y = 0
            if UIDevice.currentDevice().systemVersion.compare("7.0", options:.NumericSearch, range: nil, locale: nil) != NSComparisonResult.OrderedAscending {
                return rect
            }
            let orient = UIApplication.sharedApplication().statusBarOrientation
            if UIInterfaceOrientationIsLandscape(orient) {
                rect.origin.x = (orient == .LandscapeRight) ? 0 : 20 // status bar height
                rect.size.width = view.frame.size.width
                    - 20
            } else {
                rect.origin.y = (orient == .Portrait) ? 20 : 0 // status bar height
                rect.size.width = view.frame.size.height
                    - 20
            }
            return rect
            
        }
    }
    
    private func prepareMenuForReveal(menu: SSlideMenu) {
        if let last = lastRevealedMenu {
            if menu == last {
                return
            }
        }
        let menuViewController = menu == .MenuLeft ? leftMenu : rightMenu
        let removingMenuViewController = menu == .MenuLeft ? rightMenu : leftMenu
        lastRevealedMenu = menu
        
        removingMenuViewController?.view.removeFromSuperview()
        self.view.window?.insertSubview((menuViewController?.view)!, atIndex: 0)
        self.updateMenuFrameAndTransformAccordingToOrientation()
        menuRevealAnimator?.prepareMenuForAnimation(menu)
    }
    
    private func updateMenuFrameAndTransformAccordingToOrientation(){
        let transform = view.transform
        leftMenu?.view.transform = transform
        rightMenu?.view.transform = transform
        
        leftMenu?.view.frame = initialRectForMenu
        rightMenu?.view.frame = initialRectForMenu
    }
    private func enableTapGestureToCloseMenu(enable : Bool) {
        if enable {
            if UIDevice.currentDevice().systemVersion.compare("7.0", options:.NumericSearch, range: nil, locale: nil) != NSComparisonResult.OrderedAscending {
                self.interactivePopGestureRecognizer?.enabled = false
            }
            
            self.topViewController?.view.userInteractionEnabled = false
            self.view.addGestureRecognizer(self.tapRecognizer)
        } else {
            if UIDevice.currentDevice().systemVersion.compare("7.0", options:.NumericSearch, range: nil, locale: nil) != NSComparisonResult.OrderedAscending {
                self.interactivePopGestureRecognizer?.enabled = true
            }
            
            self.topViewController?.view.userInteractionEnabled = true
            self.view.removeGestureRecognizer(self.tapRecognizer)
        }
    }
    private func toggle(menu: SSlideMenu, withCompletion completion: ()->Void) {
        if isMenuOpen {
            closeMenuWithCompletion(completion)
        } else {
            open(menu, withCompletion:completion)
        }
    }
    private func barButtonItemForMenu(menu : SSlideMenu) -> UIBarButtonItem{
        let selector = menu == .MenuLeft ? "leftMenuSelected:" : "rightMenuSelected:"
        
        if let customButton = menu == .MenuLeft ? self.leftBarButtonItem : self.rightBarButtonItem {
            customButton.action = Selector(selector)
            customButton.target = self
            return customButton
        } else  {
            let image = UIImage(named: "menu-button")
            return UIBarButtonItem(image: image, style: .Plain, target: self, action: Selector(selector))
        }
        
    }
    private func shouldDisplayMenu(menu: SSlideMenu, forViewController vc: UIViewController?) -> Bool {
        guard let _ = vc else {return false}
        switch menu {
        case .MenuRight:
            if vc!.respondsToSelector(Selector("slideNavigationControllerShouldDisplayRightMenu")){
                if let _ = vc as? SSlideNavigationControllerDelegate {
                    return true
                }
                
            }
        case .MenuLeft:
            if vc!.respondsToSelector(Selector("slideNavigationControllerShouldDisplayLeftMenu")){
                if let _ = vc as? SSlideNavigationControllerDelegate {
                    return true
                }
            }
        }
        return false
    }
    private func open(menu: SSlideMenu, withDuration duration : NSTimeInterval, andCompletion completion: (()->Void)?) {
        enableTapGestureToCloseMenu(true)
        prepareMenuForReveal(menu)
        UIView.animateWithDuration(duration, delay: 0, options: self.menuRevealAnimationOption, animations: { () -> Void in
            let width = self.horizontalSize
            let x = menu == .MenuLeft ? width - self.slideOffset : -(width - self.slideOffset)
            self.moveHorizontallyToLocation(x)
            }) { (_) -> Void in
                completion?()
                self.postNotification(SlideNavigationControllerDidOpen, forMenu: menu)
        }
        //        let menu: SSlideMenu = horizontalLocation > 0 ? .MenuLeft : .MenuRight
        //        UIView.animateWithDuration(duration, delay: 0, options: menuRevealAnimationOption, animations: { () -> Void in
        //            self.moveHorizontallyToLocation(0)
        //            }) { (_) -> Void in
        //                completion?()
        //                self.postNotification(SlideNavigationControllerDidClose, forMenu: menu)
        //        }
    }
    private func closeMenu(duration : NSTimeInterval, completion: (()->Void)?) {
        enableTapGestureToCloseMenu(false)
        let menu: SSlideMenu = horizontalLocation > 0 ? .MenuLeft : .MenuRight
        UIView.animateWithDuration(duration, delay: 0, options: menuRevealAnimationOption, animations: { () -> Void in
            self.moveHorizontallyToLocation(0)
            }) { (_) -> Void in
                completion?()
                self.postNotification(SlideNavigationControllerDidClose, forMenu: menu)
        }
    }
    
    
    
    private func moveHorizontallyToLocation(location: CGFloat) {
        var rect =  self.view.frame
        let orient = UIApplication.sharedApplication().statusBarOrientation
        let menu: SSlideMenu = horizontalLocation >= 0 && location >= 0 ? .MenuLeft : .MenuRight
        if location > 0 && horizontalLocation <= 0 || location < 0 && horizontalLocation >= 0 {
            self.postNotification(SlideNavigationControllerDidReveal, forMenu: location > 0 ? .MenuLeft : .MenuRight)
        }
        if UIDevice.currentDevice().systemVersion.compare("7.0", options:.NumericSearch, range: nil, locale: nil) != NSComparisonResult.OrderedAscending {
            rect.origin.x = location
            rect.origin.y = 0
        } else {
            if UIInterfaceOrientationIsLandscape(orient) {
                rect.origin.x = 0
                rect.origin.y = orient == .LandscapeRight ? location : location * -1
            } else {
                rect.origin.x = orient == .Portrait ? location : location * -1
                rect.origin.y = 0
            }
        }
        self.view.frame = rect
        
        updateMenuAnimation(menu)
    }
    
    private func updateMenuAnimation(menu: SSlideMenu) {
        let progress : CGFloat = menu == .MenuLeft ? (horizontalLocation / (horizontalSize - slideOffset)) : (horizontalLocation / ((horizontalSize - slideOffset) * -1))
        menuRevealAnimator?.animate(menu, withProgress: progress)
    }
    
    
    // Gesture Recognizing
    func tapDetected(tapRecognizer: UITapGestureRecognizer) {
        self.closeMenuWithCompletion(nil)
    }
    func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldReceiveTouch touch: UITouch) -> Bool {
        if panGestureSideOffset == 0 {
            return true
        }
        let pointInView = touch.locationInView(self.view)
        let horizontalSize = self.horizontalSize
        return pointInView.x <= panGestureSideOffset || pointInView.x >= horizontalSize - self.panGestureSideOffset
    }
    var lastHorizontalLocation = CGFloat(0)
    func panDetected(panRecognizer: UIPanGestureRecognizer) {
        let translation = panRecognizer.translationInView(panRecognizer.view)
        let velocity = panRecognizer.velocityInView(panRecognizer.view)
        let movement = translation.x - self.draggingPoint.x
        
        let horizontalLoc = self.horizontalLocation
        var  currentMenu : SSlideMenu
        if horizontalLoc > 0 {
            currentMenu = .MenuLeft
        } else if horizontalLoc < 0 {
            currentMenu = .MenuRight
        } else {
            currentMenu = translation.x > 0 ? .MenuLeft : .MenuRight
        }
        guard self.shouldDisplayMenu(currentMenu, forViewController: self.topViewController) else {
            return
        }
        self.prepareMenuForReveal(currentMenu)
        
        switch panRecognizer.state {
        case .Began:
            draggingPoint = translation
        case .Changed:
            
            lastHorizontalLocation = horizontalLocation
            let newHorizontalLocation = lastHorizontalLocation + movement
            if newHorizontalLocation >= minXForDragging && newHorizontalLocation <= maxXForDragging {
                moveHorizontallyToLocation(newHorizontalLocation)
            }
            draggingPoint = translation
        case .Ended:
            let currentX = horizontalLocation
            let currentXOffset = fabs(currentX)
            let positiveVelocity = fabs(velocity.x)
            
            // positiveVelocity >= MENU_FAST_VELOCITY_FOR_SWIPE_FOLLOW_DIRECTION
            if positiveVelocity >= 1200 {
                let quickAnimationDuration = NSTimeInterval(0.18)
                let menu : SSlideMenu = velocity.x > 0 ? .MenuLeft : .MenuRight
                if velocity.x > 0 {
                    if currentX > 0 {
                        if shouldDisplayMenu(menu, forViewController: self.visibleViewController) {
                            self.open(menu, withDuration: quickAnimationDuration, andCompletion: nil)
                        }
                        
                    } else {
                        self.closeMenu(quickAnimationDuration, completion: nil)
                    }
                } else {
                    if currentX > 0 {
                        self.closeMenu(quickAnimationDuration, completion: nil)
                    } else {
                        if self.shouldDisplayMenu(menu, forViewController: self.visibleViewController) {
                            self.open(menu, withDuration: quickAnimationDuration, andCompletion: nil)
                        }
                    }
                }
            } else {
                if currentXOffset < (horizontalSize - slideOffset) / 2 {
                    self.closeMenuWithCompletion(nil)
                } else {
                    open( currentX > 0 ? .MenuLeft : .MenuRight, withCompletion:nil)
                }
            }
        default:
            break
        }
    }
    var slideOffset: CGFloat {
        get {
            return UIInterfaceOrientationIsLandscape(UIApplication.sharedApplication().statusBarOrientation) ? landscapeSlideOffset : portraitSlideOffset
        }
    }
    var minXForDragging: CGFloat {
        get {
            if self.shouldDisplayMenu(.MenuRight, forViewController: self.topViewController!) {
                return (self.horizontalSize - self.slideOffset) * -1
            }
            return 0
        }
    }
    var maxXForDragging: CGFloat {
        get {
            if self.shouldDisplayMenu(.MenuLeft, forViewController: self.topViewController!) {
                return (self.horizontalSize - self.slideOffset)
            }
            return 0
        }
    }
    
    override func popToRootViewControllerAnimated(animated: Bool) -> [UIViewController]? {
        if isMenuOpen {
            closeMenuWithCompletion({
                super.popToRootViewControllerAnimated(animated)
            })
        } else {
            return super.popToRootViewControllerAnimated(animated)
        }
        return nil
    }
    override func pushViewController(viewController: UIViewController, animated: Bool) {
        if isMenuOpen {
            closeMenuWithCompletion { super.pushViewController(viewController, animated: animated)}
        } else {
            super.pushViewController(viewController, animated: animated)
        }
    }
    override func popToViewController(viewController: UIViewController, animated: Bool) -> [UIViewController]? {
        if isMenuOpen {
            closeMenuWithCompletion({
                super.popToViewController(viewController, animated: animated)
            })
        } else {
            return super.popToViewController(viewController, animated: animated)
        }
        return nil
    }
}

//@interface SlideNavigationContorllerAnimatorFade : NSObject <SlideNavigationContorllerAnimator>
//
//@property (nonatomic, assign) CGFloat maximumFadeAlpha;
//@property (nonatomic, strong) UIColor *fadeColor;
//
//- (id)initWithMaximumFadeAlpha:(CGFloat)maximumFadeAlpha andFadeColor:(UIColor *)fadeColor;
//
//@end

class SlideNavigationControllerAnimatorFade: NSObject, SlideNavigationControllerAnimator {
    var maximumFadeAlpha: CGFloat
    var fadeColor: UIColor
    private var fadeAnimationView : UIView!
    init(maximumFadeAlpha: CGFloat, fadeColor: UIColor) {
        self.maximumFadeAlpha = maximumFadeAlpha
        self.fadeColor = fadeColor
        self.fadeAnimationView = UIView()
        self.fadeAnimationView.backgroundColor = fadeColor
    }
    convenience override init() {
        self.init(maximumFadeAlpha: 0.8, fadeColor: UIColor.blackColor())
    }
    
    func prepareMenuForAnimation(menu: SSlideMenu) {
        let menuViewController : UIViewController = menu == .MenuLeft ? SlideNavigationController.sharedInstance!.leftMenu! : SlideNavigationController.sharedInstance!.rightMenu!
        
        self.fadeAnimationView.alpha = self.maximumFadeAlpha
        self.fadeAnimationView.frame = menuViewController.view.bounds
    }
    
    func animate(menu: SSlideMenu, withProgress progress: CGFloat) {
        let menuViewController : UIViewController = menu == .MenuLeft ? SlideNavigationController.sharedInstance!.leftMenu! : SlideNavigationController.sharedInstance!.rightMenu!
        
        fadeAnimationView.alpha = self.maximumFadeAlpha
        fadeAnimationView.frame = menuViewController.view.bounds
    }
    func clear() {
        fadeAnimationView.removeFromSuperview()
    }
}

class SlideNavigationContorllerAnimatorSlide: NSObject, SlideNavigationControllerAnimator {
    var slideMovement: CGFloat
    init(slideMovement: CGFloat) {
        self.slideMovement = slideMovement
    }
    convenience override init() {
        self.init(slideMovement: 100)
    }
    
    func prepareMenuForAnimation(menu: SSlideMenu) {
        let menuViewController : UIViewController = menu == .MenuLeft ? SlideNavigationController.sharedInstance!.leftMenu! : SlideNavigationController.sharedInstance!.rightMenu!
        
        let orient = UIApplication.sharedApplication().statusBarOrientation
        var rect = menuViewController.view.frame
        if UIDevice.currentDevice().systemVersion.compare("8.0", options:.NumericSearch, range: nil, locale: nil) != NSComparisonResult.OrderedAscending {
            rect.origin.x = menu == .MenuLeft ? -slideMovement : slideMovement
        } else {
            if UIInterfaceOrientationIsLandscape(orient) {
                if orient == .LandscapeRight {
                    rect.origin.y = menu == .MenuLeft ? -slideMovement : slideMovement
                } else {
                    rect.origin.y = menu == .MenuRight ? -slideMovement : slideMovement
                }
            } else {
                if orient == .Portrait {
                    rect.origin.x = menu == .MenuLeft ? -slideMovement : slideMovement
                } else {
                    rect.origin.x = menu == .MenuRight ? -slideMovement : slideMovement
                }
            }
            
        }
    }
    func animate(menu: SSlideMenu, withProgress progress: CGFloat) {
        let menuViewController : UIViewController = menu == .MenuLeft ? SlideNavigationController.sharedInstance!.leftMenu! : SlideNavigationController.sharedInstance!.rightMenu!
        
        let orient = UIApplication.sharedApplication().statusBarOrientation
        var location :CGFloat
        switch menu {
        case .MenuLeft:
            location = min(0, slideMovement * (progress - 1))
        case .MenuRight:
            location = max(0, slideMovement * (1 - progress))
        }
        
        var rect = menuViewController.view.frame
        
        if UIDevice.currentDevice().systemVersion.compare("8.0", options:.NumericSearch, range: nil, locale: nil) != NSComparisonResult.OrderedAscending {
            rect.origin.x = location
        } else {
            if UIInterfaceOrientationIsLandscape(orient) {
                rect.origin.y = orient == .LandscapeRight ? location : location * -1
            } else {
                rect.origin.x = orient == .Portrait ? location : location * -1
            }
        }
        menuViewController.view.frame = rect
    }
    func clear() {
        clear(.MenuLeft)
        clear(.MenuRight)
    }
    func clear(menu: SSlideMenu) {
        let menuViewController : UIViewController = menu == .MenuLeft ? SlideNavigationController.sharedInstance!.leftMenu! : SlideNavigationController.sharedInstance!.rightMenu!
        let orient = UIApplication.sharedApplication().statusBarOrientation
        var rect = menuViewController.view.frame
        if UIDevice.currentDevice().systemVersion.compare("8.0", options:.NumericSearch, range: nil, locale: nil) != NSComparisonResult.OrderedAscending {
            rect.origin.x = 0
        } else {
            if UIInterfaceOrientationIsLandscape(orient) {
                rect.origin.y = 0
            } else {
                rect.origin.x = 0
            }
        }
        menuViewController.view.frame = rect
    }
}
