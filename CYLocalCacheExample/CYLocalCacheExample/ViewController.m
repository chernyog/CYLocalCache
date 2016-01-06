//
//  ViewController.m
//  CYLocalCacheExample
//
//  Created by cheny on 16/1/2.
//  Copyright © 2016年 zhssit. All rights reserved.
//

#import "ViewController.h"
#import "CYCustomURLCache.h"
#import "MBProgressHUD+MJ.h"

@interface ViewController ()

@property (weak, nonatomic) IBOutlet UIWebView *webView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    CYCustomURLCache *urlCache = [[CYCustomURLCache alloc] initWithMemoryCapacity:20 * 1024 * 1024
                                                                 diskCapacity:20 * 1024 * 1024
                                                                     diskPath:nil];
    [CYCustomURLCache setSharedURLCache:urlCache];
    
    NSString *urlStr = @"https://www.baidu.com";
    [self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString: urlStr]]];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    
    CYCustomURLCache *urlCache = (CYCustomURLCache *)[NSURLCache sharedURLCache];
    [urlCache removeAllCachedResponses];
}

#pragma mark - <WebViewDelegate>
- (void)webViewDidFinishLoad:(UIWebView *)webView {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
}

- (void)webViewDidStartLoad:(UIWebView *)webView {
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.mode = MBProgressHUDModeIndeterminate;
    hud.labelText = @"Loading...";
}


@end
