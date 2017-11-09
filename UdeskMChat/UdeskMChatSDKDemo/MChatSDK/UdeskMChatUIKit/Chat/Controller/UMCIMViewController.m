//
//  UMCIMViewController.m
//  UdeskMChatExample
//
//  Created by xuchen on 2017/10/18.
//  Copyright © 2017年 Udesk. All rights reserved.
//

#import "UMCIMViewController.h"
#import "UMCIMManager.h"
#import "UMCVoiceRecordHUD.h"
#import "UMCIMDataSource.h"
#import "UMCBaseMessage.h"
#import "UMCImagePicker.h"
#import "UMCAudioPlayerHelper.h"
#import "UMCInputBarHelper.h"
#import "UMCHelper.h"
#import "UMCBundleHelper.h"

#import "YYKeyboardManager.h"

static CGFloat const InputBarHeight = 80.0f;

@interface UMCIMViewController ()<UITableViewDelegate,UMCInputBarDelegate,YYKeyboardObserver,UdeskVoiceRecordViewDelegate,UDEmotionManagerViewDelegate,UMCBaseCellDelegate>

/** sdk配置 */
@property (nonatomic, strong) UMCSDKConfig         *sdkConfig;
/** im逻辑处理 */
@property (nonatomic, strong) UMCIMManager         *UIManager;
/** 输入框 */
@property (nonatomic, strong) UMCInputBar          *inputBar;
/** 表情 */
@property (nonatomic, strong) UMCEmojiView         *emojiView;
/** 录音 */
@property (nonatomic, strong) UMCVoiceRecordView   *recordView;
/** im TableView */
@property (nonatomic, strong) UMCIMTableView       *imTableView;
/** TableView DataSource */
@property (nonatomic, strong) UMCIMDataSource      *dataSource;
/** 录音提示HUD */
@property (nonatomic, strong) UMCVoiceRecordHUD    *voiceRecordHUD;
/** 输入框工具类 */
@property (nonatomic, strong) UMCInputBarHelper    *inputBarHelper;
/** 图片选择类 */
@property (nonatomic, strong) UMCImagePicker       *imagePicker;
/** 商户ID */
@property (nonatomic, copy  ) NSString             *merchantId;

@end

@implementation UMCIMViewController

- (instancetype)initWithSDKConfig:(UMCSDKConfig *)config merchantId:(NSString *)merchantId
{
    self = [super init];
    if (self) {
        
        _sdkConfig = config;
        _merchantId = merchantId;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [self setup];
    [self fetchMessages];
}

#pragma mark - UI布局
- (void)setup {
    
    _imTableView = [[UMCIMTableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    _imTableView.delegate = self;
    _imTableView.dataSource = self.dataSource;
    [self.view addSubview:_imTableView];
    //EdgeInsets
    [_imTableView setTableViewInsetsWithBottomValue:InputBarHeight];
    [_imTableView finishLoadingMoreMessages:self.UIManager.hasMore];
    
    //添加单击手势
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTapChatTableView:)];
    tap.cancelsTouchesInView = false;
    [_imTableView addGestureRecognizer:tap];
    
    _inputBar = [[UMCInputBar alloc] initWithFrame:CGRectMake(0, self.view.umcHeight - InputBarHeight, self.view.umcWidth,InputBarHeight) tableView:_imTableView];
    _inputBar.delegate = self;
    [self.view addSubview:_inputBar];
    //更新功能按钮隐藏属性
    [self updateInputFunctionButtonHidden];
    
    //根据系统版本去掉自动调整
    if ([self respondsToSelector:@selector(automaticallyAdjustsScrollViewInsets)]) {
        self.automaticallyAdjustsScrollViewInsets = NO;
    }
    self.navigationController.navigationBar.translucent = NO;
    self.edgesForExtendedLayout = UIRectEdgeNone;
    //获取键盘管理器
    [[YYKeyboardManager defaultManager] addObserver:self];
    
    //监听app是否从后台进入前台
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(umcIMApplicationBecomeActive) name:UIApplicationWillEnterForegroundNotification object:nil];
}

//监听app是否从后台进入前台
- (void)umcIMApplicationBecomeActive {
    
    @udWeakify(self);
    [self.UIManager fetchNewMessages:^{
        @udStrongify(self);
        [self reloadIMTableView];
    }];
}

#pragma mark - @protocol UMCInputBarDelegate
//选择图片
- (void)inputBar:(UMCInputBar *)inputBar didSelectImageWithSourceType:(UIImagePickerControllerSourceType)sourceType {
    
    [self inputBarHide:NO];
    [self.imagePicker showWithSourceType:sourceType viewController:self];
    
    //选择了GIF图片
    @udWeakify(self);
    self.imagePicker.FinishGIFImageBlock = ^(NSData *GIFData) {
        @udStrongify(self);
        [self.UIManager sendGIFImageMessage:GIFData completion:^(UMCMessage *message) {
            [self updateSendCompletedMessage:message];
        }];
    };
    //选择了普通图片
    self.imagePicker.FinishNormalImageBlock = ^(UIImage *image) {
        @udStrongify(self);
        [self.UIManager sendImageMessage:image completion:^(UMCMessage *message) {
            [self updateSendCompletedMessage:message];
        }];
    };
}

//发送文本消息，包括系统的表情
- (void)inputBar:(UMCInputBar *)inputBar didSendText:(NSString *)text {
    
    if ([UMCHelper isBlankString:text]) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:UMCLocalizedString(@"udesk_no_send_empty") preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:UMCLocalizedString(@"udesk_cancel") style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    [self.UIManager sendTextMessage:text completion:^(UMCMessage *message) {
        [self updateSendCompletedMessage:message];
    }];
}

//显示表情
- (void)inputBar:(UMCInputBar *)inputBar didSelectEmotion:(UIButton *)emotionButton {
    
    if (emotionButton.selected) {
        [self emojiView];
        [self inputBarHide:NO];
    }
}

//点击语音
- (void)inputBar:(UMCInputBar *)inputBar didSelectVoice:(UIButton *)voiceButton {
    
    if (voiceButton.selected) {
        [self recordView];
        [self inputBarHide:NO];
    }
}

//显示／隐藏
- (void)inputBarHide:(BOOL)hide {
    
    [self.inputBarHelper inputBarHide:hide superView:self.view tableView:self.imTableView inputBar:self.inputBar emojiView:self.emojiView recordView:self.recordView completion:^{
        if (hide) {
            self.inputBar.selectInputBarType = UMCInputBarTypeNormal;
        }
    }];
}

//是否隐藏部分功能
- (void)updateInputFunctionButtonHidden {
    
    _inputBar.hiddenCameraButton = self.sdkConfig.hiddenCameraButton;
    _inputBar.hiddenAlbumButton = self.sdkConfig.hiddenAlbumButton;
    _inputBar.hiddenVoiceButton = self.sdkConfig.hiddenVoiceButton;
    _inputBar.hiddenEmotionButton = self.sdkConfig.hiddenEmotionButton;
}

//点击空白处隐藏键盘
- (void)didTapChatTableView:(UITableView *)tableView {
    
    if ([self.inputBar.inputTextView resignFirstResponder]) {
        [self inputBarHide:YES];
    }
}

#pragma mark - @protocol TableViewDelegate
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UMCBaseMessage *message = self.UIManager.messagesArray[indexPath.row];
    return message ? message.cellHeight : 0;
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    
    //滑动表隐藏Menu
    UIMenuController *menu = [UIMenuController sharedMenuController];
    if (menu.isMenuVisible) {
        [menu setMenuVisible:NO animated:YES];
    }
    
    if (self.inputBar.selectInputBarType != UMCInputBarTypeNormal) {
        [self inputBarHide:YES];
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    
    @try {
        
        if (scrollView.contentOffset.y<0 && self.imTableView.isRefresh) {
            //开始刷新
            [self.imTableView startLoadingMoreMessages];
            //获取更多数据
            [self.UIManager nextMessages:^{
                //延迟0.8，提高用户体验
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    //关闭刷新、刷新数据
                    [self.imTableView finishLoadingMoreMessages:self.UIManager.hasMore];
                });
            }];
        }
    } @catch (NSException *exception) {
        NSLog(@"%@",exception);
    } @finally {
    }
}

#pragma mark - 获取消息数据
- (void)fetchMessages {
    
    @udWeakify(self);
    [self.UIManager fetchMessages:^{
        @udStrongify(self);
        [self reloadIMTableView];
    }];
    
    //刷新消息
    self.UIManager.ReloadMessagesBlock = ^{
        @udStrongify(self);
        [self reloadIMTableView];
    };
    
    //获取商户信息
    [self.UIManager fetchMerchantWithMerchantId:self.merchantId completion:nil];
}

//刷新UI
- (void)reloadIMTableView {
    
    //更新消息内容
    dispatch_async(dispatch_get_main_queue(), ^{
        //是否需要下拉刷新
        self.dataSource.messagesArray = self.UIManager.messagesArray;
        [self.imTableView finishLoadingMoreMessages:self.UIManager.hasMore];
        [self.imTableView reloadData];
    });
}

//TableView DataSource
- (UMCIMDataSource *)dataSource {
    if (!_dataSource) {
        _dataSource = [[UMCIMDataSource alloc] init];
        _dataSource.delegate = self;
    }
    return _dataSource;
}

#pragma mark - UMCBaseCellDelegate
//发送咨询对象URL
- (void)sendProductURL:(NSString *)url {
    [self inputBar:self.inputBar didSendText:url];
}

//重发消息
- (void)resendMessageInCell:(UITableViewCell *)cell resendMessage:(UMCMessage *)resendMessage {
    
    @udWeakify(self);
    [UMCManager createMessageWithMerchantsEuid:self.merchantId message:resendMessage completion:^(UMCMessage *message) {
        @udStrongify(self);
        [self updateSendCompletedMessage:message];
    }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

//vc逻辑处理
- (UMCIMManager *)UIManager {
    if (!_UIManager) {
        _UIManager = [[UMCIMManager alloc] initWithSDKConfig:_sdkConfig merchantId:_merchantId];
    }
    return _UIManager;
}

//吐司提示view
- (UMCVoiceRecordHUD *)voiceRecordHUD {
    
    if (!_voiceRecordHUD) {
        _voiceRecordHUD = [[UMCVoiceRecordHUD alloc] init];
    }
    return _voiceRecordHUD;
}

//录音动画view
- (UMCVoiceRecordView *)recordView {
    
    if (!_recordView) {
        _recordView = [[UMCVoiceRecordView alloc] initWithFrame:CGRectMake(0, CGRectGetHeight(self.view.bounds), CGRectGetWidth(self.view.bounds), 200)];
        _recordView.alpha = 0.0;
        _recordView.delegate = self;
        [self.view addSubview:_recordView];
    }
    return _recordView;
}

#pragma mark - @protocol UdeskVoiceRecordViewDelegate
//完成录音
#warning 要删除原来存储的
- (void)finishRecordedWithVoicePath:(NSString *)voicePath withAudioDuration:(NSString *)duration {
    
    @udWeakify(self);
    [self.UIManager sendVoiceMessage:voicePath voiceDuration:duration completion:^(UMCMessage *message) {
        @udStrongify(self);
        [self updateSendCompletedMessage:message];
    }];
}

//录音时间太短
- (void)speakDurationTooShort {
    [self.voiceRecordHUD showTooShortRecord:self.view];
}

#pragma mark - 表情view
- (UMCEmojiView *)emojiView {
    
    if (!_emojiView) {
        CGFloat emotionHeight = kUMCScreenWidth<375?200:216;
        _emojiView = [[UMCEmojiView alloc] initWithFrame:CGRectMake(0, CGRectGetHeight(self.view.bounds), CGRectGetWidth(self.view.bounds), emotionHeight)];
        _emojiView.delegate = self;
        _emojiView.backgroundColor = [UIColor colorWithWhite:0.961 alpha:1.000];
        _emojiView.alpha = 0.0;
        [self.view addSubview:_emojiView];
    }
    return _emojiView;
}

#pragma mark - @protocol UDEmotionManagerViewDelegate
- (void)emojiViewDidPressDeleteButton:(UIButton *)deletebutton {
    
    if (self.inputBar.inputTextView.text.length > 0) {
        NSRange lastRange = [self.inputBar.inputTextView.text rangeOfComposedCharacterSequenceAtIndex:self.inputBar.inputTextView.text.length-1];
        self.inputBar.inputTextView.text = [self.inputBar.inputTextView.text substringToIndex:lastRange.location];
    }
}

//点击表情
- (void)emojiViewDidSelectEmoji:(NSString *)emoji {
    if ([self.inputBar.inputTextView.textColor isEqual:[UIColor lightGrayColor]] && [self.inputBar.inputTextView.text isEqualToString:@"输入消息..."]) {
        self.inputBar.inputTextView.text = nil;
        self.inputBar.inputTextView.textColor = [UIColor blackColor];
    }
    self.inputBar.inputTextView.text = [self.inputBar.inputTextView.text stringByAppendingString:emoji];
}

//点击表情面板的发送按钮
- (void)didEmotionViewSendAction {
    
    [self inputBar:self.inputBar didSendText:self.inputBar.inputTextView.text];
    self.inputBar.inputTextView.text = @"";
}

#pragma mark - @protocol YYKeyboardObserver
- (void)keyboardChangedWithTransition:(YYKeyboardTransition)transition {
    CGRect toFrame =  [[YYKeyboardManager defaultManager] convertRect:transition.toFrame toView:self.view];
    [UIView animateWithDuration:0.35 animations:^{
        self.inputBar.umcBottom = CGRectGetMinY(toFrame);
        [self.imTableView setTableViewInsetsWithBottomValue:CGRectGetHeight(toFrame)+64+20];
        if (transition.toVisible) {
            [self.imTableView scrollToBottomAnimated:NO];
            self.emojiView.alpha = 0.0;
            self.recordView.alpha = 0.0;
        }
    }];
}

//input工具类
- (UMCInputBarHelper *)inputBarHelper {
    if (!_inputBarHelper) {
        _inputBarHelper = [[UMCInputBarHelper alloc] init];
    }
    return _inputBarHelper;
}

//图片选择工具类
- (UMCImagePicker *)imagePicker {
    if (!_imagePicker) {
        _imagePicker = [[UMCImagePicker alloc] init];
    }
    return _imagePicker;
}

#pragma mark - 消息发送完成回调
- (void)updateSendCompletedMessage:(UMCMessage *)message {
    
    message.merchantEuid = self.merchantId;
    //更新商户列表最后一条消息
    if (self.UpdateLastMessageBlock) {
        self.UpdateLastMessageBlock(message);
    }
    
    NSArray *array = [self.UIManager.messagesArray valueForKey:@"messageId"];
    if ([array containsObject:message.UUID]) {
        [self.imTableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:[array indexOfObject:message.UUID] inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
    }
}

#pragma mark - 设置背景颜色
- (void)setBackgroundColor:(UIColor *)color {
    self.view.backgroundColor = color;
    self.imTableView.backgroundColor = color;
}

#pragma mark - dismissChatViewController
- (void)dismissChatViewController {
    
    //离开页面 标记已读
    [UMCManager readMerchantsWithEuid:self.merchantId completion:nil];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    // 停止播放语音
    [[UMCAudioPlayerHelper shareInstance] stopAudio];
    [UMCManager leaveChatViewController];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [UMCManager enterChatViewController];
}

- (void)dealloc {
    NSLog(@"%@销毁了",[self class]);
    [[YYKeyboardManager defaultManager] removeObserver:self];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];
}

/*
 #pragma mark - Navigation
 
 // In a storyboard-based application, you will often want to do a little preparation before navigation
 - (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
 // Get the new view controller using [segue destinationViewController].
 // Pass the selected object to the new view controller.
 }
 */

@end