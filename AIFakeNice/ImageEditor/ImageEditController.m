//
//  ViewController.m
//  imageEditorController
//
//  Created by 魏瑞东 on 15/6/29.
//  Copyright (c) 2015年 Weiruidong. All rights reserved.
//

#import "ImageEditController.h"
#import "firstTableView.h"
#import "NormalDefectModel.h"
#import "moveView.h"
#import "MJExtension.h"
#import "ImgButton.h"
#import "GetDBUniqueID.h"
#import "NSString+StrExt.h"
#import "UIImage+Extension.h"
#import "Cover.h" 
#import "PPNavigationViewController.h"

#define MAXTextWidth 270
#define MAXTextHeight 40
#define LAbelHeight 35
@interface ImageEditController ()
@property (weak, nonatomic) IBOutlet ImgButton *imagebutton;

@property (nonatomic,assign) NSInteger flag;
//  记录瑕疵点index
@property (nonatomic,assign) NSInteger index;
// 存放瑕疵点模型的数组
@property (nonatomic,strong) NSMutableArray *detectArray;
@property (nonatomic,strong) Cover *cover;

// 保存瑕疵点添加顺序，用来删除
@property (nonatomic,strong) NSMutableArray *deleteArray;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *addDefectWidth;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *addDefectHeight;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *removeDefectWidth;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *removeDefectHeight;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *saveWidth;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *saveHeight;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *retakeWidth;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *retakeHeight;


@end

@implementation ImageEditController
{
    void(^_callback)(UIImage *, NSArray *,UIImage *);
    NSData *_imageData;
}
- (NSMutableArray *)deleteArray{
    if (_deleteArray == nil) {
        _deleteArray = [NSMutableArray array];
    }
    return _deleteArray;
}

- (NSMutableArray *)detectArray{
    if (_detectArray == nil) {
        _detectArray = [NSMutableArray array];
    }
    return _detectArray;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.navigationController.navigationBarHidden = YES;
    [[UIApplication sharedApplication] setStatusBarHidden:YES];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [[UIApplication sharedApplication] setStatusBarHidden:NO];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self.imagebutton setBackgroundImage:[UIImage imageWithData:_imageData] forState:UIControlStateNormal];
    [self.imagebutton setBackgroundImage:[UIImage imageWithData:_imageData] forState:UIControlStateHighlighted];
    self.imagebutton.adjustsImageWhenHighlighted = NO;
//    [self.imagebutton setBackgroundImage:[UIImage imageWithData:_imageData] forState:UIControlStateHighlighted];
//    [self.imagebutton addTarget:self action:@selector(clickImageBtn:) forControlEvents:UIControlEventTouchDragInside];
}

- (void)updateViewConstraints
{
    [super updateViewConstraints];
    
    NSString *deviceType = [GetDBUniqueID getCurrentDeviceType];
    
    if ([deviceType isEqualToString:@"5"]) {
        _addDefectHeight.constant = 60;
        _addDefectWidth.constant = 60;
        _removeDefectHeight.constant = 60;
        _removeDefectWidth.constant = 60;
        _saveHeight.constant = 60;
        _saveWidth.constant = 60;
        _retakeHeight.constant = 60;
        _retakeWidth.constant = 60;
    }
}



- (void)viewDidLoad {
    [super viewDidLoad];
//    [Util showTips:@"最多添加四个瑕疵点!" forSecond:2.0f onView:self.view];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(newAddDefectLabel:) name:AIDefectNotefication object:nil];
//    [[UIDevice currentDevice] setValue:[NSNumber numberWithInteger:UIDeviceOrientationPortrait] forKey:@"orientation"];//这句话是防止手动先把设备置为横屏,导致下面的语句失效.
    [[UIDevice currentDevice] setValue:[NSNumber numberWithInteger:UIDeviceOrientationLandscapeLeft] forKey:@"orientation"];
//    self.view.transform = CGAffineTransformMakeRotation(-M_PI/2);
    [self addCoverView];

    
}
- (void)addCoverView{
    Cover *cover = [[NSBundle mainBundle] loadNibNamed:@"cover" owner:self options:nil][0];
    self.cover = cover;
    
    if ([[[UIDevice currentDevice] systemVersion] floatValue] < 8.0) {
        cover.frame = CGRectMake(0, 0, (SCREENWIDTH - 40 ) * 3/2, SCREENWIDTH - 40);
    }else {
        cover.frame = CGRectMake(0, 0, (SCREENHEIGHT - 40 ) * 3/2, SCREENHEIGHT - 40);
    }
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(removeCover)];
    [cover addGestureRecognizer:tap];
    [self.imagebutton addSubview:cover];
}

- (void)removeCover{
    [self.cover removeFromSuperview];
    [self clickImageBtn:nil];
    [AINoteCenter postNotificationName:AITimerNotefication object:self userInfo:nil];
}

- (instancetype)initWithImage:(NSData *)imageData defects:(NSArray *)defects callback:(void (^)(UIImage *, NSArray *,UIImage *))callback
{
    self = [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:@"ImageEditController"];
    
    if (self) {
        self.titleArray = defects;
        _callback = callback;
        _imageData = imageData;
    }
    
    return self;
}



- (IBAction)saveImage:(UIButton *)sender {
    for (UIView *view in self.imagebutton.subviews) {
        if ([view isKindOfClass:[Cover class]]) {
            [GetDBUniqueID showTips:@"请添加瑕疵！" forSecond:1.0f onView:self.view];
            return;
        }
    }
    if(self.imagebutton.subviews.count == 1){
        [GetDBUniqueID showTips:@"请添加瑕疵！" forSecond:1.0f onView:self.view];
        return;
    }
    
    // 保存图片，并将坐标对应赋值给数组中对应的模型（index 和 tag 一致）
    for (moveView *view in self.imagebutton.subviews) {
        if ([view isKindOfClass:[moveView class]]) {
            for (NormalDefectModel *modal in self.detectArray) {
                if ([modal.index isEqualToString:[NSString stringWithFormat:@"%ld",(long)view.tag]]) {
                    CGFloat x = view.frame.origin.x / self.imagebutton.frame.size.width;
                    CGFloat y = (view.frame.origin.y + 0.5 * LAbelHeight) / self.imagebutton.frame.size.height;
                    if([view.direction isEqualToString:@"R"]){
                        x = (view.frame.origin.x + view.frame.size.width) / self.imagebutton.frame.size.width;
                    }
                    if (x < 0) {
                        x = fabs(x);
                    }
                    NSString *X = [NSString stringWithFormat:@"%.6f",x];
                    NSString *Y = [NSString stringWithFormat:@"%.6f",y];
                    modal.point = [NSString stringWithFormat:@"%@,%@",X,Y];
                    modal.direction = view.direction;
                }
            }
        }
    }
    NSLog(@"----%@",self.detectArray);
    
    UIGraphicsBeginImageContext(self.imagebutton.bounds.size);  //NO，YES 控制是否透明
    [self.imagebutton.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    UIImage *originImage = [UIImage imageWithData:_imageData];
    _callback(image, self.detectArray,originImage);
}

- (IBAction)retakeClick:(id)sender {
        [[UIDevice currentDevice] setValue:[NSNumber numberWithInteger:UIDeviceOrientationPortrait] forKey:@"orientation"];
    [self.navigationController popViewControllerAnimated:YES];
}

-(void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}


//  点击增加瑕疵
- (IBAction)addDefect:(id)sender {
    [self.cover removeFromSuperview];
    [AINoteCenter postNotificationName:AITimerNotefication object:self userInfo:nil];
    NSInteger max_count;
    
    if (self.Label_Max_Count == 0) {
        max_count = 4;
    }else{
        max_count = self.Label_Max_Count;
    }
    if(self.imagebutton.subviews.count >= max_count + 1){
        [GetDBUniqueID showTips:@"添加瑕疵超过最大数量！" forSecond:1.0f onView:self.view];
        return;
    }
    firstTableView *first = [[firstTableView alloc]init];
    // 分别将两个数组传递过去（标题组 ＋ 总数组）
    first.firstArray = [self foundSecionTitleWithArray:self.titleArray];
    first.totalArray = self.titleArray;
    PPNavigationViewController *nav = [[PPNavigationViewController alloc]initWithRootViewController:first];
    [self presentViewController:nav animated:YES completion:nil];
}
//



// 点击删除瑕疵
- (IBAction)deleteDefect:(id)sender {
    
//    UIView *view = self.imagebutton.subviews.lastObject;
//    
//    if ([view isKindOfClass:[moveView class]]) {
//        [view removeFromSuperview];
//        [self.detectArray removeObjectAtIndex:self.detectArray.count -1];
//    }
    
    UIView *view = self.deleteArray.lastObject;
    if (view) {
        [view removeFromSuperview];
        [self.deleteArray removeObjectAtIndex:self.deleteArray.count - 1];
        [self.detectArray removeObjectAtIndex:self.detectArray.count - 1];
    }
    
}

//   点击图片任意位置
- (IBAction)clickImageBtn:(ImgButton *)sender {
    [self addDefect:nil];
    
}


- (void)newAddDefectLabel:(NSNotification *)note{
    self.flag = 0;
    NSDictionary *dict = [note userInfo];
    NormalDefectModel *modal = [NormalDefectModel objectWithKeyValues:dict];

    CGPoint point = [GetDBUniqueID shareUniqueID].originPoint;
    CGFloat x;CGFloat y;
    CGSize titleSize = [modal.title sizeWithFont:[UIFont systemFontOfSize:16] maxSize:CGSizeMake(MAXTextWidth, MAXTextHeight)];
    
    //  如果已经记录了当前点击的位置
    if ((point.x != 0) && (point.y != 0)) {
        x = point.x;
        y = point.y - 0.5 * LAbelHeight;
        // 判断小按钮超出图片范围
        NSLog(@"%@",NSStringFromCGSize(self.imagebutton.frame.size));
        if (point.y + LAbelHeight > self.imagebutton.frame.size.height) {
            y = self.imagebutton.frame.size.height - LAbelHeight;
        }
        if (point.y - LAbelHeight < 0) {
            y = 0;
        }
        if (point.x + titleSize.width + 40 > self.imagebutton.frame.size.width){
            self.flag = 1;
//            x = self.imagebutton.frame.size.width - (titleSize.width + 40);
            x = point.x - (titleSize.width + 40);
        }
    }else{
        x = 50;
        y = arc4random() % 200 + 10;
    }
    
    moveView *view = [[moveView alloc]initWithFrame:CGRectMake(x, y, titleSize.width + 40,LAbelHeight)];
    
    [GetDBUniqueID shareUniqueID].originPoint = CGPointZero;
    
    
    UIImage *arrow1_normal = [UIImage resizableImageWithName:@"arrow1_normal"];
    UIImage *arrow2_normal = [UIImage resizableImageWithName:@"arrow2_normal"];
    UIImage *arrow1_special = [UIImage resizableImageWithName:@"arrow1_special"];
    UIImage *arrow2_special = [UIImage resizableImageWithName:@"arrow2_special"];
    
    
    
    if (self.flag) {
        view.contentEdgeInsets = UIEdgeInsetsMake(0, 0, 0, 20);
        view.direction = @"R";
        if (![modal.localLevel isEqualToString:@"0"]) {
            view.changeColor = 1;
            [view setBackgroundImage:arrow2_special forState:UIControlStateNormal];
        }else{
            view.changeColor = 0;
            [view setBackgroundImage:arrow2_normal forState:UIControlStateNormal];
            [view setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        }
    }else{
        view.direction = @"L";
        view.contentEdgeInsets = UIEdgeInsetsMake(0, 20, 0, 0);
        if (![modal.localLevel isEqualToString:@"0"]) {
            view.changeColor = 1;
            [view setBackgroundImage:arrow1_special forState:UIControlStateNormal];
        }else{
            view.changeColor = 0;
            [view setBackgroundImage:arrow1_normal forState:UIControlStateNormal];
            [view setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        }
    }
    
    
    [view setTitle:modal.title forState:UIControlStateNormal];
    view.titleLabel.font = [UIFont systemFontOfSize:16];
    
    
    // 瑕疵点放到数组,用index来进行区分
    self.index ++;
    modal.index = [NSString stringWithFormat:@"%ld",(long)self.index];
    view.tag = self.index;
    [self.deleteArray addObject:view];
    [self.imagebutton addSubview:view];
    [self.detectArray addObject:modal];
}




// 筛选出所有的组标题（去重）
- (NSArray *)foundSecionTitleWithArray:(NSArray *)array{
    NSMutableDictionary *totalTitleDict = [NSMutableDictionary dictionary];
    NSMutableArray *firstArray = [NSMutableArray array];
    for (NormalDefectModel *modal in array) {
        //  利用字典去重
        [totalTitleDict setObject:modal forKey:modal.sectionTitle];
    }
    for (id key in totalTitleDict) {
        NormalDefectModel *modal = [totalTitleDict objectForKey:key];
        [firstArray addObject:modal];
    }
    return firstArray;
}

- (BOOL)shouldAutorotate
{
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskLandscapeRight;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation
{
    return UIInterfaceOrientationLandscapeRight;
}

@end

