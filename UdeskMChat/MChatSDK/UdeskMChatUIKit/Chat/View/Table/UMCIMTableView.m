//
//  UMCIMTableView.m
//  UdeskMChatExample
//
//  Created by xuchen on 2017/10/19.
//  Copyright © 2017年 Udesk. All rights reserved.
//

#import "UMCIMTableView.h"
#import "UMCUIMacro.h"

@implementation UMCIMTableView

- (instancetype)initWithFrame:(CGRect)frame style:(UITableViewStyle)style {
    self = [super initWithFrame:frame style:style];
    if (self) {
        
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.separatorColor = [UIColor clearColor];
        self.separatorStyle = UITableViewCellSeparatorStyleNone;
        
        if (@available(iOS 11.0, *)) {
            self.estimatedRowHeight = 0;
            self.estimatedSectionHeaderHeight = 0;
            self.estimatedSectionFooterHeight = 0;
        }
        
        _headView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kUMCScreenWidth, 25)];
        _headView.backgroundColor = [UIColor clearColor];
        
        _loadingView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        _loadingView.hidden = NO;
        _loadingView.frame = CGRectMake(_headView.frame.size.width/2-10, 5, 20, 25);
        [_headView addSubview:_loadingView];
        
        self.tableHeaderView = _headView;
        
        _isRefresh = YES;
    }
    return self;
}

//设置ContentSize
- (void)setContentSize:(CGSize)contentSize
{
    if (!CGSizeEqualToSize(self.contentSize, CGSizeZero))
    {
        if (contentSize.height > self.contentSize.height)
        {
            CGPoint offset = self.contentOffset;
            offset.y += (contentSize.height - self.contentSize.height);
            self.contentOffset = offset;
        }
    }
    [super setContentSize:contentSize];
}

//开始下拉
- (void)startLoadingMoreMessages {
    
    self.headView.hidden = NO;
    [self.loadingView startAnimating];
    _isRefresh = NO;
}

//下拉结束
- (void)finishLoadingMoreMessages:(BOOL)isShowRefresh {
    
    //消息小于20条移除菊花
    if (!isShowRefresh) {
        
        //没有更多消息停止刷新
        [self.loadingView stopAnimating];
        self.headView.hidden = YES;
        [self.headView removeFromSuperview];
        [self.loadingView removeFromSuperview];
        self.tableHeaderView = [[UIView alloc] initWithFrame:CGRectZero];;
        
        _isRefresh = NO;
        
    }else {
        
        _isRefresh = YES;
    }
}

//设置TabelView bottom
- (void)setTableViewInsetsWithBottomValue:(CGFloat)bottom {
    UIEdgeInsets insets = [self tableViewInsetsWithBottomValue:bottom];
    self.contentInset = insets;
    self.scrollIndicatorInsets = insets;
}

- (UIEdgeInsets)tableViewInsetsWithBottomValue:(CGFloat)bottom {
    UIEdgeInsets insets = UIEdgeInsetsZero;
    
    insets.bottom = bottom;
    
    return insets;
}

//滚动TableView
- (void)scrollToBottomAnimated:(BOOL)animated {
    
    @try {
        
        NSInteger rows = [self numberOfRowsInSection:0];
        
        if (rows > 0) {
            [self scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:rows - 1 inSection:0]
                        atScrollPosition:UITableViewScrollPositionBottom
                                animated:animated];
        }
    } @catch (NSException *exception) {
        NSLog(@"%@",exception);
    } @finally {
    }
}

@end
