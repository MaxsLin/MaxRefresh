//
//  UIScrollView+MAXRefresh.h
//  封装上下拉刷新
//
//  Created by maixilin on 15/10/10.
//  Copyright (c) 2015年 MAX. All rights reserved.
//
//  v2.2版本

#import <UIKit/UIKit.h>

#define kHeaderTitle      @"下拉可以刷新"
#define kFooterTitle      @"上拉加载更多"
#define kHeaderBeginTitle @"正在加载..."
#define kFooterBeginTitle @"正在加载更多..."
#define kPullingTitile    @"松手立即刷新"
#define kNoMoreTitle      @"没有更多的数据了"

/** 提示文字的大小 */
#define kTitleFont  14

@interface MAXBaseView : UIView

@end

/**
 头部的view
 */
@interface MAXHeader : MAXBaseView

@end


/**
 尾部的view
 */
@interface MAXFooter : MAXBaseView

@end


typedef void(^refreshBlock)();

@interface UIScrollView (MAXRefresh)

/** 头部view */
@property (nonatomic, strong) MAXHeader *header;

/** 尾部view */
@property (nonatomic, strong) MAXFooter *footer;

/**
 当滑到底部时自动触发加载更多，默认NO，当为YES时停止自动加载
 */
@property (nonatomic, assign) BOOL autoLoadMore;

/**
 尾部加载，没有更多数据了，当为YES时可加载更多，默认为NO
 */
@property (nonatomic, assign) BOOL noMore;

/**
 添加头部刷新
 */
- (void)addHeaderWithRefreshBlcok:(refreshBlock)block;

/**
 添加尾部刷新
 */
- (void)addFooterWithRefreshBlock:(refreshBlock)block;

/**
 开始头部刷新
 */
- (void)headerBeginRefresh;

/**
 开始尾部刷新
 */
- (void)footerBeginRefresh;

/**
 结束刷新
 */
- (void)endRefresh;

@end
