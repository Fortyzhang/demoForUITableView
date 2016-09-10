//
//  ViewController.m
//  LazyLoad
//
//  Created by Allen Hsu on 12/14/14.
//  Copyright (c) 2014 Glow, Inc. All rights reserved.
//

#import <AFNetworking/AFNetworking.h>
#import <SDWebImage/UIImageView+WebCache.h>
#import <NSDictionary+Accessors/NSDictionary+Accessors.h>

#import "ViewController.h"
#import "GLImageCell.h"
//@interface GLImageCell : UITableViewCell
//@property (weak, nonatomic) IBOutlet UIImageView *photoView;
//@end

//@implementation GLImageCell
//@end

@interface ViewController () <UITableViewDelegate, UITableViewDataSource>

@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (copy, nonatomic) NSArray *data;
@property (strong, nonatomic) NSValue *targetRect;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [self fetchDataFromServer];
    
    //注册
    UINib *GLImageCell = [UINib nibWithNibName:@"GLImageCell" bundle:nil];
    [_tableView registerNib:GLImageCell forCellReuseIdentifier:@"ImageCell"];
    
}


- (IBAction)didClickRefreshButton:(id)sender {
    [self fetchDataFromServer];
}

//网络请求并处理
- (void)fetchDataFromServer
{
    static NSString *apiURL = @"http://image.baidu.com/search/acjson?tn=resultjson_com&ipn=rj&ie=utf-8&oe=utf-8&word=cat&queryWord=dog";
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    AFHTTPResponseSerializer *serializer = [AFHTTPResponseSerializer serializer];
    [serializer.acceptableContentTypes setByAddingObject:@"text/html"];
    manager.responseSerializer = serializer;
    [manager GET:apiURL parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSLog(@"Request succeeded");
        
        //将字符串替换
        NSString *responseString = [operation.responseString stringByReplacingOccurrencesOfString:@"\\'" withString:@"'"];
        NSData *data = [responseString dataUsingEncoding:NSUTF8StringEncoding];
        NSError *error;
        NSDictionary *responseDictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        //判断responseDictionary是否是NSDictionary类
        if ([responseDictionary isKindOfClass:[NSDictionary class]]) {
            NSArray *originalData = [responseDictionary arrayForKey:@"data"];
            NSMutableArray *dataArr = [NSMutableArray array];
            //遍历数组 originalData
            for (NSDictionary *item in originalData) {
                //字典item中key值：“thumbURL”所对应的value的值的长度大于0，则将字典item添加到数组dataArr中
                if ([item isKindOfClass:[NSDictionary class]] && [[item stringForKey:@"thumbURL"] length] > 0) {
                    [dataArr addObject:item];
                }
            }
            self.data = dataArr;
        } else {
            self.data = nil;
        }
        [self.tableView reloadData];
        
        NSLog(@"%@",self.data);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Request falied");
    }];
}

- (NSDictionary *)objectForRow:(NSInteger)row
{
    if (row < self.data.count) {
        return self.data[row];
    }
    return nil;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.data.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cellIdentifier = @"ImageCell";
    GLImageCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier forIndexPath:indexPath];
    cell.titleLabel.text = self.data[indexPath.row][@"fromPageTitle"];
    [self setupCell:cell withIndexPath:indexPath];
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *obj = [self objectForRow:indexPath.row];
    NSInteger width = [obj integerForKey:@"width"];
    NSInteger height = [obj integerForKey:@"height"];
    if (obj && width > 0 && height > 0) {
        return tableView.frame.size.width / (float)width * (float)height;
    }
    return 44.0;
}

- (void)setupCell:(GLImageCell *)cell withIndexPath:(NSIndexPath *)indexPath
{
//    static NSString *referer = @"http://image.baidu.com/i?tn=baiduimage&ipn=r&ct=201326592&cl=2&lm=-1&st=-1&fm=index&fr=&sf=1&fmq=&pv=&ic=0&nc=1&z=&se=1&showtab=0&fb=0&width=&height=&face=0&istype=2&ie=utf-8&word=cat&oq=cat&rsp=-1";
//    SDWebImageDownloader *downloader = [[SDWebImageManager sharedManager] imageDownloader];
//    [downloader setValue:referer forHTTPHeaderField:@"Referer"];
    
    NSDictionary *obj = [self objectForRow:indexPath.row];
    NSURL *targetURL = [NSURL URLWithString:[obj stringForKey:@"thumbURL"]];
    
    //方法判断，如果cell.iconImage图片的url不一样
    if (![[cell.photoView sd_imageURL] isEqual:targetURL]) {
        
        cell.photoView.opaque = NO;
        cell.photoView.alpha = 0.0;
        SDWebImageManager *manager = [SDWebImageManager sharedManager];
        CGRect cellFrame = [self.tableView rectForRowAtIndexPath:indexPath];
        BOOL shouldLoadImage = YES;
        
        //CGRectIntersectsRect是BOOL类型函数函数，判断cellFrame是否在[self.targetRect CGRectValue]内
        if (self.targetRect && !CGRectIntersectsRect([self.targetRect CGRectValue], cellFrame)) {
            SDImageCache *cache = [manager imageCache];
            NSString *key = [manager cacheKeyForURL:targetURL];
            // imageFromMemoryCacheForKey方法，返回UIImage判断内存中已经有这张图片了，方法则表示没有这张图片
            if (![cache imageFromMemoryCacheForKey:key]) {
                shouldLoadImage = NO;
            }
        }
        if (shouldLoadImage) {
            //加载图片并且添加动画效果
            [cell.photoView sd_setImageWithURL:targetURL placeholderImage:nil options:SDWebImageHandleCookies completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, NSURL *imageURL) {
                if (!error && [imageURL isEqual:targetURL]) {
                // fade in animation
                    [UIView animateWithDuration:0.25 animations:^{
                        cell.photoView.opaque = YES;
                        cell.photoView.alpha = 1.0;
                    }];
                // or flip animation
//                    [UIView transitionWithView:cell duration:0.5 options:UIViewAnimationOptionCurveEaseInOut|UIViewAnimationOptionTransitionFlipFromBottom animations:^{
//                        cell.photoView.opaque = YES;
//                        cell.photoView.alpha = 1.0;
//                    } completion:^(BOOL finished) {
//                    }];
                }
            }];
        }
    }
}

- (void)loadImageForVisibleCells
{
    NSArray *cells = [self.tableView visibleCells];
    for (GLImageCell *cell in cells) {
        NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
        [self setupCell:cell withIndexPath:indexPath];
    }
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    self.targetRect = nil;
    [self loadImageForVisibleCells];
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset
{
    CGRect targetRect = CGRectMake(targetContentOffset->x, targetContentOffset->y, scrollView.frame.size.width, scrollView.frame.size.height);
    self.targetRect = [NSValue valueWithCGRect:targetRect];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    self.targetRect = nil;
    [self loadImageForVisibleCells];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    
}
@end
