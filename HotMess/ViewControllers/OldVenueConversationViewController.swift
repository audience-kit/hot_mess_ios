//
//  VenueConversationViewController.swift
//  HotMess
//
//  Created by Rick Mark on 3/21/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

//  The converted code is limited by 2 KB.
//  Upgrade your plan to remove this limitation.

//  Converted with Swiftify v1.0.6285 - https://objectivec2swift.com/
/*
import UIKit
import Atlas
import MapKit

enum ATLAvatarItemDisplayFrequency : Int {
    case section
    case cluster
    case all
}

protocol ATLConversationViewControllerDelegate: NSObjectProtocol {
    func conversationViewController(_ viewController: ATLConversationViewController, didSend message: LYRMessage)
    
    func conversationViewController(_ viewController: ATLConversationViewController, didFailSending message: LYRMessage, error: Error?)
    
    func conversationViewController(_ viewController: ATLConversationViewController, didSelect message: LYRMessage)
    
    func conversationViewController(_ viewController: ATLConversationViewController, heightFor message: LYRMessage, withCellWidth cellWidth: CGFloat) -> CGFloat
    
    func conversationViewController(_ conversationViewController: ATLConversationViewController, configureCell cell: ATLMessagePresenting, for message: LYRMessage)
    
    func conversationViewController(_ viewController: ATLConversationViewController, messagesForMediaAttachments mediaAttachments: [ ATLMediaAttachment ]) -> [ VenueMessage ]?
}

protocol ATLConversationViewControllerDataSource: NSObjectProtocol {
    func conversationViewController(_ conversationViewController: ATLConversationViewController, participantFor identity: LYRIdentity) -> ATLParticipant
    
    func conversationViewController(_ conversationViewController: ATLConversationViewController, attributedStringForDisplayOf date: Date) -> NSAttributedString
    
    func conversationViewController(_ conversationViewController: ATLConversationViewController, attributedStringForDisplayOfRecipientStatus recipientStatus: [ AnyHashable: Any ]) -> NSAttributedString
    func conversationViewController(_ viewController: ATLConversationViewController, reuseIdentifierFor message: LYRMessage) -> String?
    
    func conversationViewController(_ viewController: ATLConversationViewController, conversationWithParticipants participants: Set<AnyHashable>) -> LYRConversation
}

class VenueConversationViewController: ATLBaseConversationViewController, UICollectionViewDataSource, UICollectionViewDelegate, CLLocationManagerDelegate {
    
    static let ATLMoreMessagesSection = 0
    static let ATLPushNotificationSoundName = "layerbell.caf"
    static let ATLDefaultPushAlertGIF = "sent you a GIF."
    static let ATLDefaultPushAlertImage = "sent you a photo."
    static let ATLDefaultPushAlertLocation = "sent you a location."
    static let ATLDefaultPushAlertVideo = "sent you a video."
    static let ATLDefaultPushAlertText = "sent you a message."
    static let ATLPhotoActionSheet = 1000

    var conversationDataSource: ATLConversationDataSource
    var queryController: LYRQueryController
    var shouldDisplayAvatarItem: Bool
    var typingParticipantIDs: NSMutableOrderedSet
    var objectChanges: NSMutableArray
    var sectionHeaders: NSHashTable
    var sectionFooters: NSHashTable

    var showingMoreMessagesIndicator = false
    var hasAppeared = false

    var locationManager: ATLLocationManager
    var shouldShareLocation = false
    var canDisableAddressBar = false
    var animationQueue = DispatchQueue(label: "conversationViewControllerQueue")
    var expandingPaginationWindow = false

    static func sharedMediaAttachmentCache()
    {
        static _sharedCache: NSCache
        static onceToken: dispatch_once_t
        dispatch_once(&onceToken, ^{
            _sharedCache = [NSCache new];
        });
        return _sharedCache;
    }
    

    init(withCoder decoder: NSCoder)
    {
        self._commonInit()
        super.init(decoder)
    }
    
    init(conversation: VenueConversation) {
        super.init()
    }


    private func _commonInit()
    {
        dateDisplayTimeInterval = 60 * 60;
        marksMessagesAsRead = true
        shouldDisplayAvatarItemForOneOtherParticipant = false
        shouldDisplayAvatarItemForAuthenticatedUser = false
        avatarItemDisplayFrequency = ATLAvatarItemDisplayFrequencySection
        typingParticipantIDs = NSMutableOrderedSet()
        sectionHeaders = NSHashTable.weakObjectsHashTable()
        sectionFooters = NSHashTable.weakObjectsHashTable()
        objectChanges = NSMutableArray()
        animationQueue = dispatch_queue_create("com.atlas.animationQueue", DISPATCH_QUEUE_SERIAL);
    }
    
    func loadView()
    {
        super.loadView()
        // Collection View Setup
        self.collectionView = ATLConversationCollectionView(CGRect.zero, collectionViewLayout: UICollectionViewFlowLayout())
        self.collectionView.delegate = self;
        self.collectionView.dataSource = self;
    }
    
    func viewDidLoad()
    {
        super.viewDidLoad()
    
        self.configureControllerForConversation()
        self.messageInputToolbar.inputToolBarDelegate = self
        self.addressBarController.delegate = self
        self.canDisableAddressBar = true
        self._registerForNotifications()
    }
    
    func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
    
        if (self.addressBarController != nil && self.conversation.lastMessage && self.canDisableAddressBar) {
            self.addressBarController.disable()
            self.configureAddressBarForConversation()
        }
    
        self.canDisableAddressBar = true
        if (!self.hasAppeared) {
            self.collectionView.layoutIfNeeded()
        }
        if (!self.hasAppeared && self.class.sharedMediaAttachmentCache.objectForKey(self.conversation.identifier)) {
            self.loadCachedMediaAttachments()
        }
    
        // Track changes in authentication state to manipulate the query controller appropriately
        NotificationCenter.defaultCenter.addObserver(self, selector: #selector(self.layerClientDidAuthenticate:), name: LYRClientDidAuthenticateNotification, object: self.layerClient)
        NotificationCenter.defaultCenter.addObserver(self, selector: #selector(self.layerClientDidDeauthenticate), name:LYRClientDidDeauthenticateNotification, object: self.layerClient)
        NotificationCenter.defaultCenter.addObserver(self, selector: #selector(self.layerClientDidSwitchSession), name:LYRClientDidSwitchSessionNotification, object: self.layerClient)
    }
    
    func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
    
        self.hasAppeared = true
        self.configurePaginationWindow()
        self.configureMoreMessagesIndicatorVisibility()
    
        if (self.addressBarController != nil && !self.addressBarController.isDisabled) {
            self.addressBarController.addressBarView.addressBarTextView.becomeFirstResponder()
        }
    }
    
    deinit
    {
        if (self.messageInputToolbar.mediaAttachments.count > 0) {
            self.cacheMediaAttachments()
        }
        self.collectionView.delegate = nil;
        NotificationCenter.default.removeObserver(self)
    }
        
    func cacheMediaAttachments()
    {
        sharedMediaAttachmentCache.setObject(self.messageInputToolbar.mediaAttachments, forKey:self.conversation.identifier)
    }
    
    func loadCachedMediaAttachments()
    {
        let mediaAttachments = self.class.sharedMediaAttachmentCache.objectForKey(self.conversation.identifier)
        for (int i = 0; i < mediaAttachments.count; i++) {
            ATLMediaAttachment *attachment = [mediaAttachments objectAtIndex:i];
            BOOL shouldHaveLineBreak = (i < mediaAttachments.count - 1) || !(attachment.mediaMIMEType == ATLMIMETypeTextPlain);
            [self.messageInputToolbar insertMediaAttachment:attachment withEndLineBreak:shouldHaveLineBreak];
        }
        [[[self class] sharedMediaAttachmentCache] removeObjectForKey:self.conversation.identifier];
    }

    func setConversation(conversation: LYRConversation)
    {
        if (conversation == nil && self.conversation == nil) return;
        if ([conversation isEqual:self.conversation]) return;
    
        self.conversation = conversation;
    
        self.showingMoreMessagesIndicator = false
        self.typingParticipantIDs .removeAllObjects()
        self.updateTypingIndicatorOverlay(false)
    
        // Set up the controller for the conversation
        self.deinitializeConversationDataSource()
        self.setupConversationDataSource()
        self.configureControllerForConversation()
        self.configureAddressBarForChangedParticipants()
    
        let contentSize = self.collectionView.collectionViewLayout.collectionViewContentSize;
        self.collectionView setContentOffset:[self bottomOffsetForContentSize:contentSize] animated:NO];
    }
    
    func setupConversationDataSource()
    {
        NSAssert(self.conversationDataSource == nil, "Cannot initialize more than once");
        if (!self.conversation) return;
        
        LYRQuery *query = [LYRQuery queryWithQueryableClass:[LYRMessage class]];
        query.predicate = [LYRPredicate predicateWithProperty:@"conversation" predicateOperator:LYRPredicateOperatorIsEqualTo value:self.conversation];
        query.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"position" ascending:YES]];
        
        if ([self.dataSource respondsToSelector:@selector(conversationViewController:willLoadWithQuery:)]) {
            query = [self.dataSource conversationViewController:self willLoadWithQuery:query];
            if (![query isKindOfClass:[LYRQuery class]]){
                @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Data source must return an `LYRQuery` object." userInfo:nil];
            }
        }
            
        self.conversationDataSource = [ATLConversationDataSource dataSourceWithLayerClient:self.layerClient query:query];
        if (!self.conversationDataSource) {
            return;
        }
        self.conversationDataSource.queryController.delegate = self;
        self.queryController = self.conversationDataSource.queryController;
        self.showingMoreMessagesIndicator = [self.conversationDataSource moreMessagesAvailable];
        [self.collectionView reloadData];
    }
        
    func deinitializeConversationDataSource()
    {
        self.conversationDataSource = nil;
        self.conversationDataSource.queryController.delegate = nil;
        self.queryController = nil;
        self.collectionView.reloadData()
    }
            
    func layerClientDidAuthenticate(_ notification: NSNotification)
    {
        if (self.conversationDataSource == nil) {
            self.setupConversationDataSource()
        }
    }
    
    func layerClientDidSwitchSession(_ notification: NSNotification)
    {
        self.deinitializeConversationDataSource()
        self.setupConversationDataSource()
    }
    
    func layerClientDidDeauthenticate(_ notification: NSNotification)
    {
        self.deinitializeConversationDataSource()
    }


    func configureControllerForConversation()
    {
        // Configure avatar image display
        let otherParticipantIDs = self.conversation.participants.valueForKey("userID").mutableCopy()
        if (self.layerClient.authenticatedUser) otherParticipantIDs.removeObject(self.layerClient.authenticatedUser.userID)
        self.shouldDisplayAvatarItem = (otherParticipantIDs.count > 1) ? true : self.shouldDisplayAvatarItemForOneOtherParticipant
    
        // Configure message bar button enablement
        let shouldEnableButton = self.conversation != nil
        self.messageInputToolbar.rightAccessoryButton.enabled = shouldEnableButton;
        self.messageInputToolbar.leftAccessoryButton.enabled = shouldEnableButton;
    
        // Mark all messages as read if needed
        if (self.conversation.lastMessage != nil && self.marksMessagesAsRead) {
            self.conversation.markAllMessagesAsRead(nil)
        }
    }
    
    func configureAddressBarForConversation()
    {
        if (!self.dataSource) return;
        if (!self.addressBarController) return;
            
        let participantIdentifiers = [NSMutableOrderedSet orderedSetWithSet:[self.conversation.participants valueForKey:@"userID"]];
        if (participantIdentifiers.containsObject(self.layerClient.authenticatedUser.userID)) {
            participantIdentifiers.removeObject(self.layerClient.authenticatedUser.userID)
        }
        [self.addressBarController setSelectedParticipants:[self participantsForIdentifiers:participantIdentifiers]];
    }


    /**
     Atlas - The `ATLConversationViewController` component uses one `LYRMessage` to represent each row.
     */
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int
    {
        if (section == ATLMoreMessagesSection) { return 0 }
        // Each message is represented by one cell no matter how many parts it has.
        return 1
    }
    
    /**
     Atlas - The `ATLConversationViewController` component uses `LYRMessage` objects to represent sections.
     */
    func numberOfSectionsInCollectionView(_ collectionView: UICollectionView) -> Int
    {
        return self.conversationDataSource.queryController.numberOfObjectsInSection(0) + ATLNumberOfSectionsBeforeFirstMessageSection;
    }
    
    /**
     Atlas - Configuring a subclass of `ATLMessageCollectionViewCell` to be displayed on screen. `Atlas` supports both `ATLIncomingMessageCollectionViewCell` and `ATLOutgoingMessageCollectionViewCell`.
     */
    - (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
    {
        LYRMessage *message = [self.conversationDataSource messageAtCollectionViewIndexPath:indexPath];
        NSString *reuseIdentifier = [self reuseIdentifierForMessage:message atIndexPath:indexPath];
    
        UICollectionViewCell<ATLMessagePresenting> *cell =  [self.collectionView dequeueReusableCellWithReuseIdentifier:reuseIdentifier forIndexPath:indexPath];
        [self configureCell:cell forMessage:message indexPath:indexPath];
        if ([self.delegate respondsToSelector:@selector(conversationViewController:configureCell:forMessage:)]) {
            [self.delegate conversationViewController:self configureCell:cell forMessage:message];
        }
        return cell;
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath)
    {
        [self notifyDelegateOfMessageSelection:[self.conversationDataSource messageAtCollectionViewIndexPath:indexPath]];
    }

    - (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
    {
        return [self heightForMessageAtIndexPath:indexPath];
    }
    
    - (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
    {
        if (indexPath.section == ATLMoreMessagesSection) {
            ATLConversationCollectionViewMoreMessagesHeader *header = [self.collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:ATLMoreMessagesHeaderIdentifier forIndexPath:indexPath];
            return header;
        }
        if (kind == UICollectionElementKindSectionHeader) {
            ATLConversationCollectionViewHeader *header = [self.collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:ATLConversationViewHeaderIdentifier forIndexPath:indexPath];
            [self configureHeader:header atIndexPath:indexPath];
            [self.sectionHeaders addObject:header];
            return header;
        } else {
            ATLConversationCollectionViewFooter *footer = [self.collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:ATLConversationViewFooterIdentifier forIndexPath:indexPath];
            [self configureFooter:footer atIndexPath:indexPath];
            [self.sectionFooters addObject:footer];
            return footer;
        }
    }
    
    - (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout referenceSizeForHeaderInSection:(NSInteger)section
    {
        if (section == ATLMoreMessagesSection) {
            return self.showingMoreMessagesIndicator ? CGSizeMake(0, 30) : CGSizeZero;
        }
        NSAttributedString *dateString;
        NSString *participantName;
        if ([self shouldDisplayDateLabelForSection:section]) {
            dateString = [self attributedStringForMessageDate:[self.conversationDataSource messageAtCollectionViewSection:section]];
        }
        if ([self shouldDisplaySenderLabelForSection:section]) {
            participantName = [self participantNameForMessage:[self.conversationDataSource messageAtCollectionViewSection:section]];
        }
        CGFloat height = [ATLConversationCollectionViewHeader headerHeightWithDateString:dateString participantName:participantName inView:self.collectionView];
        return CGSizeMake(0, height);
    }
    
    - (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout referenceSizeForFooterInSection:(NSInteger)section
    {
        if (section == ATLMoreMessagesSection) return CGSizeZero;
        NSAttributedString *readReceipt;
        if ([self shouldDisplayReadReceiptForSection:section]) {
            readReceipt = [self attributedStringForRecipientStatusOfMessage:[self.conversationDataSource messageAtCollectionViewSection:section]];
        }
        BOOL shouldClusterMessage = [self shouldClusterMessageAtSection:section];
        CGFloat height = [ATLConversationCollectionViewFooter footerHeightWithRecipientStatus:readReceipt clustered:shouldClusterMessage];
        return CGSizeMake(0, height);
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView)
    {
        // When the keyboard is being dragged, we need to update the position of the typing indicator.
        self.view.setNeedsUpdateConstraints()
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool)
    {
        if (decelerate) { return }
        self.configurePaginationWindow()
        self.configureMoreMessagesIndicatorVisibility()
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView)
    {
        self.configurePaginationWindow()
        self.configureMoreMessagesIndicatorVisibility()
    }
    
    func scrollViewDidScrollToTop(_ scrollView: UIScrollView)
    {
        self.configurePaginationWindow()
        self.configureMoreMessagesIndicatorVisibility()
    }

    /**
     Atlas - Extracting the proper message part and analyzing its properties to determine the cell configuration.
     */
    func configureCell(_ cell: ATLMessagePresenting, forMessage message: LYRMessage, indexPath: NSIndexPath)
    {
        cell.presentMessage(message)
        let willDisplayAvatarItem = (![message.sender.userID isEqualToString:self.layerClient.authenticatedUser.userID]) ? self.shouldDisplayAvatarItem : (self.shouldDisplayAvatarItem && self.shouldDisplayAvatarItemForAuthenticatedUser);
        [cell shouldDisplayAvatarItem:willDisplayAvatarItem];
    
        if ([self shouldDisplayAvatarItemAtIndexPath:indexPath]) {
            [cell updateWithSender:[self participantForIdentity:message.sender]];
        } else {
            [cell updateWithSender:nil];
        }
        if (message.isUnread && [[UIApplication sharedApplication] applicationState] == UIApplicationStateActive && self.marksMessagesAsRead) {
            [message markAsRead:nil];
        }
    }
    
    func configureFooter(_ footer: ATLConversationCollectionViewFooter, atIndexPath indexPath: NSIndexPath)
    {
        LYRMessage *message = [self.conversationDataSource messageAtCollectionViewIndexPath:indexPath];
        footer.message = message;
        if ([self shouldDisplayReadReceiptForSection:indexPath.section]) {
            [footer updateWithAttributedStringForRecipientStatus:[self attributedStringForRecipientStatusOfMessage:message]];
        } else {
            [footer updateWithAttributedStringForRecipientStatus:nil];
        }
    }
    
    func configureHeader(_ header: ATLConversationCollectionViewHeader, atIndexPath indexPath: NSIndexPath)
    {
        LYRMessage *message = [self.conversationDataSource messageAtCollectionViewIndexPath:indexPath];
        header.message = message;
        if ([self shouldDisplayDateLabelForSection:indexPath.section]) {
            [header updateWithAttributedStringForDate:[self attributedStringForMessageDate:message]];
        }
        if ([self shouldDisplaySenderLabelForSection:indexPath.section]) {
            [header updateWithParticipantName:[self participantNameForMessage:message]];
        }
    }

    - (CGFloat)defaultCellHeightForItemAtIndexPath:(NSIndexPath *)indexPath
    {
        LYRMessage *message = [self.conversationDataSource messageAtCollectionViewIndexPath:indexPath];
        if ([message.sender.userID isEqualToString:self.layerClient.authenticatedUser.userID]) {
            return [ATLOutgoingMessageCollectionViewCell cellHeightForMessage:message inView:self.view];
        } else {
            return [ATLIncomingMessageCollectionViewCell cellHeightForMessage:message inView:self.view];
        }
    }
    
    func shouldDisplayDateLabelForSection(section: NSUInteger) -> Bool
    {
        if (section < ATLNumberOfSectionsBeforeFirstMessageSection) return NO;
        if (section == ATLNumberOfSectionsBeforeFirstMessageSection) return YES;
    
        LYRMessage *message = [self.conversationDataSource messageAtCollectionViewSection:section];
        LYRMessage *previousMessage = [self.conversationDataSource messageAtCollectionViewSection:section - 1];
        if (!previousMessage.sentAt) return NO;
    
        NSDate *date = message.sentAt ?: [NSDate date];
        NSTimeInterval interval = [date timeIntervalSinceDate:previousMessage.sentAt];
        if (fabs(interval) > self.dateDisplayTimeInterval) {
            return YES;
        }
        return NO;
    }
    
    func shouldDisplaySenderLabelForSection(_ section: NSUInteger) -> Bool
    {
        if (self.conversation.participants.count <= 2) return NO;
    
        LYRMessage *message = [self.conversationDataSource messageAtCollectionViewSection:section];
        if ([message.sender.userID isEqualToString:self.layerClient.authenticatedUser.userID]) return NO;
        if (section > ATLNumberOfSectionsBeforeFirstMessageSection) {
            LYRMessage *previousMessage = [self.conversationDataSource messageAtCollectionViewSection:section - 1];
            if ([previousMessage.sender.userID isEqualToString:message.sender.userID]) {
                return NO;
            }
        }
        return YES;
    }
    
    func shouldDisplayReadReceiptForSection(_ section: NSUInteger) -> Bool
    {
        // Only show read receipt if last message was sent by currently authenticated user
        NSInteger lastQueryControllerRow = [self.conversationDataSource.queryController numberOfObjectsInSection:0] - 1;
        NSInteger lastSection = [self.conversationDataSource collectionViewSectionForQueryControllerRow:lastQueryControllerRow];
        if (section != lastSection) return NO;
        LYRMessage *message = [self.conversationDataSource messageAtCollectionViewSection:section];
        if (![message.sender.userID isEqualToString:self.layerClient.authenticatedUser.userID]) return NO;
    
        return YES;
    }
    
    func shouldClusterMessageAtSection(_ section: NSUInteger) -> Bool
    {
        if (section == self.collectionView.numberOfSections - 1) {
            return NO;
        }
        LYRMessage *message = [self.conversationDataSource messageAtCollectionViewSection:section];
        LYRMessage *nextMessage = [self.conversationDataSource messageAtCollectionViewSection:section + 1];
        if (!nextMessage.receivedAt) {
            return NO;
        }
        NSDate *date = message.receivedAt ?: [NSDate date];
        NSTimeInterval interval = [nextMessage.receivedAt timeIntervalSinceDate:date];
        return (interval < 60);
    }
    
    func shouldDisplayAvatarItemAtIndexPath(_ indexPath: NSIndexPath) -> Bool
    {
        if (!self.shouldDisplayAvatarItem) return false
        let message = self.conversationDataSource.messageAtCollectionViewIndexPath(indexPath)
        if (message.sender.userID == nil) {
            return NO;
        }
    
        if ([message.sender.userID isEqualToString:self.layerClient.authenticatedUser.userID] && !self.shouldDisplayAvatarItemForAuthenticatedUser) {
            return NO;
        }
        if (![self shouldClusterMessageAtSection:indexPath.section] && self.avatarItemDisplayFrequency == ATLAvatarItemDisplayFrequencyCluster) {
            return YES;
        }
        NSInteger lastQueryControllerRow = [self.conversationDataSource.queryController numberOfObjectsInSection:0] - 1;
        NSInteger lastSection = [self.conversationDataSource collectionViewSectionForQueryControllerRow:lastQueryControllerRow];
        if (indexPath.section < lastSection) {
            LYRMessage *nextMessage = [self.conversationDataSource messageAtCollectionViewSection:indexPath.section + 1];
            // If the next message is sent by the same user, no
            if ([nextMessage.sender.userID isEqualToString:message.sender.userID] && self.avatarItemDisplayFrequency != ATLAvatarItemDisplayFrequencyAll) {
                return NO;
            }
        }
        return YES;
    }


    func messageInputToolbar(_ messageInputToolbar: ATLMessageInputToolbar, didTapLeftAccessoryButton leftAccessoryButton: UIButton)
    {
        if (messageInputToolbar.textInputView.isFirstResponder) {
            messageInputToolbar.textInputView.resignFirstResponder()
        }
    
        let actionSheet = UIActionSheet(title:nil, delegate:self, cancelButtonTitle:"Cancel", destructiveButtonTitle:nil,
            otherButtonTitles:["Take Photo/Video", "Last Photo/Video", "Photo/Video Library"])
        [actionSheet showInView:self.view];
        actionSheet.tag = ATLPhotoActionSheet;
    }
    
    func messageInputToolbar(_ messageInputToolbar: ATLMessageInputToolbar, didTapRightAccessoryButton rightAccessoryButton: UIButton)
    {
        guard (self.conversation == nil) else { return }
    
        // If there's no content in the input field, send the location.
        let messages = [self messagesForMediaAttachments:messageInputToolbar.mediaAttachments];
        if (messages.count == 0 && messageInputToolbar.textInputView.text.length == 0) {
            [self sendLocationMessage];
        } else {
            for (LYRMessage *message in messages) {
                [self sendMessage:message];
            }
        }
        if (self.addressBarController) [self.addressBarController disable];
    }
    
    func messageInputToolbarDidType:(ATLMessageInputToolbar *)messageInputToolbar
    {
        if (!self.conversation) return;
        [self.conversation sendTypingIndicator:LYRTypingIndicatorActionBegin];
    }
    
    func messageInputToolbarDidEndTyping:(ATLMessageInputToolbar *)messageInputToolbar
    {
        if (!self.conversation) return;
        [self.conversation sendTypingIndicator:LYRTypingIndicatorActionFinish];
    }


    - (NSOrderedSet *)defaultMessagesForMediaAttachments:(NSArray *)mediaAttachments
    {
        NSMutableOrderedSet *messages = [NSMutableOrderedSet new];
        for (ATLMediaAttachment *attachment in mediaAttachments) {
            NSArray *messageParts = ATLMessagePartsWithMediaAttachment(attachment);
            LYRMessage *message = [self messageForMessageParts:messageParts MIMEType:attachment.mediaMIMEType pushText:(([attachment.mediaMIMEType isEqualToString:ATLMIMETypeTextPlain]) ? attachment.textRepresentation : nil)];
            if (message)[messages addObject:message];
        }
        return messages;
    }
    
    - (LYRMessage *)messageForMessageParts:(NSArray *)parts MIMEType:(NSString *)MIMEType pushText:(NSString *)pushText;
    {
        NSString *senderName = [[self participantForIdentity:self.layerClient.authenticatedUser] displayName];
        NSString *completePushText;
        if (!pushText) {
            if ([MIMEType isEqualToString:ATLMIMETypeImageGIF]) {
                completePushText = [NSString stringWithFormat:"%@ %@", senderName, ATLDefaultPushAlertGIF];
            } else if ([MIMEType isEqualToString:ATLMIMETypeImagePNG] || [MIMEType isEqualToString:ATLMIMETypeImageJPEG]) {
                completePushText = [NSString stringWithFormat:"%@ %@", senderName, ATLDefaultPushAlertImage];
            } else if ([MIMEType isEqualToString:ATLMIMETypeLocation]) {
                completePushText = [NSString stringWithFormat:"%@ %@", senderName, ATLDefaultPushAlertLocation];
            } else if ([MIMEType isEqualToString:ATLMIMETypeVideoMP4]){
                completePushText = [NSString stringWithFormat:"%@ %@", senderName, ATLDefaultPushAlertVideo];
            } else {
                completePushText = [NSString stringWithFormat:"%@ %@", senderName, ATLDefaultPushAlertText];
            }
        } else {
            completePushText = [NSString stringWithFormat:"%@: %@", senderName, pushText];
        }
    
        LYRMessage *message = ATLMessageForParts(self.layerClient, parts, completePushText, ATLPushNotificationSoundName);
        return message;
    }
    
    func sendMessage(message: LYRMessage)
    {
        var error: NSError? = nil
        let success = self.conversation.sendMessage(message, error:&error)
        if (success) {
            self.notifyDelegateOfMessageSend(message)
        } else {
            self.notifyDelegateOfMessageSendFailure(message, error:error)
        }
    }


    // TODO: Use shared locaton manager
    func sendLocationMessage()
    {
        self.shouldShareLocation = true
        if (!self.locationManager) {
            self.locationManager = [[ATLLocationManager alloc] init];
            self.locationManager.delegate = self;
            if (self.locationManager.respondsToSelector(#selector(requestWhenInUseAuthorization))) {
                self.locationManager.requestWhenInUseAuthorization];
            }
        }
        if ([self.locationManager locationServicesEnabled]) {
            [self.locationManager startUpdatingLocation];
        }
    }
    
    func locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
    {
        if (!self.shouldShareLocation) return;
        if (locations.firstObject) {
            self.shouldShareLocation = NO;
            [self sendMessageWithLocation:locations.firstObject];
            [self.locationManager stopUpdatingLocation];
        }
    }
    
    func sendMessageWithLocation:(CLLocation *)location
    {
        ATLMediaAttachment *attachement = [ATLMediaAttachment mediaAttachmentWithLocation:location];
        LYRMessage *message = [self messageForMessageParts:ATLMessagePartsWithMediaAttachment(attachement) MIMEType:ATLMIMETypeLocation pushText:nil];
        [self sendMessage:message];
    }


    func actionSheet(_ actionSheet: UIActionSheet, didDismissWithButtonIndex buttonIndex: Int)
    {
        if (actionSheet.tag == ATLPhotoActionSheet) {
            switch (buttonIndex) {
            case 0:
                self.displayImagePickerWithSourceType(.camera)
                break;
            case 1:
                self.captureLastPhotoTaken()
                break;
            case 2:
                self.displayImagePickerWithSourceType(.photoLibrary)
                break;
            default:
                break;
            }
        }
    }

    func displayImagePickerWithSourceType(_ sourceType: UIImagePickerControllerSourceType)
    {
        self.messageInputToolbar.textInputView.resignFirstResponder()
        let pickerSourceTypeAvailable = UIImagePickerController.isSourceTypeAvailable(sourceType)
        if (pickerSourceTypeAvailable) {
            let picker = UIImagePickerController()
            picker.delegate = self;
            picker.mediaTypes = UIImagePickerController.availableMediaTypesForSourceType(sourceType)
            picker.sourceType = sourceType
            picker.videoQuality = .typeHigh
            self.navigationController.presentViewController(picker, animated:true, completion:nil)
        }
    }
    
    func captureLastPhotoTaken()
    {
        ATLAssetURLOfLastPhotoTaken() { (assetUrl, error) in
            if (error) {
                NSLog("Failed to capture last photo with error: %@", error.localizedDescription);
            } else {
                let mediaAttachment = ATLMediaAttachment.mediaAttachmentWithAssetURL(assetUrl, thumbnailSize: ATLDefaultThumbnailSize)
                self.messageInputToolbar.insertMediaAttachment(mediaAttachment, withEndLineBreak: true)
            }
        }
    }


    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: NSDictionary)
    {
        var mediaAttachment: ATLMediaAttachment? = nil
        if (info[UIImagePickerControllerMediaURL]) {
            // Video recorded within the app or was picked and edited in
            // the image picker.
            NSURL *moviePath = [NSURL fileURLWithPath:(NSString *)[[info objectForKey:UIImagePickerControllerMediaURL] path]];
            mediaAttachment = [ATLMediaAttachment mediaAttachmentWithFileURL:moviePath thumbnailSize:ATLDefaultThumbnailSize];
        } else if (info[UIImagePickerControllerReferenceURL]) {
            // Photo taken or video recorded within the app.
            mediaAttachment = [ATLMediaAttachment mediaAttachmentWithAssetURL:info[UIImagePickerControllerReferenceURL] thumbnailSize:ATLDefaultThumbnailSize];
        } else if (info[UIImagePickerControllerOriginalImage]) {
            // Image picked from the image picker.
            mediaAttachment = [ATLMediaAttachment mediaAttachmentWithImage:info[UIImagePickerControllerOriginalImage] metadata:info[UIImagePickerControllerMediaMetadata] thumbnailSize:ATLDefaultThumbnailSize];
        } else {
            return;
        }
    
        if (mediaAttachment) {
            [self.messageInputToolbar insertMediaAttachment:mediaAttachment withEndLineBreak:YES];
        }
        [self.navigationController dismissViewControllerAnimated:YES completion:nil];
        [self.view becomeFirstResponder];
    
        // Workaround for collection view not displayed on iOS 7.1.
        [self.collectionView setNeedsLayout];
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController)
    {
        self.navigationController.dismissViewControllerAnimated(true, completion:nil)
        self.view.becomeFirstResponder()
    
        // Workaround for collection view not displayed on iOS 7.1.
        self.collectionView.setNeedsLayout()
    }


    func didReceiveTypingIndicator(_ notification: NSNotification)
    {
        if (!self.conversation) return;
        if (!notification.object) return;
        if (![notification.object isEqual:self.conversation]) return;
    
        LYRTypingIndicator *typingIndicator = notification.userInfo[LYRTypingIndicatorObjectUserInfoKey];
        if (typingIndicator.action == LYRTypingIndicatorActionBegin) {
            [self.typingParticipantIDs addObject:typingIndicator.sender.userID];
        } else {
            [self.typingParticipantIDs removeObject:typingIndicator.sender.userID];
        }
        [self updateTypingIndicatorOverlay:YES];
    }
    
    func layerClientObjectsDidChange(_ notification: NSNotification)
    {
        if (!self.conversation) return;
        if (!self.layerClient) return;
        if (!notification.object) return;
        if (![notification.object isEqual:self.layerClient]) return;
    
        NSArray *changes = notification.userInfo[LYRClientObjectChangesUserInfoKey];
        for (LYRObjectChange *change in changes) {
            if (![change.object isEqual:self.conversation]) {
                continue;
            }
            if (change.type == LYRObjectChangeTypeUpdate && [change.property isEqualToString:@"participants"]) {
                [self configureControllerForChangedParticipants];
                break;
            }
        }
    }
    
    func handleApplicationDidBecomeActive(_ notification: NSNotification)
    {
        if (self.conversation != nil && self.marksMessagesAsRead) {
            NSError *error;
            BOOL success = [self.conversation markAllMessagesAsRead:&error];
            if (!success) {
                NSLog(@"Failed to mark all messages as read with error: %@", error);
            }
        }
    }

    func updateTypingIndicatorOverlay(_ animated: Bool)
    {
        NSMutableOrderedSet *knownParticipantsTyping = [NSMutableOrderedSet new];
        [self.typingParticipantIDs enumerateObjectsUsingBlock:^(NSString *participantID, NSUInteger idx, BOOL *stop) {
            LYRIdentity *identity = ATLIdentityFromSet(participantID, self.conversation.participants);
            id<ATLParticipant> participant = [self participantForIdentity:identity];
            if (participant) [knownParticipantsTyping addObject:participant];
        }];
        [self.typingIndicatorController updateWithParticipants:knownParticipantsTyping animated:animated];
    
        if (knownParticipantsTyping.count) {
            self.typingIndicatorInset = self.typingIndicatorController.view.frame.size.height;
        } else {
            self.typingIndicatorInset = 0.0f;
        }
    }

    func configureControllerForChangedParticipants
    {
        if (self.addressBarController && !self.addressBarController.isDisabled) {
            self.configureConversationForAddressBar()
            return;
        }
        var removedParticipantIdentifiers = self.typingParticipantIDs.array
        if (removedParticipantIdentifiers.count) {
            removedParticipantIdentifiers.minusSet(self.conversation.participants)
            self.typingParticipantIDs.removeObjectsInArray(removedParticipantIdentifiers.allObjects)
            self.updateTypingIndicatorOverlay(false)
        }
        self.configureAddressBarForChangedParticipants()
        self.configureControllerForConversation()
        self.collectionView.reloadData()
    }


    func willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
    {
        [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
        [self.collectionView.collectionViewLayout invalidateLayout];
    }


    func addressBarViewControllerDidBeginSearching:(ATLAddressBarViewController *)addressBarViewController
    {
        self.messageInputToolbar.hidden = YES;
    }
    
    func addressBarViewControllerDidEndSearching:(ATLAddressBarViewController *)addressBarViewController
    {
        self.messageInputToolbar.hidden = NO;
    }
    
    func addressBarViewController:(ATLAddressBarViewController *)addressBarViewController didSelectParticipant:(id<ATLParticipant>)participant
    {
        self.canDisableAddressBar = NO;
        [self configureConversationForAddressBar];
    }
    
    func addressBarViewController:(ATLAddressBarViewController *)addressBarViewController didRemoveParticipant:(id<ATLParticipant>)participant
    {
        [self configureConversationForAddressBar];
    }


    func configurePaginationWindow()
    {
        if (CGRectEqualToRect(self.collectionView.frame, CGRectZero)) return;
        if (self.collectionView.isDragging) return;
        if (self.collectionView.isDecelerating) return;
    
        CGFloat topOffset = -self.collectionView.contentInset.top;
        CGFloat distanceFromTop = self.collectionView.contentOffset.y - topOffset;
        CGFloat minimumDistanceFromTopToTriggerLoadingMore = 200;
        BOOL nearTop = distanceFromTop <= minimumDistanceFromTopToTriggerLoadingMore;
        if (!nearTop) return;
    
        self.expandingPaginationWindow = YES;
        [self.conversationDataSource expandPaginationWindow];
    }
    
    func configureMoreMessagesIndicatorVisibility()
    {
        if (self.collectionView.isDragging) return;
        if (self.collectionView.isDecelerating) return;
        BOOL moreMessagesAvailable = [self.conversationDataSource moreMessagesAvailable];
        if (moreMessagesAvailable == self.showingMoreMessagesIndicator) return;
        self.showingMoreMessagesIndicator = moreMessagesAvailable;
        [self reloadCollectionViewAdjustingForContentHeightChange];
    }
        
    func reloadCollectionViewAdjustingForContentHeightChange()
    {
        CGFloat priorContentHeight = self.collectionView.contentSize.height;
        [self.collectionView reloadData];
        CGFloat contentHeightDifference = self.collectionView.collectionViewLayout.collectionViewContentSize.height - priorContentHeight;
        CGFloat adjustment = contentHeightDifference;
        self.collectionView.contentOffset = CGPointMake(0, self.collectionView.contentOffset.y + adjustment);
        [self.collectionView flashScrollIndicators];
    }


    func configureConversationForAddressBar()
    {
        let participants = self.addressBarController.selectedParticipants.set;
        let participantIdentifiers = participants.valueForKey("userID")
    
        if (!participantIdentifiers && !self.conversation.participants) return;
    
        NSString *authenticatedUserID = self.layerClient.authenticatedUser.userID;
        NSMutableSet *conversationParticipantsCopy = [[self.conversation.participants valueForKey:@"userID"] mutableCopy];
        if ([conversationParticipantsCopy containsObject:authenticatedUserID]) {
            conversationParticipantsCopy.removeObject(authenticatedUserID)
        }
        if ([participantIdentifiers isEqual:conversationParticipantsCopy]) return;
    
        let conversation = self.conversationWithParticipants(participants)
        self.conversation = conversation;
    }


    func configureAddressBarForChangedParticipants()
    {
        if (!self.addressBarController) return;
    
        NSOrderedSet *existingParticipants = self.addressBarController.selectedParticipants;
        NSOrderedSet *existingParticipantIdentifiers = [existingParticipants valueForKey:@"userID"];
    
        if (!existingParticipantIdentifiers && !self.conversation.participants) return;
        if ([existingParticipantIdentifiers.set isEqual:[self.conversation.participants valueForKey:@"userID"]]) return;
    
        NSMutableOrderedSet *removedIdentifiers = [NSMutableOrderedSet orderedSetWithOrderedSet:existingParticipantIdentifiers];
        [removedIdentifiers minusSet:[self.conversation.participants valueForKey:@"userID"]];
    
        NSMutableOrderedSet *addedIdentifiers = [NSMutableOrderedSet orderedSetWithSet:[self.conversation.participants valueForKey:@"userID"]];
        [addedIdentifiers minusOrderedSet:existingParticipantIdentifiers];
    
        NSString *authenticatedUserID = self.layerClient.authenticatedUser.userID;
        if (authenticatedUserID) [addedIdentifiers removeObject:authenticatedUserID];
    
        NSMutableOrderedSet *participantIdentifiers = [NSMutableOrderedSet orderedSetWithOrderedSet:existingParticipantIdentifiers];
        [participantIdentifiers minusOrderedSet:removedIdentifiers];
        [participantIdentifiers unionOrderedSet:addedIdentifiers];
    
        NSOrderedSet *participants = [self participantsForIdentifiers:participantIdentifiers];
        self.addressBarController.selectedParticipants = participants;
    }

    func registerClass(_ cellClass: AnyClass, forMessageCellWithReuseIdentifier reuseIdentifier: String)
    {
        self.collectionView.register(cellClass, forCellWithReuseIdentifier: reuseIdentifier)
    }

    
    func reloadCellsForMessagesSentByParticipantWithIdentifier:(NSString *)participantIdentifier
    {
        if (self.conversationDataSource.queryController.query == nil) {
            return;
        }
    
        dispatch_async(self.animationQueue, ^{
            // Query for all of the message identifiers in the conversation
            LYRQuery *messageIdentifiersQuery = [self.conversationDataSource.queryController.query copy];
            if (messageIdentifiersQuery == nil) {
                return;
            }
            messageIdentifiersQuery.resultType = LYRQueryResultTypeIdentifiers;
            NSError *error = nil;
            NSOrderedSet *messageIdentifiers = [self.layerClient executeQuery:messageIdentifiersQuery error:&error];
            if (!messageIdentifiers) {
                NSLog(@"LayerKit failed to execute query with error: %@", error);
                return;
            }
            
            // Query for the all of the message identifiers in the above set where user == participantIdentifier
            LYRQuery *query = [LYRQuery queryWithQueryableClass:[LYRMessage class]];
            LYRPredicate *senderPredicate = [LYRPredicate predicateWithProperty:@"sender.userID" predicateOperator:LYRPredicateOperatorIsEqualTo value:participantIdentifier];
            LYRPredicate *objectIdentifiersPredicate = [LYRPredicate predicateWithProperty:@"identifier" predicateOperator:LYRPredicateOperatorIsIn value:messageIdentifiers];
            query.predicate = [LYRCompoundPredicate compoundPredicateWithType:LYRCompoundPredicateTypeAnd subpredicates:@[ senderPredicate, objectIdentifiersPredicate ]];
            query.resultType = LYRQueryResultTypeIdentifiers;
            NSOrderedSet *messageIdentifiersToReload = [self.layerClient executeQuery:query error:&error];
            if (!messageIdentifiers) {
                NSLog(@"LayerKit failed to execute query with error: %@", error);
                return;
            }
            
            // Convert query controller index paths to collection view index paths
            NSDictionary *objectIdentifiersToIndexPaths = [self.conversationDataSource.queryController indexPathsForObjectsWithIdentifiers:messageIdentifiersToReload.set];
            NSArray *queryControllerIndexPaths = [objectIdentifiersToIndexPaths allValues];
            for (NSIndexPath *indexPath in queryControllerIndexPaths) {
                NSIndexPath *collectionViewIndexPath = [self.conversationDataSource collectionViewIndexPathForQueryControllerIndexPath:indexPath];
                // Configure the cell, the header, and the footer
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self configureCollectionViewElementsAtCollectionViewIndexPath:collectionViewIndexPath];
                    });
            }
        });
    }

    func notifyDelegateOfMessageSend:(LYRMessage *)message
    {
        if ([self.delegate respondsToSelector:@selector(conversationViewController:didSendMessage:)]) {
            [self.delegate conversationViewController:self didSendMessage:message];
        }
    }
    
    func notifyDelegateOfMessageSendFailure:(LYRMessage *)message error:(NSError *)error
    {
        if ([self.delegate respondsToSelector:@selector(conversationViewController:didFailSendingMessage:error:)]) {
            [self.delegate conversationViewController:self didFailSendingMessage:message error:error];
        }
    }
    
    func notifyDelegateOfMessageSelection:(LYRMessage *)message
    {
        if ([self.delegate respondsToSelector:@selector(conversationViewController:didSelectMessage:)]) {
            [self.delegate conversationViewController:self didSelectMessage:message];
        }
    }
    
    - (CGSize)heightForMessageAtIndexPath:(NSIndexPath *)indexPath
    {
        CGFloat width = self.collectionView.bounds.size.width;
        CGFloat height = 0;
        if ([self.delegate respondsToSelector:@selector(conversationViewController:heightForMessage:withCellWidth:)]) {
            LYRMessage *message = [self.conversationDataSource messageAtCollectionViewIndexPath:indexPath];
            height = [self.delegate conversationViewController:self heightForMessage:message withCellWidth:width];
        }
        if (!height) {
            height = [self defaultCellHeightForItemAtIndexPath:indexPath];
        }
        return CGSizeMake(width, height);
    }
    
    - (NSOrderedSet *)messagesForMediaAttachments:(NSArray *)mediaAttachments
    {
        NSOrderedSet *messages;
        if ([self.delegate respondsToSelector:@selector(conversationViewController:messagesForMediaAttachments:)]) {
            messages = [self.delegate conversationViewController:self messagesForMediaAttachments:mediaAttachments];
            // If delegate returns an empty set, don't send any messages.
            if (messages && !messages.count) return nil;
        }
        // If delegate returns nil, we fall back to default behavior.
        if (!messages) messages = [self defaultMessagesForMediaAttachments:mediaAttachments];
        return messages;
    }


    - (id<ATLParticipant>)participantForIdentity:(LYRIdentity *)identity;
    {
        if ([self.dataSource respondsToSelector:@selector(conversationViewController:participantForIdentity:)]) {
            return [self.dataSource conversationViewController:self participantForIdentity:identity];
        } else {
            return identity;
        }
    }
    
    - (NSAttributedString *)attributedStringForMessageDate:(LYRMessage *)message
    {
        NSAttributedString *dateString;
        if ([self.dataSource respondsToSelector:@selector(conversationViewController:attributedStringForDisplayOfDate:)]) {
            NSDate *date = message.sentAt ?: [NSDate date];
            dateString = [self.dataSource conversationViewController:self attributedStringForDisplayOfDate:date];
            NSAssert([dateString isKindOfClass:[NSAttributedString class]], @"Date string must be an attributed string");
        } else {
            @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"ATLConversationViewControllerDataSource must return an attributed string for Date" userInfo:nil];
        }
        return dateString;
    }
    
    - (NSAttributedString *)attributedStringForRecipientStatusOfMessage:(LYRMessage *)message
    {
        NSAttributedString *recipientStatusString;
        if ([self.dataSource respondsToSelector:@selector(conversationViewController:attributedStringForDisplayOfRecipientStatus:)]) {
            recipientStatusString = [self.dataSource conversationViewController:self attributedStringForDisplayOfRecipientStatus:message.recipientStatusByUserID];
            NSAssert([recipientStatusString isKindOfClass:[NSAttributedString class]], @"Recipient String must be an attributed string");
        } else {
            @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"ATLConversationViewControllerDataSource must return an attributed string for recipient status" userInfo:nil];
        }
        return recipientStatusString;
    }
    
    - (NSString *)reuseIdentifierForMessage:(LYRMessage *)message atIndexPath:(NSIndexPath *)indexPath
    {
        NSString *reuseIdentifier;
        if ([self.dataSource respondsToSelector:@selector(conversationViewController:reuseIdentifierForMessage:)]) {
            reuseIdentifier = [self.dataSource conversationViewController:self reuseIdentifierForMessage:message];
        }
        if (!reuseIdentifier) {
            if ([self.layerClient.authenticatedUser.userID isEqualToString:message.sender.userID]) {
                reuseIdentifier = ATLOutgoingMessageCellIdentifier;
            } else {
                reuseIdentifier = ATLIncomingMessageCellIdentifier;
            }
        }
        return reuseIdentifier;
    }
    
    - (LYRConversation *)conversationWithParticipants:(NSSet *)participants
    {
        if (participants.count == 0) return nil;
        
        LYRConversation *conversation;
        if ([self.dataSource respondsToSelector:@selector(conversationViewController:conversationWithParticipants:)]) {
            conversation = [self.dataSource conversationViewController:self conversationWithParticipants:participants];
            if (conversation) return conversation;
        }
        NSSet *participantIdentifiers = [participants valueForKey:@"userID"];
        conversation = [self existingConversationWithParticipantIdentifiers:participantIdentifiers];
        if (conversation) return conversation;
        
        LYRConversationOptions *conversationOptions = [LYRConversationOptions new];
        conversationOptions.deliveryReceiptsEnabled = participants.count <= 5;
        conversation = [self.layerClient newConversationWithParticipants:participantIdentifiers options:conversationOptions error:nil];
        return conversation;
    }

    func queryController(_controller: LYRQueryController,
didChangeObject object: Any,
atIndexPath:(NSIndexPath *)indexPath,
forChangeType:(LYRQueryControllerChangeType)type,
newIndexPath:(NSIndexPath *)newIndexPath)
{
    NSInteger currentIndex = indexPath ? [self.conversationDataSource collectionViewSectionForQueryControllerRow:indexPath.row] : NSNotFound;
    NSInteger newIndex = newIndexPath ? [self.conversationDataSource collectionViewSectionForQueryControllerRow:newIndexPath.row] : NSNotFound;
    [self.objectChanges addObject:[ATLDataSourceChange changeObjectWithType:type newIndex:newIndex currentIndex:currentIndex]];
    }
    
    func queryControllerWillChangeContent:(LYRQueryController *)queryController
    {
        // Implemented by subclass
    }
    
    func queryControllerDidChangeContent(queryController: LYRQueryController)
    {
        NSArray *objectChanges = [self.objectChanges copy];
        [self.objectChanges removeAllObjects];
    
        if (self.expandingPaginationWindow) {
            self.expandingPaginationWindow = NO;
            self.showingMoreMessagesIndicator = [self.conversationDataSource moreMessagesAvailable];
            [self reloadCollectionViewAdjustingForContentHeightChange];
            return;
        }
        
        if (objectChanges.count == 0) {
            [self configurePaginationWindow];
            [self configureMoreMessagesIndicatorVisibility];
            return;
        }
        
        // Prevent scrolling if user has scrolled up into the conversation history.
        BOOL shouldScrollToBottom = [self shouldScrollToBottom];
        
        // ensure the animation's queue will resume
        if (self.collectionView) {
            dispatch_suspend(self.animationQueue);
            [self.collectionView performBatchUpdates:^{
                for (ATLDataSourceChange *change in objectChanges) {
                switch (change.type) {
                case LYRQueryControllerChangeTypeInsert:
                [self.collectionView insertSections:[NSIndexSet indexSetWithIndex:change.newIndex]];
                break;
                
                case LYRQueryControllerChangeTypeMove:
                [self.collectionView moveSection:change.currentIndex toSection:change.newIndex];
                break;
                
                case LYRQueryControllerChangeTypeDelete:
                [self.collectionView deleteSections:[NSIndexSet indexSetWithIndex:change.currentIndex]];
                break;
                
                case LYRQueryControllerChangeTypeUpdate:
                // If we call reloadSections: for a section that is already being animated due to another move (e.g. moving section 17 to 16 causes section 16 to be moved/animated to 17 and then we also reload section 16), UICollectionView will throw an exception. But since all onscreen sections will be reconfigured (see below) we don't need to reload the sections here anyway.
                break;
                
                default:
                break;
                }
                }
                } completion:^(BOOL finished) {
                dispatch_resume(self.animationQueue);
                }];
        }
        self.configureCollectionViewElements()
        
        if (shouldScrollToBottom)  {
            // We can't get the content size from the collection view because it will be out-of-date due to the above updates, but we can get the update-to-date size from the layout.
            let contentSize = self.collectionView.collectionViewLayout.collectionViewContentSize;
            self.collectionView.setContentOffset(self.bottomOffsetForContentSize(contentSize) animated:true)
        } else {
            self.configurePaginationWindow()
            self.configureMoreMessagesIndicatorVisibility()
        }
    }
    
    func configureCollectionViewElements()
    {
        // Since each section's content depends on other messages, we need to update each visible section even when a section's corresponding message has not changed. This also solves the issue with LYRQueryControllerChangeTypeUpdate (see above).
        for cell in self.collectionView.visibleCells {
            let indexPath = self.collectionView.indexPath(for: cell)
            let message = self.conversationDataSource.messageAtCollectionViewIndexPath(indexPath)
            self.configureCell(cell, forMessage:message, indexPath:indexPath)
        }
        
        for header in self.sectionHeaders {
            let queryControllerIndexPath = self.conversationDataSource.queryController.indexPathForObject(header.message)
            if (!queryControllerIndexPath) { continue }
            let collectionViewIndexPath = self.conversationDataSource.collectionViewIndexPathForQueryControllerIndexPath(queryControllerIndexPath)
            self.configureHeader(header, atIndexPath:collectionViewIndexPath)
        }
        
        for footer in self.sectionFooters {
            let queryControllerIndexPath = self.conversationDataSource.queryController.indexPathForObject(footer.message)
            if (!queryControllerIndexPath) { continue }
            let collectionViewIndexPath = self.conversationDataSource.collectionViewIndexPathForQueryControllerIndexPath(queryControllerIndexPath)
            self.configureFooter(footer, atIndexPath:collectionViewIndexPath)
        }
    }
    
    func configureCollectionViewElementsAtCollectionViewIndexPath(_ collectionViewIndexPath: NSIndexPath) {
        // Direct access to the message
        let message = self.conversationDataSource.messageAtCollectionViewIndexPath(collectionViewIndexPath)
        let cell = self.collectionView.cellForItemAtIndexPath(collectionViewIndexPath)
        if (cell.conformsToProtocol(#protocol(ATLMessagePresenting))) {
            self.configureCell((UICollectionViewCell<ATLMessagePresenting>)cell, forMessage:message, indexPath:collectionViewIndexPath)
        }
        
        // Find the header...
        for header in self.sectionHeaders {
            let queryControllerIndexPath = self.conversationDataSource.queryController.indexPathForObject(header.message)
            if (queryControllerIndexPath && header.message.identifier.isEqual(message.identifier)) {
                let collectionViewIndexPath = self.conversationDataSource.collectionViewIndexPathForQueryControllerIndexPath(queryControllerIndexPath)
                self.configureHeader(header, atIndexPath:collectionViewIndexPath)
                break
            }
        }
        
        // ...and the footer
        for footer in self.sectionFooters {
            let queryControllerIndexPath = self.conversationDataSource.queryController.indexPathForObject(footer.message)
            if (queryControllerIndexPath && footer.message.identifier.isEqual(message.identifier)) {
                let collectionViewIndexPath = self.conversationDataSource.collectionViewIndexPathForQueryControllerIndexPath(queryControllerIndexPath)
                self.configureFooter(footer, atIndexPath:collectionViewIndexPath)
                break;
            }
        }
    }


    func existingConversationWithParticipantIdentifiers(_ participantIdentifiers: NSSet) -> LYRConversation
    {
        let set = participantIdentifiers.mutableCopy()
        set.addObject(self.layerClient.authenticatedUser.userID)
        let query = LYRQuery.queryWithQueryableClass(LYRConversation.class)
        query.predicate = LYRPredicate.predicateWithProperty("participants", predicateOperator: LYRPredicateOperatorIsEqualTo, value:set)
        query.limit = 1;
        return self.layerClient.executeQuery(query, error:nil).lastObject;
    }
    
    func participantsForIdentifiers(_ identifiers: NSOrderedSet) -> NSOrderedSet
    {
        let participants = NSMutableOrderedSet()
        for (NSString *participantIdentifier in identifiers) {
            LYRIdentity *identity = ATLIdentityFromSet(participantIdentifier, self.conversation.participants);
            id<ATLParticipant> participant = [self participantForIdentity:identity];
            if (!participant) continue;
            [participants addObject:participant];
        }
        return participants;
    }
    
    func participantNameForMessage(message: LYRMessage) -> String
    {
        var participantName: String? = nil
        if (message.sender.userID != nil) {
            let participant = self.participantForIdentity(message.sender) as ATLParticipant
            participantName = participant.displayName ?: ATLLocalizedString(@"atl.conversation.participant.unknown.key", @"Unknown User", nil);
        } else {
            participantName = message.sender.displayName;
        }
        return participantName;
    }


    func _registerForNotifications()
    {
        // Layer Notifications
        NotificationCenter.defaultCenter.addObserver(self, selector: #selector(didReceiveTypingIndicator:), name: LYRConversationDidReceiveTypingIndicatorNotification, object:nil)
        NotificationCenter.defaultCenter.addObserver(self, selector: #selector(layerClientObjectsDidChange:), name: LYRClientObjectsDidChangeNotification, object: nil)
        
        // Application State Notifications
        NSNotificationCenter.defaultCenter.addObserver(self, selector: #selector(handleApplicationDidBecomeActive:), name:UIApplicationDidBecomeActiveNotification, object:nil)
    }

}
*/
