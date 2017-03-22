//
//  VenueConversationViewController.swift
//  HotMess
//
//  Created by Rick Mark on 3/21/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import UIKit
import Atlas
/*
class VenueConversationViewController : UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, CLLocationManagerDelegate {
    static let TypingIndicatorHeight: CGFloat = 20;
    static let MaxScrollDistanceFromBottom: CGFloat = 150;
    
    
    private var typingParticipantIDs: NSMutableArray = []
    private var typingIndicatorViewBottomConstraint: NSLayoutConstraint
    private var keyboardHeight: CGFloat = 0.0
    private var firstAppearance = true
    
    private var _collectionView = UICollectionView()

    /**
     @abstract IA boolean value to determine whether or not the receiver should display an `ATLAddressBarController`. If yes, applications should implement `ATLAddressBarControllerDelegate` and `ATLAddressBarControllerDataSource`. Default is no.
     */
    var displaysAddressBar: Bool
    
    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    }

    /**
     @abstract Returns a boolean value to determines whether or not the controller should scroll the collection view content to the bottom.
     @discussion Returns NO if the content is further than 150px from the bottom of the collection view or the collection view is currently scrolling.
     */
    var shouldScrollToBottom: Bool
    
    /**
     @abstract The `ATLAddressBarViewController` displayed for addressing new conversations or displaying names of current conversation participants.
     */
    var addressBarController: ATLAddressBarViewController?
    
    /**
     @abstract The `ATLMessageInputToolbar` displayed for user input.
     */
    var messageInputToolbar: ATLMessageInputToolbar
    
    /**
     @abstract An `ATLTypingIndicatorViewController` displayed to represent participants typing in a conversation.
     */
    var typingIndicatorController: ATLTypingIndicatorViewController
    
    /**
     @abstract The `UICollectionView` responsible for displaying messaging content.
     @discussion Subclasses should set the collection view property in their `loadView` method. The controller will then handle configuring autolayout constraints for the collection view.
     */
    var collectionView: UICollectionView {
        return _collectionView
    }
    
    ///----------------------------------------------
    /// @name Configuring View Options
    ///----------------------------------------------
    
    /**
     @abstract A constant representing the current height of the typing indicator.
     */
    var typingIndicatorInset: CGFloat = 0.0
    

    
    /**
     @abstract Initializes the input accessory view of the ATLBaseConversationViewController, which by default is an instance of ATLMessageInputToolbar. Override this method to return a subclass of ATLMessageInputToolbar.
     */
    func initializeMessageInputToolbar() -> ATLMessageInputToolbar {
        
    }
    
    ///-------------------------------------
    /// @name Managing Scrolling
    ///-------------------------------------
    

    
    /**
     @abstract Informs the controller that it should scroll the collection view to the bottom of its content.
     @param animated A boolean value to determine whether or not the scroll should be animated.
     */
    func scrollToBottomAnimated(animated: Bool) {
        
    }
    

    override func loadView()
    {
        self.view = ATLConversationView()
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
    
        // Add message input tool bar
        self.messageInputToolbar = self.initializeMessageInputToolbar()
        // Fixes an ios9 bug that causes the background of the input accessory view to be black when being presented on screen.
        self.messageInputToolbar.isTranslucent = false;
        // An apparent system bug causes a view controller to not be deallocated
        // if the view controller's own inputAccessoryView property is used.
        self.view.inputAccessoryView = self.messageInputToolbar;
        self.messageInputToolbar.containerViewController = self;
    
        // Add typing indicator
        self.typingIndicatorController = ATLTypingIndicatorViewController()
        self.addChildViewController(self.typingIndicatorController)
        self.view.addSubview(self.typingIndicatorController.view)
        self.typingIndicatorController.didMove(toParentViewController: self)
        self.configureTypingIndicatorLayoutConstraints()
    
        // Add address bar if needed
        if (self.displaysAddressBar) {
            self.addressBarController = ATLAddressBarViewController()
            self.addChildViewController(self.addressBarController)
            self.view.addSubview(self.addressBarController.view)
            self.addressBarController.didMove(toParentViewController: self)
            self.configureAddressbarLayoutConstraints()
        }
        self._baseRegisterForNotifications()
    }
    
    override func initializeMessageInputToolbar() -> ATLMessageInputToolbar
    {
        return ATLMessageInputToolbar()
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
    
        // Workaround for a modal dismissal causing the message toolbar to remain offscreen on iOS 8.
        if (self.presentedViewController != nil) {
            self.view.becomeFirstResponder()
        }
        if (self.addressBarController != nil && self.firstAppearance) {
            self.updateTopCollectionViewInset()
        }
        self.updateBottomCollectionViewInset()
    }
    
    override func viewDidAppear(_ animated: Bool)
    {
        if (self.displaysAddressBar != nil) {
            self.updateTopCollectionViewInset()
        }
        super.viewDidAppear(animated)
        self.messageInputToolbar.isTranslucent = true
    }
    
    override func viewDidLayoutSubviews()
    {
        super.viewDidLayoutSubviews()
    
        // To get the toolbar to slide onscreen with the view controller's content, we have to make the view the
        // first responder here. Even so, it will not animate on iOS 8 the first time.
        if (!self.presentedViewController != nil && self.navigationController != nil && self.view.inputAccessoryView.superview == nil) {
            self.view.becomeFirstResponder()
        }
    
        if (self.firstAppearance) {
            self.firstAppearance = false;
            // We use the content size of the actual collection view when calculating the ammount to scroll. Hence, we layout the collection view before scrolling to the bottom.
            self.view.layoutIfNeeded()
            self.scrollToBottomAnimated(false)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool)
    {
        super.viewWillDisappear(animated)
    
        self.messageInputToolbar.isTranslucent = false;
    }
    

    
    func setCollectionView(collectionView: UICollectionView)
    {
        _collectionView = collectionView;
        _collectionView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(self.collectionView)
        self.configureCollectionViewLayoutConstraints()
    }
    
    func setTypingIndicatorInset(typingIndicatorInset: CGFloat)
    {
        _typingIndicatorInset = typingIndicatorInset;
        UIView.animateWithDuration(0.1) {
            self.updateBottomCollectionViewInset()
        }
    }
    
    func shouldScrollToBottom() -> Bool
    {
        let bottomOffset = self.bottomOffsetForContentSize(self.collectionView.contentSize)
        let distanceToBottom = bottomOffset.y - self.collectionView.contentOffset.y;
        let shouldScrollToBottom = distanceToBottom <= MaxScrollDistanceFromBottom && !self.collectionView.isTracking && !self.collectionView.isDragging && !self.collectionView.isDecelerating;
        return shouldScrollToBottom;
    }
    
    func scrollToBottomAnimated(_ animated: Bool)
    {
        let contentSize = self.collectionView.contentSize;
        self.collectionView.setContentOffset(self.bottomOffsetForContentSize(contentSize), animated:animated)
    }
    
    func updateTopCollectionViewInset()
    {
        self.addressBarController!.view.layoutIfNeeded()
    
        let contentInset = self.collectionView.contentInset;
        let scrollIndicatorInsets = self.collectionView.scrollIndicatorInsets;
        let frame = self.view.convert(self.addressBarController!.addressBarView.frame, from: self.addressBarController!.addressBarView.superview)
    
        contentInset.top = frame.maxY
        scrollIndicatorInsets.top = contentInset.top;
        self.collectionView.contentInset = contentInset;
        self.collectionView.scrollIndicatorInsets = scrollIndicatorInsets;
    }
    
    func updateBottomCollectionViewInset()
    {
        self.messageInputToolbar.layoutIfNeeded()
    
        var insets = self.collectionView.contentInset;
        let keyboardHeight = max(self.keyboardHeight, self.messageInputToolbar.frame.height);
    
        insets.bottom = keyboardHeight + self.typingIndicatorInset;
        self.collectionView.scrollIndicatorInsets = insets;
        self.collectionView.contentInset = insets;
        self.typingIndicatorViewBottomConstraint.constant = -keyboardHeight;
    }
    
    
    func keyboardWillShow(_ notification: Notification)
    {
        if (self.navigationController?.modalPresentationStyle == .popover) {
            return;
        }
        
        self.configureWithKeyboardNotification(notification)
    }
    
    func keyboardWillHide(_ notification: Notification)
    {
        if (!self.navigationController?.viewControllers.contains(self) ?? false) {
            return;
        }
        self.configureWithKeyboardNotification(notification)
    }
    
    func messageInputToolbarDidChangeHeight(_ notification: Notification)
    {
        guard self.messageInputToolbar.superview == nil else { return }
    
        let toolbarFrame = self.view.convertRect(self.messageInputToolbar.frame, fromView:self.messageInputToolbar.superview)
        let keyboardOnscreenHeight = self.view.frame.height - toolbarFrame.minY
        if (keyboardOnscreenHeight == self.keyboardHeight) { return }
    
        let messagebarDidGrow = keyboardOnscreenHeight > self.keyboardHeight;
        self.keyboardHeight = keyboardOnscreenHeight;
        self.typingIndicatorViewBottomConstraint.constant = -self.collectionView.scrollIndicatorInsets.bottom;
        self.updateBottomCollectionViewInset()
    
        if (self.shouldScrollToBottom != nil && messagebarDidGrow) {
            self.scrollToBottomAnimated(true)
        }
    }
    
    func textViewTextDidBeginEditing(_ notification: Notification)
    {
        self.scrollToBottomAnimated(true)
    }
    
    func configureWithKeyboardNotification(_ notification: Notification) {
    
        let keyboardBeginFrame = notification.userInfo![UIKeyboardFrameBeginUserInfoKey] as! CGRect
        let keyboardBeginFrameInView = self.view.convert(keyboardBeginFrame, from: nil)
        let keyboardEndFrame = notification.userInfo![UIKeyboardFrameEndUserInfoKey] as! CGRect
        let keyboardEndFrameInView = self.view.convert(keyboardEndFrame, from: nil)
        let keyboardEndFrameIntersectingView = self.view.bounds.intersection(keyboardEndFrameInView)
    
        let keyboardHeight = keyboardEndFrameIntersectingView.height
        // Workaround for keyboard height inaccuracy on iOS 8.
        if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_7_1) {
            keyboardHeight -= self.messageInputToolbar.frame.minY
        }
        self.keyboardHeight = keyboardHeight;
    
        // Workaround for collection view cell sizes changing/animating when view is first pushed onscreen on iOS 8.
        if (keyboardBeginFrameInView.equalTo(keyboardEndFrameInView)) {
            UIView.performWithoutAnimation() {
                self.updateBottomCollectionViewInset()
            }
            return;
        }
    
        self.view.layoutIfNeeded()
        UIView.beginAnimations(nil, context:nil)
        UIView.setAnimationDuration(notification.userInfo[UIKeyboardAnimationDurationUserInfoKey], doubleValue)
        UIView.setAnimationCurve(notification.userInfo[UIKeyboardAnimationCurveUserInfoKey], integerValue)
        UIView.setAnimationBeginsFromCurrentState(true)
        self.updateBottomCollectionViewInset()
        self.view.layoutIfNeeded()
        UIView.commitAnimations()
    }
    
    
    func bottomOffsetForContentSize(contentSize: CGSize) -> CGPoint
    {
        let contentSizeHeight = contentSize.height;
        let collectionViewFrameHeight = self.collectionView.frame.size.height;
        let collectionViewBottomInset = self.collectionView.contentInset.bottom;
        let collectionViewTopInset = self.collectionView.contentInset.top;
        let offset = CGPoint(x: 0, y: max(-collectionViewTopInset, contentSizeHeight - (collectionViewFrameHeight - collectionViewBottomInset)));
        return offset;
    }
    
    override func updateViewConstraints()
    {
        let typingIndicatorBottomConstraintConstant = -self.collectionView.scrollIndicatorInsets.bottom;
        if (self.messageInputToolbar.superview != nil) {
            let toolbarFrame = self.view.convert(self.messageInputToolbar.frame, from:self.messageInputToolbar.superview)
            let keyboardOnscreenHeight = self.view.frame.height - toolbarFrame.minY;
            if (-keyboardOnscreenHeight > typingIndicatorBottomConstraintConstant) {
                typingIndicatorBottomConstraintConstant = -keyboardOnscreenHeight;
            }
        }
        self.typingIndicatorViewBottomConstraint.constant = typingIndicatorBottomConstraintConstant;
        super.updateViewConstraints()
    }
    
    func configureCollectionViewLayoutConstraints()
    {
        self.view.addConstraint(NSLayoutConstraint(item: self.collectionView, attribute: .left, relatedBy: .equal, toItem:self.view, attribute: .left, multiplier:1.0, constant:0))
        self.view.addConstraint(NSLayoutConstraint(item: self.collectionView, attribute: .right, relatedBy: .equal, toItem:self.view, attribute:.right, multiplier:1.0, constant:0))
        self.view.addConstraint(NSLayoutConstraint(item: self.collectionView, attribute: .top, relatedBy: .equal, toItem:self.view, attribute: .top, multiplier:1.0, constant:0))
        self.view.addConstraint(NSLayoutConstraint(item: self.collectionView, attribute: .bottom, relatedBy: .equal, toItem:self.view, attribute: .bottom, multiplier:1.0, constant:0))
    }
    
    func configureTypingIndicatorLayoutConstraints()
    {
        // Typing Indicator
        self.view.addConstraint(NSLayoutConstraint(item: self.typingIndicatorController.view, attribute: .left, relatedBy: .equal, toItem: self.view, attribute: .left, multiplier:1.0, constant:0))
        self.view.addConstraint(NSLayoutConstraint(item: self.typingIndicatorController.view, attribute: .width, relatedBy: .equal, toItem: self.view, attribute: .width, multiplier:1.0, constant:0))
        self.view.addConstraint(NSLayoutConstraint(item: self.typingIndicatorController.view, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier:1.0, constant: VenueConversationViewController.TypingIndicatorHeight))
            
        self.typingIndicatorViewBottomConstraint = NSLayoutConstraint(item: self.typingIndicatorController.view, attribute: .bottom, relatedBy: .equal, toItem:self.view, attribute: .bottom, multiplier:1.0, constant:0)
            
        self.view.addConstraint(self.typingIndicatorViewBottomConstraint)
    }
    
    func configureAddressbarLayoutConstraints()
    {
        // Address Bar
        self.view.addConstraint(NSLayoutConstraint(item: self.addressBarController.view, attribute: .left, relatedBy:.equal, toItem:self.view, attribute: .left, multiplier:1.0,constant:0))
        self.view.addConstraint(NSLayoutConstraint(item: self.addressBarController.view, attribute: .width, relatedBy: .equal, toItem:self.view, attribute: .width, multiplier:1.0, constant:0))
        self.view.addConstraint(NSLayoutConstraint(item: self.addressBarController.view, attribute: .top, relatedBy: .equal, toItem:self.topLayoutGuide, attribute: .bottom, multiplier:1.0, constant:0))
        self.view.addConstraint(NSLayoutConstraint(item: self.addressBarController.view, attribute: .bottom, relatedBy: .equal, toItem:self.view, attribute: .bottom, multiplier:1.0, constant:0))
    }
    

    internal func _baseRegisterForNotifications()
    {
        // Keyboard Notifications
        NotificationCenter.defaultCenter.addObserver(self, selector: #selector(keyboardWillShow:), name: UIKeyboardWillShowNotification, object:nil)
        NotificationCenter.defaultCenter.addObserver(self, selector: #selector(keyboardWillHide:), name: UIKeyboardWillHideNotification, object:nil)
    
        // ATLMessageInputToolbar Notifications
        NotificationCenter.defaultCenter.addObserver(self, selector: #selector(textViewTextDidBeginEditing:), name:UITextViewTextDidBeginEditingNotification, object:self.messageInputToolbar.textInputView)
        NotificationCenter.defaultCenter.addObserver(self, selector: #selector(messageInputToolbarDidChangeHeight:), name:ATLMessageInputToolbarDidChangeHeightNotification, object:self.messageInputToolbar)
    }

    
    deinit
    {
        NotificationCenter.default.removeObserver(self)
    }
}
*/
