//
//  SlideNavigation.swift
//  SlideMenu
//
//  Created by ZhangChen on 10/12/15.
//  Copyright © 2015 Aryan Ghassemi. All rights reserved.
//

import UIKit

enum SlideMenu {
    case menuLeft
    case menuRight
}

protocol SlideNavigationControllerAnimator : NSObjectProtocol {
    func prepareMenuForAnimation(_ menu : SlideMenu)
    func animate(_ menu : SlideMenu, withProgress progress:CGFloat)
    func clear()
}

@objc protocol SSlideNavigationControllerDelegate : NSObjectProtocol {
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
        case all
        case root
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
                layer.shadowColor = UIColor.black.cgColor
                layer.shadowRadius = 10
                layer.shadowOpacity = 1
                layer.shadowPath = UIBezierPath(rect: self.view.bounds).cgPath
                layer.shouldRasterize = true
                layer.rasterizationScale = UIScreen.main.scale
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
    var menuRevealAnimator : SlideNavigationControllerAnimator? {
        willSet(newAnimator) {
            menuRevealAnimator?.clear()
        }
    }
    var menuRevealAnimationDuration = TimeInterval(MENU_SLIDE_ANIMATION_DURATION)
    var menuRevealAnimationOption = UIViewAnimationOptions.curveEaseOut
    
    
    fileprivate lazy var tapRecognizer : UITapGestureRecognizer! = UITapGestureRecognizer(target: self, action: #selector(SlideNavigationController.tapDetected(_:)))
    fileprivate lazy var panRecognizer : UIPanGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(SlideNavigationController.panDetected(_:)))
    
    fileprivate var draggingPoint = CGPoint.zero
    
    fileprivate var menuNeedsLayout = false
    fileprivate var lastRevealedMenu : SlideMenu?
    
    static var sharedInstance: SlideNavigationController? {
        get { return singletonInstance }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setUp()
    }
    override init(rootViewController: UIViewController) {
        super.init(rootViewController: rootViewController)
        setUp()
    }
    
    override init(navigationBarClass: AnyClass?, toolbarClass: AnyClass?) {
        super.init(navigationBarClass: navigationBarClass, toolbarClass: toolbarClass)
        setUp()
    }
    func setUp() {
        singletonInstance = self
        self.enableSwipeGesture = true
        self.enableShadow = true
        self.delegate = self
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        if !enableShadow {
            self.view.layer.shadowPath = UIBezierPath(rect: self.view.bounds).cgPath
        }
        enableTapGestureToCloseMenu(false)
        if menuNeedsLayout {
            self.updateMenuFrameAndTransformAccordingToOrientation()
            
            if  isMenuOpen && UIDevice.current.systemVersion.compare("8.0", options:.numeric, range: nil, locale: nil) != ComparisonResult.orderedAscending {
                let menu: SlideMenu = horizontalLocation > 0 ? .menuLeft : .menuRight
                open(menu, withDuration: 0, andCompletion: nil)
            }
            
            menuNeedsLayout = false
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        menuNeedsLayout = true
    }
    
    override func willRotate(to toInterfaceOrientation: UIInterfaceOrientation, duration: TimeInterval) {
        super.willRotate(to: toInterfaceOrientation, duration: duration)
        menuNeedsLayout = true
    }
    
    func bounce(_ menu: SlideMenu, withCompletion completion:(()->Void)?) {
        prepareMenuForReveal(menu)
        let movementDirection = (menu == .menuLeft) ? CGFloat(1) : CGFloat(-1)
        UIView.animate(withDuration: 0.16, delay: 0, options: UIViewAnimationOptions.curveEaseOut, animations: {self.moveHorizontallyToLocation(30 * movementDirection)}) { (_) -> Void in
            UIView.animate(withDuration: 0.1, delay: 0, options: .curveEaseIn, animations: {self.moveHorizontallyToLocation(0)}) { (_) -> Void in
                UIView.animate(withDuration: 0.12, delay: 0, options: .curveEaseOut, animations: {self.moveHorizontallyToLocation(16 * movementDirection) }) { (_) -> Void in
                    UIView.animate(withDuration: 0.08, delay: 0, options: .curveEaseIn, animations: { self.moveHorizontallyToLocation(0) }) { (_) -> Void in
                        UIView.animate(withDuration: 0.08, delay: 0, options: .curveEaseOut, animations: { self.moveHorizontallyToLocation(6 * movementDirection)}) { (_) -> Void in
                            UIView.animate(withDuration: 0.06, delay: 0, options: .curveEaseIn, animations: { () -> Void in
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
    
    func switchToViewController(_ viewController: UIViewController, withSlideOutAnimation: Bool, popType: PopType, andCompletion completion: (()->Void)?) {
        if let topViewController = topViewController {
            if avoidSwitchingToSameClassViewController && type(of: topViewController) === viewController.self {
            closeMenuWithCompletion(completion)
            return
            }
        }
        let switchAndCallCompletion = { (closeMenuBeforeCallingCompletion: Bool) -> Void in
            if popType == .all {
                self.viewControllers = [viewController]
            } else {
                super.popToRootViewController(animated: false)
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
                UIView.animate(withDuration: menuRevealAnimationDuration, delay: 0, options: menuRevealAnimationOption, animations: { let width = self.horizontalLocation; let moveLocation = self.horizontalLocation > 0 ? width : -1 * width; self.moveHorizontallyToLocation(moveLocation)}, completion: { (_)-> Void in switchAndCallCompletion(true)})
            } else {
                switchAndCallCompletion(true)
            }
        } else {
            switchAndCallCompletion(false)
        }
    }
    func switchToViewController(_ viewController: UIViewController, withCompletion completion:(()->Void)?) {
        self.switchToViewController(viewController, withSlideOutAnimation: true, popType: .root, andCompletion: completion)
    }
    func popToRootAndSwitch(_ toViewController: UIViewController, withSlideOutAnimation:Bool, andCompletion completion:(()->Void)? ) {
        self.switchToViewController(toViewController, withSlideOutAnimation: withSlideOutAnimation, popType: .root, andCompletion: completion)
    }
    func popToRootAndSwitch(_ toViewController: UIViewController, withCompletioncompletion completion:(()->Void)? ) {
        self.switchToViewController(toViewController, withSlideOutAnimation: true, popType: .root, andCompletion: completion)
    }
    
    func popAllAndSwitch(_ toViewController: UIViewController, withSlideOutAnimation: Bool, andCompletion completion: (()->Void)? ) {
        self.switchToViewController(toViewController, withSlideOutAnimation: withSlideOutAnimation, popType: .all, andCompletion: completion)
    }
    
    func popAllAndSwitch(_ toViewController: UIViewController, withCompletion completion: (()->Void)?) {
        self.switchToViewController(toViewController, withSlideOutAnimation: true, popType: .all, andCompletion: completion)
    }
    
    func toggleLeftMenu() {
        toggle(.menuLeft, withCompletion: nil)
    }
    func toggleRightMenu() {
        toggle(.menuRight, withCompletion: nil)
    }
    func toggle(_ menu: SlideMenu, withCompletion completion:(()->Void)?) {
        if isMenuOpen {
            closeMenuWithCompletion(completion)
        } else {
            self.open(menu, withCompletion: completion)
        }
    }
    
    fileprivate var horizontalLocation : CGFloat {
        get {
            let rect = view.frame
            let orient = UIApplication.shared.statusBarOrientation
            if UIDevice.current.systemVersion.compare("8.0", options:.numeric, range: nil, locale: nil) != ComparisonResult.orderedAscending {
                return rect.origin.x
            } else {
                if UIInterfaceOrientationIsLandscape(orient) {
                    return orient == .landscapeRight ? rect.origin.y : rect.origin.y * -1
                } else {
                    return orient == .portrait ? rect.origin.x : rect.origin.x * -1
                }
            }
        }
    }
    
    fileprivate var horizontalSize : CGFloat {
        get {
            let rect = view.frame
            let orient = UIApplication.shared.statusBarOrientation
            if UIDevice.current.systemVersion.compare("8.0", options:.numeric, range: nil, locale: nil) != ComparisonResult.orderedAscending {
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
    
    
    func postNotification(_ name: String, forMenu menu: SlideMenu) {
        let menuString = menu == .menuLeft ? "left" : "right"
        let userInfo = ["menu" : menuString]
        NotificationCenter.default.post(name: Notification.Name(rawValue: name), object: nil, userInfo: userInfo)
    }
    
    // UINavigationControllerDelegate
    
    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        if self.shouldDisplayMenu(.menuLeft, forViewController: viewController) {
            viewController.navigationItem.leftBarButtonItem = barButtonItemForMenu(.menuLeft)
        }
        if self.shouldDisplayMenu(.menuRight, forViewController: viewController) {
            viewController.navigationItem.rightBarButtonItem = barButtonItemForMenu(.menuRight)
        }
    }
    
    
    var isMenuOpen : Bool {
        get {
            return self.horizontalLocation != 0
        }
    }
    
    func closeMenuWithCompletion(_ completion: (()->Void)?) {
        closeMenu(menuRevealAnimationDuration, completion:completion)
    }
    
    func open(_ menu: SlideMenu, withCompletion completion: (()->Void)?) {
        open(menu, withDuration: self.menuRevealAnimationDuration, andCompletion:completion)
    }
    
    // IBActions
    func leftMenuSelected(_ sender: AnyObject?) {
        if isMenuOpen {
            closeMenuWithCompletion(nil)
        } else {
            open(.menuLeft, withCompletion:nil)
        }
    }
    func rightMenuSelected(_ sender: AnyObject?) {
        if isMenuOpen {
            closeMenuWithCompletion(nil)
        } else {
            open(.menuRight, withCompletion:nil)
        }
    }
    // Private Methods
    fileprivate var initialRectForMenu : CGRect {
        get {
            var rect = self.view.frame
            rect.origin.x = 0
            rect.origin.y = 0
            if UIDevice.current.systemVersion.compare("7.0", options:.numeric, range: nil, locale: nil) != ComparisonResult.orderedAscending {
                return rect
            }
            let orient = UIApplication.shared.statusBarOrientation
            if UIInterfaceOrientationIsLandscape(orient) {
                rect.origin.x = (orient == .landscapeRight) ? 0 : 20 // status bar height
                rect.size.width = view.frame.size.width
                    - 20
            } else {
                rect.origin.y = (orient == .portrait) ? 20 : 0 // status bar height
                rect.size.width = view.frame.size.height
                    - 20
            }
            return rect
            
        }
    }
    
    fileprivate func prepareMenuForReveal(_ menu: SlideMenu) {
        if let last = lastRevealedMenu {
            if menu == last {
                return
            }
        }
        let menuViewController = menu == .menuLeft ? leftMenu : rightMenu
        let removingMenuViewController = menu == .menuLeft ? rightMenu : leftMenu
        lastRevealedMenu = menu
        
        removingMenuViewController?.view.removeFromSuperview()
        if let subview = menuViewController?.view {
            self.view.window?.insertSubview(subview, at: 0)
            self.updateMenuFrameAndTransformAccordingToOrientation()
            menuRevealAnimator?.prepareMenuForAnimation(menu)
        }
    }
    
    fileprivate func updateMenuFrameAndTransformAccordingToOrientation(){
        let transform = view.transform
        leftMenu?.view.transform = transform
        rightMenu?.view.transform = transform
        
        leftMenu?.view.frame = initialRectForMenu
        rightMenu?.view.frame = initialRectForMenu
    }
    fileprivate func enableTapGestureToCloseMenu(_ enable : Bool) {
        if enable {
            if UIDevice.current.systemVersion.compare("7.0", options:.numeric, range: nil, locale: nil) != ComparisonResult.orderedAscending {
                self.interactivePopGestureRecognizer?.isEnabled = false
            }
            
            self.topViewController?.view.isUserInteractionEnabled = false
            self.view.addGestureRecognizer(self.tapRecognizer)
        } else {
            if UIDevice.current.systemVersion.compare("7.0", options:.numeric, range: nil, locale: nil) != ComparisonResult.orderedAscending {
                self.interactivePopGestureRecognizer?.isEnabled = true
            }
            
            self.topViewController?.view.isUserInteractionEnabled = true
            self.view.removeGestureRecognizer(self.tapRecognizer)
        }
    }
    fileprivate func toggle(_ menu: SlideMenu, withCompletion completion: @escaping ()->Void) {
        if isMenuOpen {
            closeMenuWithCompletion(completion)
        } else {
            open(menu, withCompletion:completion)
        }
    }
    fileprivate func barButtonItemForMenu(_ menu : SlideMenu) -> UIBarButtonItem{
        let selector = menu == .menuLeft ? "leftMenuSelected:" : "rightMenuSelected:"
        
        if let customButton = menu == .menuLeft ? self.leftBarButtonItem : self.rightBarButtonItem {
            customButton.action = Selector(selector)
            customButton.target = self
            return customButton
        } else  {
            let image = UIImage(named: "menu-button")
            return UIBarButtonItem(image: image, style: .plain, target: self, action: Selector(selector))
        }
        
    }
    fileprivate func shouldDisplayMenu(_ menu: SlideMenu, forViewController vc: UIViewController?) -> Bool {
        guard let _ = vc else {return false}
        if let vc = vc as? SSlideNavigationControllerDelegate {
            switch menu {
            case .menuRight:
                if vc.responds(to: #selector(SSlideNavigationControllerDelegate.slideNavigationControllerShouldDisplayRightMenu)) {
                    return true
                }
                
            case .menuLeft:
                if vc.responds(to:#selector(SSlideNavigationControllerDelegate.slideNavigationControllerShouldDisplayLeftMenu)) {
                    return true
                }
//                if vc.responds(to: #selector(SSlideNavigationControllerDelegate.slideNavigationControllerShouldDisplayLeftMenu")) {
//                    return true
            
            }
        }
    
        return false
    }
    fileprivate func open(_ menu: SlideMenu, withDuration duration : TimeInterval, andCompletion completion: (()->Void)?) {
        enableTapGestureToCloseMenu(true)
        prepareMenuForReveal(menu)
        UIView.animate(withDuration: duration, delay: 0, options: self.menuRevealAnimationOption, animations: { () -> Void in
            let width = self.horizontalSize
            let x = menu == .menuLeft ? width - self.slideOffset : -(width - self.slideOffset)
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
    fileprivate func closeMenu(_ duration : TimeInterval, completion: (()->Void)?) {
        enableTapGestureToCloseMenu(false)
        let menu: SlideMenu = horizontalLocation > 0 ? .menuLeft : .menuRight
        UIView.animate(withDuration: duration, delay: 0, options: menuRevealAnimationOption, animations: { () -> Void in
            self.moveHorizontallyToLocation(0)
            }) { (_) -> Void in
                completion?()
                self.postNotification(SlideNavigationControllerDidClose, forMenu: menu)
        }
    }
    
    
    
    fileprivate func moveHorizontallyToLocation(_ location: CGFloat) {
        var rect =  self.view.frame
        let orient = UIApplication.shared.statusBarOrientation
        let menu: SlideMenu = horizontalLocation >= 0 && location >= 0 ? .menuLeft : .menuRight
        if location > 0 && horizontalLocation <= 0 || location < 0 && horizontalLocation >= 0 {
            self.postNotification(SlideNavigationControllerDidReveal, forMenu: location > 0 ? .menuLeft : .menuRight)
        }
        if UIDevice.current.systemVersion.compare("7.0", options:.numeric, range: nil, locale: nil) != ComparisonResult.orderedAscending {
            rect.origin.x = location
            rect.origin.y = 0
        } else {
            if UIInterfaceOrientationIsLandscape(orient) {
                rect.origin.x = 0
                rect.origin.y = orient == .landscapeRight ? location : location * -1
            } else {
                rect.origin.x = orient == .portrait ? location : location * -1
                rect.origin.y = 0
            }
        }
        self.view.frame = rect
        
        updateMenuAnimation(menu)
    }
    
    fileprivate func updateMenuAnimation(_ menu: SlideMenu) {
        let progress : CGFloat = menu == .menuLeft ? (horizontalLocation / (horizontalSize - slideOffset)) : (horizontalLocation / ((horizontalSize - slideOffset) * -1))
        menuRevealAnimator?.animate(menu, withProgress: progress)
    }
    
    
    // Gesture Recognizing
    func tapDetected(_ tapRecognizer: UITapGestureRecognizer) {
        self.closeMenuWithCompletion(nil)
    }
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if panGestureSideOffset == 0 {
            return true
        }
        let pointInView = touch.location(in: self.view)
        let horizontalSize = self.horizontalSize
        return pointInView.x <= panGestureSideOffset || pointInView.x >= horizontalSize - self.panGestureSideOffset
    }
    var lastHorizontalLocation = CGFloat(0)
    func panDetected(_ panRecognizer: UIPanGestureRecognizer) {
        let translation = panRecognizer.translation(in: panRecognizer.view)
        let velocity = panRecognizer.velocity(in: panRecognizer.view)
        let movement = translation.x - self.draggingPoint.x
        
        let horizontalLoc = self.horizontalLocation
        var  currentMenu : SlideMenu
        if horizontalLoc > 0 {
            currentMenu = .menuLeft
        } else if horizontalLoc < 0 {
            currentMenu = .menuRight
        } else {
            currentMenu = translation.x > 0 ? .menuLeft : .menuRight
        }
        guard self.shouldDisplayMenu(currentMenu, forViewController: self.topViewController) else {
            return
        }
        self.prepareMenuForReveal(currentMenu)
        
        switch panRecognizer.state {
        case .began:
            draggingPoint = translation
        case .changed:
            
            lastHorizontalLocation = horizontalLocation
            let newHorizontalLocation = lastHorizontalLocation + movement
            if newHorizontalLocation >= minXForDragging && newHorizontalLocation <= maxXForDragging {
                moveHorizontallyToLocation(newHorizontalLocation)
            }
            draggingPoint = translation
        case .ended:
            let currentX = horizontalLocation
            let currentXOffset = fabs(currentX)
            let positiveVelocity = fabs(velocity.x)
            
            // positiveVelocity >= MENU_FAST_VELOCITY_FOR_SWIPE_FOLLOW_DIRECTION
            if positiveVelocity >= 1200 {
                let quickAnimationDuration = TimeInterval(0.18)
                let menu : SlideMenu = velocity.x > 0 ? .menuLeft : .menuRight
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
                    open( currentX > 0 ? .menuLeft : .menuRight, withCompletion:nil)
                }
            }
        default:
            break
        }
    }
    var slideOffset: CGFloat {
        get {
            return UIInterfaceOrientationIsLandscape(UIApplication.shared.statusBarOrientation) ? landscapeSlideOffset : portraitSlideOffset
        }
    }
    var minXForDragging: CGFloat {
        get {
            if self.shouldDisplayMenu(.menuRight, forViewController: self.topViewController!) {
                return (self.horizontalSize - self.slideOffset) * -1
            }
            return 0
        }
    }
    var maxXForDragging: CGFloat {
        get {
            if self.shouldDisplayMenu(.menuLeft, forViewController: self.topViewController!) {
                return (self.horizontalSize - self.slideOffset)
            }
            return 0
        }
    }
    
    override func popToRootViewController(animated: Bool) -> [UIViewController]? {
        if isMenuOpen {
            closeMenuWithCompletion({
                super.popToRootViewController(animated: animated)
            })
        } else {
            return super.popToRootViewController(animated: animated)
        }
        return nil
    }
    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        if isMenuOpen {
            closeMenuWithCompletion { super.pushViewController(viewController, animated: animated)}
        } else {
            super.pushViewController(viewController, animated: animated)
        }
    }
    override func popToViewController(_ viewController: UIViewController, animated: Bool) -> [UIViewController]? {
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
    fileprivate var fadeAnimationView : UIView!
    init(maximumFadeAlpha: CGFloat, fadeColor: UIColor) {
        self.maximumFadeAlpha = maximumFadeAlpha
        self.fadeColor = fadeColor
        self.fadeAnimationView = UIView()
        self.fadeAnimationView.backgroundColor = fadeColor
    }
    convenience override init() {
        self.init(maximumFadeAlpha: 0.8, fadeColor: UIColor.black)
    }
    
    func prepareMenuForAnimation(_ menu: SlideMenu) {
        let menuViewController : UIViewController = menu == .menuLeft ? SlideNavigationController.sharedInstance!.leftMenu! : SlideNavigationController.sharedInstance!.rightMenu!
        
        self.fadeAnimationView.alpha = self.maximumFadeAlpha
        self.fadeAnimationView.frame = menuViewController.view.bounds
    }
    
    func animate(_ menu: SlideMenu, withProgress progress: CGFloat) {
        let menuViewController : UIViewController = menu == .menuLeft ? SlideNavigationController.sharedInstance!.leftMenu! : SlideNavigationController.sharedInstance!.rightMenu!
        
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
    
    func prepareMenuForAnimation(_ menu: SlideMenu) {
        let menuViewController : UIViewController = menu == .menuLeft ? SlideNavigationController.sharedInstance!.leftMenu! : SlideNavigationController.sharedInstance!.rightMenu!
        
        let orient = UIApplication.shared.statusBarOrientation
        var rect = menuViewController.view.frame
        if UIDevice.current.systemVersion.compare("8.0", options:.numeric, range: nil, locale: nil) != ComparisonResult.orderedAscending {
            rect.origin.x = menu == .menuLeft ? -slideMovement : slideMovement
        } else {
            if UIInterfaceOrientationIsLandscape(orient) {
                if orient == .landscapeRight {
                    rect.origin.y = menu == .menuLeft ? -slideMovement : slideMovement
                } else {
                    rect.origin.y = menu == .menuRight ? -slideMovement : slideMovement
                }
            } else {
                if orient == .portrait {
                    rect.origin.x = menu == .menuLeft ? -slideMovement : slideMovement
                } else {
                    rect.origin.x = menu == .menuRight ? -slideMovement : slideMovement
                }
            }
            
        }
    }
    func animate(_ menu: SlideMenu, withProgress progress: CGFloat) {
        let menuViewController : UIViewController = menu == .menuLeft ? SlideNavigationController.sharedInstance!.leftMenu! : SlideNavigationController.sharedInstance!.rightMenu!
        
        let orient = UIApplication.shared.statusBarOrientation
        var location :CGFloat
        switch menu {
        case .menuLeft:
            location = min(0, slideMovement * (progress - 1))
        case .menuRight:
            location = max(0, slideMovement * (1 - progress))
        }
        
        var rect = menuViewController.view.frame
        
        if UIDevice.current.systemVersion.compare("8.0", options:.numeric, range: nil, locale: nil) != ComparisonResult.orderedAscending {
            rect.origin.x = location
        } else {
            if UIInterfaceOrientationIsLandscape(orient) {
                rect.origin.y = orient == .landscapeRight ? location : location * -1
            } else {
                rect.origin.x = orient == .portrait ? location : location * -1
            }
        }
        menuViewController.view.frame = rect
    }
    func clear() {
        clear(.menuLeft)
        clear(.menuRight)
    }
    func clear(_ menu: SlideMenu) {
        let menuViewController : UIViewController = menu == .menuLeft ? SlideNavigationController.sharedInstance!.leftMenu! : SlideNavigationController.sharedInstance!.rightMenu!
        let orient = UIApplication.shared.statusBarOrientation
        var rect = menuViewController.view.frame
        if UIDevice.current.systemVersion.compare("8.0", options:.numeric, range: nil, locale: nil) != ComparisonResult.orderedAscending {
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
