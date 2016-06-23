//
//  UIScrollView+MAXRefresh.m
//  封装上下拉刷新
//
//  Created by maixilin on 15/10/10.
//  Copyright (c) 2015年 MAX. All rights reserved.
//

#import "MAXRefresh.h"
#import <objc/runtime.h>

/** 观察scrollView的偏移量 */
#define kScrollViewContentOffset @"contentOffset" 
/** 观察scrollView的滚动区域 */
#define kScrollViewContentSize   @"contentSize" 
/** 观察手势的状态 */
#define kScrollViewPanState      @"state"

/** 头部拖拽超出的高度 */
#define kHeaderDragHeight -70

/** 头部停止时的高度 */
#define kHeaderPullingHeight 70

/** 尾部拖拽超出的高度 */
#define kFooterDragHeight 60

// 头部刷新状态
typedef NS_ENUM(NSInteger, MAXHeaderRefreshState) {
    /** 空闲状态 */
    MAXHeaderRefreshStateNormal,
    /** 结束刷新 */
    MAXHeaderRefreshStateEnd,
    /** 正在刷新 */
    MAXHeaderRefreshStateRefreshing,
    /** 松手立即刷新 */
    MAXHeaderRefreshStatePulling,
};

// 尾部刷新状态
typedef NS_ENUM(NSInteger, MAXFooterRefreshState) {
    /** 空闲状态 */
    MAXFooterRefreshStateNormal,
    /** 结束刷新 */
    MAXFooterRefreshStateEnd,
    /** 正在刷新 */
    MAXFooterRefreshStateRefreshing,
    /** 松手立即刷新 */
    MAXFooterRefreshStatePulling,
};

typedef NS_ENUM(NSInteger, RefreshHeaderOrFooterState) {
    /** 没有刷新 */
    MAXRefreshHeaderOrFooterStateNon,
    /** 头部刷新 */
    MAXRefreshHeaderOrFooterStateHeader,
    /** 尾部刷新 */
    MAXRefreshHeaderOrFooterStateFooter,
};

typedef void(^CallBack)();

#pragma mark - baseView

@interface MAXBaseView ()

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIActivityIndicatorView *indicationView;
@property (nonatomic, strong) UILabel *pullingTitle;
@property (nonatomic, strong) UILabel *titleLbl;
@property (nonatomic, strong) UIImageView *arrow;
@property (nonatomic, copy  ) CallBack callBack;
@property (nonatomic, assign) MAXHeaderRefreshState headerState;
@property (nonatomic, assign) MAXFooterRefreshState footerState;
@property (nonatomic, assign) RefreshHeaderOrFooterState headerOrFooterState;

@property (nonatomic, assign) BOOL autoLoadMore;
//@property (nonatomic, assign) BOOL notMore;

@end

@implementation MAXBaseView

- (void)willMoveToSuperview:(UIView *)newSuperview
{
    [super willMoveToSuperview:newSuperview];
    
    // 移除旧的父控件
    [self.superview removeObserver:self forKeyPath:kScrollViewContentOffset context:NULL];
    
    // 是否为新的控件
    if (newSuperview)
    {
        // 记录
        self.scrollView = (UIScrollView *)newSuperview;
        
        // 设置永远支持垂直弹簧效果
        // 防止数据没有布满整个scrollView时而不能拖拽刷新
        self.scrollView.alwaysBounceVertical = YES;

        // 观察
        [self.scrollView addObserver:self forKeyPath:kScrollViewContentOffset options:NSKeyValueObservingOptionNew context:NULL];
    }
}

- (CGSize)getWidthWithText:(NSString *)text
{
    return [text boundingRectWithSize:CGSizeMake(self.scrollView.bounds.size.width, kTitleFont+5) options:NSStringDrawingUsesFontLeading| NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:kTitleFont]} context:NULL].size;
}

@end


#pragma mark - header

/**
 头部的view
 */
@implementation MAXHeader

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame])
    {
        self.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        
        // 下拉状态提示
        self.pullingTitle = [[UILabel alloc] init];
        self.pullingTitle.frame = CGRectZero;
        self.pullingTitle.textAlignment = NSTextAlignmentCenter;
        self.pullingTitle.textColor = [UIColor grayColor];
        self.pullingTitle.font = [UIFont boldSystemFontOfSize:kTitleFont];
        self.pullingTitle.text = kHeaderTitle;
        [self addSubview:self.pullingTitle];
        
        [self setPullingText];
        
        self.pullingTitle.autoresizingMask = self.autoresizingMask;
        
        // 标题
        self.titleLbl = [[UILabel alloc] init];
        self.titleLbl.frame = CGRectMake(0, CGRectGetMaxY(self.indicationView.frame), frame.size.width, 20);
        self.titleLbl.textAlignment = NSTextAlignmentCenter;
        self.titleLbl.textColor = [UIColor grayColor];
        self.titleLbl.font = [UIFont boldSystemFontOfSize:kTitleFont];
        self.titleLbl.text = @"最后刷新:-- --";
        [self addSubview:self.titleLbl];
        
        [self setTitleText];
        
        self.titleLbl.autoresizingMask = self.autoresizingMask;
        
        // 箭头
        UIImage *arrow = [UIImage imageNamed:@"maxarrow.png"];
        self.arrow = [[UIImageView alloc] initWithFrame:CGRectMake(CGRectGetMinX(self.titleLbl.frame)-arrow.size.width-50, 5, arrow.size.width, arrow.size.height)];
        self.arrow.image = arrow;
        [self addSubview:self.arrow];
        
        self.arrow.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        
        // 旋转的菊花
        self.indicationView = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(CGRectGetMinX(self.titleLbl.frame)-30-40, 10, 30, 30)];
        self.indicationView.color = [UIColor grayColor];
        self.indicationView.hidden = YES;
        [self addSubview:self.indicationView];
        
        self.indicationView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    }
    return self;
}

// 设置下拉标题的frame
- (void)setPullingText
{
    CGSize size = [self getWidthWithText:self.pullingTitle.text];
    self.pullingTitle.frame = CGRectMake(self.bounds.size.width/2-size.width/2, 0, size.width+5, size.height);
}

// 设置标题的frame
- (void)setTitleText
{
    CGSize size = [self getWidthWithText:self.titleLbl.text];
    self.titleLbl.frame = CGRectMake(self.bounds.size.width/2-size.width/2, 25, size.width+5, size.height);
}

// 刷新UI
- (void)reloadRefreshState:(MAXHeaderRefreshState)refreshState
{
    if (self.headerState == refreshState) {
        return;
    }
    
    self.headerState = refreshState;
    
    switch (refreshState)
    {
        case MAXHeaderRefreshStateNormal:
        {
            self.pullingTitle.text = kHeaderTitle;
            self.indicationView.hidden = YES;
            self.arrow.hidden = NO;
            [self setPullingText];
            [self reversalArrow:NO];
        }
            break;

        case MAXHeaderRefreshStatePulling:
        {
            self.pullingTitle.text = kPullingTitile;
            [self setPullingText];
            [self reversalArrow:YES];
        }
            break;
            
        case MAXHeaderRefreshStateRefreshing:
        {
            self.pullingTitle.text = kHeaderBeginTitle;
            self.indicationView.hidden = NO;
            self.arrow.hidden = YES;
            [self setPullingText];
            [self reversalArrow:NO];
        }
            break;
            
        case MAXHeaderRefreshStateEnd:
        {
            
        }
            break;
            
        default:
            break;
    }
}

// 翻转箭头
- (void)reversalArrow:(BOOL)reversal
{
    [UIView animateWithDuration:0.25 animations:^{
        
        if (reversal)
        {
            self.arrow.transform = CGAffineTransformMakeRotation(M_PI);
        }
        else
        {
            self.arrow.transform = CGAffineTransformIdentity;
        }
    }];
}

// 观察scrollView的contentOffset
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    // 判断手势状态
    if ([keyPath isEqualToString:kScrollViewPanState])
    {
        UIGestureRecognizerState state = [change[NSKeyValueChangeNewKey] integerValue];
        
        if (state == UIGestureRecognizerStateEnded && self.headerState == MAXHeaderRefreshStatePulling)
        {
            [self beginHeader];
        }
    }
    else if ([keyPath isEqualToString:kScrollViewContentOffset])
    {
        CGFloat offsetY = [change[NSKeyValueChangeNewKey] CGPointValue].y;
        
        // scrollView是否有偏移
        UIEdgeInsets insets = self.scrollView.contentInset;
        
        if (offsetY <= kHeaderDragHeight - insets.top && self.headerState != MAXHeaderRefreshStateRefreshing)
        {
            [self reloadRefreshState:MAXHeaderRefreshStatePulling];
        }
        else
        {
            [self reloadRefreshState:(self.headerState == MAXHeaderRefreshStateRefreshing ? MAXHeaderRefreshStateRefreshing : MAXHeaderRefreshStateNormal)];
        }
    }
}

- (void)beginHeader
{
    if (self.callBack) {
        
        [self reloadRefreshState:MAXHeaderRefreshStateRefreshing];
        
        [self beginRefresh];
        
        // 让菊花继续旋转N秒
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            
            self.callBack();
        });
    }
}

- (void)beginRefresh
{
    // 获取当前时间
    NSDate *nowDate = [NSDate date];
    
    // 设置时间格式
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    
    // 设置格式
    formatter.dateFormat = @"最后刷新: MM-dd HH:mm";
    
    // 将格式化的时间转成字符串
    NSString *dateStr = [formatter stringFromDate:nowDate];
    
    // 设置头部日期文字
    self.titleLbl.text = dateStr;
    
    [self setTitleText];
    
    // 开始旋转
    [self.indicationView startAnimating];
    
    // 修改scrollView的偏移量
    UIEdgeInsets insets = self.scrollView.contentInset;
    
    if (self.scrollView.contentInset.top == insets.top+kHeaderPullingHeight) {
        return;
    }
    
    [UIView animateWithDuration:0.2 animations:^{
        
        self.scrollView.contentInset = UIEdgeInsetsMake(insets.top+kHeaderPullingHeight, insets.left, insets.bottom, insets.right);
    }];
}

- (void)endRefresh
{
    if (self.scrollView.contentInset.top == 0) {
        return;
    }
    
    // 还原scrollView的偏移量
    UIEdgeInsets instes = self.scrollView.contentInset;
    
    [UIView animateWithDuration:0.2 animations:^{
        
        self.scrollView.contentInset = UIEdgeInsetsMake(instes.top-kHeaderPullingHeight, instes.left, instes.bottom, instes.right);
        
    } completion:^(BOOL finished) {
        
        [self.indicationView stopAnimating];
        [self reloadRefreshState:MAXHeaderRefreshStateEnd];
    }];
}

@end

#pragma mark - footer

@interface MAXFooter ()

/** 没有更多的数据了 */
@property (nonatomic, assign) BOOL noMore;

@end

/**
 尾部的view
 */
@implementation MAXFooter

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame])
    {
        self.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        
        // 标题
        CGSize size = [self getWidthWithText:kFooterTitle];
        self.titleLbl = [[UILabel alloc] initWithFrame:CGRectMake(self.bounds.size.width/2-(size.width/2), self.bounds.size.height/2-(size.height/2), size.width, size.height)];
        self.titleLbl.textAlignment = NSTextAlignmentCenter;
        self.titleLbl.textColor = [UIColor grayColor];
        self.titleLbl.font = [UIFont boldSystemFontOfSize:kTitleFont];
        self.titleLbl.text = kFooterTitle;
        [self addSubview:self.titleLbl];
        
        self.titleLbl.autoresizingMask = self.autoresizingMask;
        
        // 旋转的菊花
        self.indicationView = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(self.titleLbl.frame.origin.x-30, self.bounds.size.height/2-15, 30, 30)];
        self.indicationView.color = [UIColor grayColor];
        [self addSubview:self.indicationView];
        
        self.titleLbl.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    }
    return self;
}

- (void)setNoMore:(BOOL)noMore
{
    _noMore = noMore;
    
    if (_noMore) {
        self.indicationView.hidden = YES;
        self.titleLbl.text = kNoMoreTitle;
        
    }
    
    [self setTitleText];
}

// 设置标题的frame
- (void)setTitleText
{
    CGSize size = [self getWidthWithText:self.titleLbl.text];
    CGRect rect = self.titleLbl.frame;
    rect.size.width = size.width+5;
    rect.origin.x = self.bounds.size.width/2 - size.width/2;
    self.titleLbl.frame = rect;
    
    rect = self.indicationView.frame;
    rect.origin.x = CGRectGetMinX(self.titleLbl.frame)-40;
    self.indicationView.frame = rect;
}

// 刷新UI
- (void)reloadRefreshState:(MAXFooterRefreshState)refreshState
{
    if (self.footerState == refreshState) {
        return;
    }
    
    self.footerState = refreshState;
    
    switch (refreshState)
    {
        case MAXFooterRefreshStateNormal:
        {
            self.titleLbl.text = kFooterTitle;
            [self setTitleText];
        }
            break;
            
        case MAXFooterRefreshStatePulling:
        {
            self.titleLbl.text = kPullingTitile;
            [self setTitleText];
        }
            break;
            
        case MAXFooterRefreshStateRefreshing:
        {
            self.titleLbl.text = kFooterBeginTitle;
            [self setTitleText];
        }
            break;
            
        case MAXFooterRefreshStateEnd:
        {
            
        }
            break;
            
        default:
            break;
    }
}

// 观察scrollView的contentOffset
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    // 判断手势状态
    if ([keyPath isEqualToString:kScrollViewPanState])
    {
        UIGestureRecognizerState state = [change[NSKeyValueChangeNewKey] integerValue];

        if (state == UIGestureRecognizerStateEnded && self.footerState == MAXFooterRefreshStatePulling)
        {
            [self beginFooter];
        }
    }
    // 当scrollView contentSize发生变化的时候，重新修改footView的y轴坐标
    else if ([keyPath isEqualToString:kScrollViewContentSize])
    {
        // 获取新的值
        CGSize size = [change[NSKeyValueChangeNewKey] CGSizeValue];
        
        CGRect rect = self.frame;
        
        CGFloat offsetY = size.height > 0 ? size.height : self.scrollView.bounds.size.height;
        
        if ([self.scrollView isKindOfClass:[UITableView class]])
        {
            UITableView *tableV = (UITableView *)self.scrollView;
            
            // 减去表头
            offsetY = size.height - tableV.tableHeaderView.bounds.size.height > 0 ? size.height : self.scrollView.bounds.size.height;
        }
        
        rect.origin.y = offsetY;
        
        self.frame = rect;
    }
    
    // 没有更多数据可以加载了
    if (self.noMore) {
        return;
    }
    
    // 当scrollView contentOffset偏移量发生变化的时候
    if ([keyPath isEqualToString:kScrollViewContentOffset] && self.footerState != MAXFooterRefreshStateRefreshing)
    {
        CGFloat offsetY = [change[NSKeyValueChangeNewKey] CGPointValue].y;
        
        CGFloat contentSizeHeight = self.scrollView.contentSize.height;
        CGFloat height = self.scrollView.bounds.size.height;
        
        // 自动加载更多
        CGFloat currHeight = contentSizeHeight - height + (self.autoLoadMore ? 0 : kFooterDragHeight);
        
        if ((offsetY > currHeight) && (offsetY > 0) && self.autoLoadMore) {
            
            [self beginFooter];
            return;
        }
        
        // contentSizeHeight - height
        if ((offsetY > currHeight) && (offsetY > 0))
        {
            [self reloadRefreshState:MAXFooterRefreshStatePulling];
        }
        else
        {
            [self reloadRefreshState:MAXFooterRefreshStateNormal];
        }
    }
    else
    {
        [self reloadRefreshState:(self.footerState == MAXFooterRefreshStateRefreshing ? MAXFooterRefreshStateRefreshing : MAXFooterRefreshStateNormal)];
    }
}

- (void)beginFooter
{
    if (self.callBack) {
        
        [self reloadRefreshState:MAXFooterRefreshStateRefreshing];
        
        [self beginRefresh];
        
        // 让菊花旋转N秒
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            
            self.callBack();
        });
    }
}

- (void)beginRefresh
{
    // 修改尾部提示
    self.titleLbl.text = kFooterBeginTitle;
    
    // 开始旋转
    [self.indicationView startAnimating];
    
    // 修改scrollView的偏移量
    UIEdgeInsets instes = self.scrollView.contentInset;
    
//    if (instes.bottom == 0) {
//        
//    }
    
    if (self.scrollView.contentInset.bottom == instes.bottom+kFooterDragHeight) {
        return;
    }
    
    self.scrollView.contentInset = UIEdgeInsetsMake(instes.top, instes.left, instes.bottom+kFooterDragHeight, instes.right);
}

- (void)endRefresh
{
    // 还原scrollView的偏移量
    UIEdgeInsets instes = self.scrollView.contentInset;
    
    if (self.scrollView.contentInset.bottom == instes.bottom-kFooterDragHeight) {
        return;
    }
    
    [UIView animateWithDuration:0.3 animations:^{
        
        self.scrollView.contentInset = UIEdgeInsetsMake(instes.top, instes.left, instes.bottom-kFooterDragHeight, instes.right);
        
    } completion:^(BOOL finished) {
        [self.indicationView stopAnimating];
        self.titleLbl.text = self.noMore ? kNoMoreTitle : kFooterTitle;
        [self reloadRefreshState:MAXFooterRefreshStateEnd];
    }];
}

@end

#pragma mark - scrollView

@interface UIScrollView ()

@property (nonatomic, strong) refreshBlock block;
@property (nonatomic, strong) UIPanGestureRecognizer *pan;

@end

@implementation UIScrollView (MAXRefresh)

#pragma mark - 利用运行时给类别添加属性

static const void *refreshBlockKey = &refreshBlockKey;
static const void *headerKey       = &headerKey;
static const void *footerKey       = &footerKey;
static const void *autoLoadMoreKey = &autoLoadMoreKey;
static const void *noMoreKey      = &noMoreKey;
static const void *panKey          = &panKey;

// block
- (void)setBlock:(refreshBlock)block
{
    objc_setAssociatedObject(self, refreshBlockKey, block, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (refreshBlock)block
{
    return objc_getAssociatedObject(self, refreshBlockKey);
}

// header
- (void)setHeader:(MAXHeader *)header
{
    objc_setAssociatedObject(self, headerKey, header, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (MAXHeader *)header
{
    return objc_getAssociatedObject(self, headerKey);
}

// footer
- (void)setFooter:(MAXFooter *)footer
{
    objc_setAssociatedObject(self, footerKey, footer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (MAXFooter *)footer
{
    return objc_getAssociatedObject(self, footerKey);
}

// autoLoadMore
- (void)setAutoLoadMore:(BOOL)autoLoadMore
{
    objc_setAssociatedObject(self, autoLoadMoreKey, @(autoLoadMore), OBJC_ASSOCIATION_ASSIGN);
    self.footer.autoLoadMore = autoLoadMore;
}
- (BOOL)autoLoadMore
{
    return objc_getAssociatedObject(self, autoLoadMoreKey);
}

// noMore
- (void)setNoMore:(BOOL)noMore
{
    objc_setAssociatedObject(self, noMoreKey, @(noMore), OBJC_ASSOCIATION_ASSIGN);
    self.footer.noMore = noMore;
}
- (BOOL)noMore
{
    return objc_getAssociatedObject(self, noMoreKey);
}

// pan
- (void)setPan:(UIPanGestureRecognizer *)pan
{
    objc_setAssociatedObject(self, panKey, pan, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (UIPanGestureRecognizer *)pan
{
    return objc_getAssociatedObject(self, panKey);
}

- (void)addHeaderWithRefreshBlcok:(refreshBlock)block
{
    [self addHeaderView];
    self.header.callBack = block;
}

- (void)addFooterWithRefreshBlock:(refreshBlock)block
{
    [self addFooterView];
    
    self.footer.callBack = block;
    
    // 默认不自动加载更多
    self.footer.autoLoadMore = NO;
    
    // 默认不显示
    self.footer.noMore = NO;
}

/**
 加载头部的视图
 */
- (void)addHeaderView
{
    self.header = [[MAXHeader alloc] initWithFrame:CGRectMake(0, -60, self.bounds.size.width, 50)];
    [self addSubview:self.header];
    
    // 记录
    self.pan = self.panGestureRecognizer;
    
    // 监听手势拖拽
    [self.pan addObserver:self.header forKeyPath:kScrollViewPanState options:NSKeyValueObservingOptionNew context:NULL];
}

/**
 加载尾部的视图
 */
- (void)addFooterView
{
    self.footer = [[MAXFooter alloc] initWithFrame:CGRectMake(0, self.bounds.size.height, self.bounds.size.width, 50)];
    
    [self addSubview:self.footer];
    
    // 观察
    [self addObserver:self.footer forKeyPath:kScrollViewContentSize options:NSKeyValueObservingOptionNew context:NULL];
    
    // 监听手势拖拽
    [self.pan addObserver:self.footer forKeyPath:kScrollViewPanState options:NSKeyValueObservingOptionNew context:NULL];
}

/**
 开始头部刷新
 */
- (void)headerBeginRefresh
{
    [self.header beginHeader];
}

/**
 开始尾部刷新
 */
- (void)footerBeginRefresh
{
    [self.footer beginFooter];
}

/**
 结束刷新
 */
- (void)endRefresh
{
    if (self.header.headerState == MAXHeaderRefreshStateRefreshing) {
        [self.header endRefresh];
    }
    
    if (self.footer.footerState == MAXFooterRefreshStateRefreshing) {
        [self.footer endRefresh];
    }
}

@end
