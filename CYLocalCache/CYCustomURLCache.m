//
//  CYCustomURLCache.m
//  CYLocalCacheExample
//
//  Created by cheny on 16/1/2.
//  Copyright © 2016年 zhssit. All rights reserved.
//

#import "CYCustomURLCache.h"
#import "Reachability.h"
#import <CommonCrypto/CommonCrypto.h>

// 最大缓存时间 一周
static const NSInteger kDefaultCacheMaxCacheAge = 60 * 60 * 24 * 7; // 1 week

@interface CYCustomURLCache () {
    int curSize;
    float cacheMaxSize;
}

@property (nonatomic, copy) NSString *cachePath;

@end

@implementation CYCustomURLCache

static NSString * const CACHEFOLDER = @"CUSTOMCACHEFOLDER";
static NSString * const DEFAULT_CACHEPROVIDER_FIELD_TIME = @"time";
static NSString * const DEFAULT_CACHEPROVIDER_FIELD_MIMETYPE = @"MIMEType";
static NSString * const DEFAULT_CACHEPROVIDER_FIELD_TEXTENCODINGNAME = @"EncodingName";

- (id)initWithMemoryCapacity:(NSUInteger)memoryCapacity diskCapacity:(NSUInteger)diskCapacity diskPath:(NSString *)path {
    if (self = [super initWithMemoryCapacity:memoryCapacity diskCapacity:diskCapacity diskPath:path]) {
        if (path)
            self.diskPath = path;
        else
            self.diskPath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
        self.responseDictionary = [NSMutableDictionary dictionaryWithCapacity:0];
        cacheMaxSize = diskCapacity;
        // 初始化默认数值，最大缓存时间一周
        _maxCacheAge = kDefaultCacheMaxCacheAge;
    }
    return self;
}

- (NSCachedURLResponse *)cachedResponseForRequest:(NSURLRequest *)request {
    if ([request.HTTPMethod compare:@"GET"] != NSOrderedSame) {
        return [super cachedResponseForRequest:request];
    }
    return [self setupCacheWithRequest:request];
}

- (NSCachedURLResponse *)setupCacheWithRequest:(NSURLRequest *)request {
    NSString *url = request.URL.absoluteString;
    NSString *fileName = [self cacheRequestFileName:url];
    NSString *otherInfoFileName = [self cacheRequestOtherInfoFileName:url];
    NSString *filePath = [self cacheFilePath:fileName];
    NSString *otherInfoPath = [self cacheFilePath:otherInfoFileName];
    NSDate *date = [NSDate date];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:filePath]) {
        BOOL expire = NO;
        NSDictionary *otherInfo = [NSDictionary dictionaryWithContentsOfFile:otherInfoPath];
        // 缓存时间
        NSInteger createTime = [[otherInfo objectForKey:DEFAULT_CACHEPROVIDER_FIELD_TIME] intValue] + self.maxCacheAge;
        // 当前时间
        int currentTime = [[NSDate date] timeIntervalSince1970];
        if (currentTime > createTime) {
            expire = YES;
        }
        
        if (expire == NO) {
            NSLog(@"从缓存中取数据。。。");
            NSData *data = [NSData dataWithContentsOfFile:filePath];
            NSURLResponse *response = [[NSURLResponse alloc] initWithURL:request.URL
                                                                MIMEType:[otherInfo objectForKey:DEFAULT_CACHEPROVIDER_FIELD_MIMETYPE]
                                                   expectedContentLength:data.length
                                                        textEncodingName:[otherInfo objectForKey:DEFAULT_CACHEPROVIDER_FIELD_TEXTENCODINGNAME]];
            NSCachedURLResponse *cachedResponse = [[NSCachedURLResponse alloc] initWithResponse:response data:data];
            return cachedResponse;
        } else {
            NSLog(@"清除缓存数据。");
            [fileManager removeItemAtPath:filePath error:nil];
            [fileManager removeItemAtPath:otherInfoPath error:nil];
        }
    }
    if (![Reachability networkAvailable]) {
        return nil;
    }
    __block NSCachedURLResponse *cachedResponse = nil;
    id boolExsite = [self.responseDictionary objectForKey:url];
    if (boolExsite == nil) {
        //判断是否大于缓存上限
        if (curSize > cacheMaxSize){
            [self clearExpiredCache];
            curSize = [self fileSizeForDir:self.cachePath];
            if (curSize > cacheMaxSize){
                [self deleteCacheFolder];
            }
        }
        
        [self.responseDictionary setValue:[NSNumber numberWithBool:YES] forKey:url];
        [NSURLConnection sendAsynchronousRequest:request
                                           queue:[[NSOperationQueue alloc] init]
                               completionHandler:^(NSURLResponse *response, NSData *data,NSError *error) {
             if (response && data) {
                 [self.responseDictionary removeObjectForKey:url];
                 if (error) {
                     NSLog(@"Error : %@", error);
                     NSLog(@"Not Cached: %@", request.URL.absoluteString);
                     cachedResponse = nil;
                 }
                 NSLog(@"Cache url --- %@ ",url);
                 NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
                                       [NSString stringWithFormat:@"%f", [date timeIntervalSince1970]], DEFAULT_CACHEPROVIDER_FIELD_TIME,
                                       response.MIMEType, DEFAULT_CACHEPROVIDER_FIELD_MIMETYPE,
                                       response.textEncodingName, DEFAULT_CACHEPROVIDER_FIELD_TEXTENCODINGNAME,
                                       nil];
                 [dict writeToFile:otherInfoPath atomically:YES];
                 BOOL result = [data writeToFile:filePath atomically:YES];
                 if (result){
                     int fsize = [self fileSizeForFile:filePath fileManager:[NSFileManager defaultManager]];
                     curSize+=fsize;
                 }
                 cachedResponse = [[NSCachedURLResponse alloc] initWithResponse:response data:data];
             }
         }];
        return cachedResponse;
    }
    return nil;
}

- (void)removeAllCachedResponses {
    [super removeAllCachedResponses];
    [self deleteCacheFolder];
}

- (void)removeCachedResponseForRequest:(NSURLRequest *)request {
    [super removeCachedResponseForRequest:request];
    NSString *url = request.URL.absoluteString;
    NSString *fileName = [self cacheRequestFileName:url];
    NSString *otherInfoFileName = [self cacheRequestOtherInfoFileName:url];
    NSString *filePath = [self cacheFilePath:fileName];
    NSString *otherInfoPath = [self cacheFilePath:otherInfoFileName];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager removeItemAtPath:filePath error:nil];
    [fileManager removeItemAtPath:otherInfoPath error:nil];
}

- (void)deleteCacheFolder {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager removeItemAtPath:self.cachePath error:nil];
}

- (NSString *)cacheFilePath:(NSString *)file {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDir;
    if ([fileManager fileExistsAtPath:self.cachePath isDirectory:&isDir] && isDir) {
        
    } else {
        [fileManager createDirectoryAtPath:self.cachePath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return [NSString stringWithFormat:@"%@/%@", self.cachePath, file];
}

- (NSString *)cacheRequestFileName:(NSString *)requestUrl {
    return [self md5String:requestUrl];
}

- (NSString *)cacheRequestOtherInfoFileName:(NSString *)requestUrl {
    return [self md5String:[NSString stringWithFormat:@"%@-otherInfo", requestUrl]];
}

#pragma mark - HTTPS
- (void)connection:(NSURLConnection *)connection willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    NSLog(@"%@", challenge.protectionSpace);
    static CFArrayRef certs;
    if (!certs) {
        NSData*certData =[NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"srca" ofType:@"cer"]];
        SecCertificateRef rootcert =SecCertificateCreateWithData(kCFAllocatorDefault,CFBridgingRetain(certData));
        const void *array[1] = { rootcert };
        certs = CFArrayCreate(NULL, array, 1, &kCFTypeArrayCallBacks);
        CFRelease(rootcert);
    }
    
    SecTrustRef trust = [[challenge protectionSpace] serverTrust];
    int err;
    SecTrustResultType trustResult = 0;
    err = SecTrustSetAnchorCertificates(trust, certs);
    if (err == noErr) {
        err = SecTrustEvaluate(trust,&trustResult);
    }
    CFRelease(trust);
    BOOL trusted = (err == noErr) && ((trustResult == kSecTrustResultProceed) || (trustResult == kSecTrustResultUnspecified));
    
    if (trusted) {
        [challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge];
    }else{
        [challenge.sender cancelAuthenticationChallenge:challenge];
    }
}

- (void)clearExpiredCache {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSDirectoryEnumerator *direnum = [fileManager enumeratorAtPath:self.cachePath];
    NSMutableArray *files = [NSMutableArray new];
    NSString *filename;
    while (filename = [direnum nextObject]) {
        if ([[filename pathExtension] isEqualToString:@""]) {
            [files addObject: filename];
        }
    }
    for (NSString *filePath in files) {
        NSMutableDictionary * data = [[NSMutableDictionary alloc] initWithContentsOfFile:filePath];
        int currentTime = [[NSDate date] timeIntervalSince1970];
        int expireTime = [[data objectForKey:DEFAULT_CACHEPROVIDER_FIELD_TIME] intValue];
        if (currentTime > expireTime){
            [fileManager removeItemAtPath:filePath error:nil];
        }
    }
    curSize = [self fileSizeForDir:self.cachePath];
    NSLog(@"Expired Cached Deleted, current size: %.2fM",curSize/1024.0/1024.0);
}

- (float)fileSizeForDir:(NSString*)path {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    float size =0;
    NSArray* array = [fileManager contentsOfDirectoryAtPath:path error:nil];
    for(int i = 0; i<[array count]; i++){
        NSString *fullPath = [path stringByAppendingPathComponent:[array objectAtIndex:i]];
        BOOL isDir;
        if ( !([fileManager fileExistsAtPath:fullPath isDirectory:&isDir] && isDir) ){
            size+=[self fileSizeForFile:fullPath fileManager:fileManager];
        }
        else{
            [self fileSizeForDir:fullPath];
        }
    }
    return size;
}

- (float)fileSizeForFile:(NSString*)path fileManager:(NSFileManager *)fileManager {
    if ([fileManager fileExistsAtPath:path]){
        NSDictionary *fileAttributeDic=[fileManager attributesOfItemAtPath:path error:nil];
        return fileAttributeDic.fileSize;
    }
    return 0;
}


- (NSString *)cachePath {
    return [NSString stringWithFormat:@"%@/%@", self.diskPath, CACHEFOLDER];
}

#pragma mark - 加密相关
- (NSString *)md5String:(NSString *)input {
    const char *str = input.UTF8String;
    uint8_t buffer[CC_MD5_DIGEST_LENGTH];
    
    CC_MD5(str, (CC_LONG)strlen(str), buffer);
    
    return [self stringFromBytes:buffer length:CC_MD5_DIGEST_LENGTH];
}

/**
 *  返回二进制 Bytes 流的字符串表示形式
 *
 *  @param bytes  二进制 Bytes 数组
 *  @param length 数组长度
 *
 *  @return 字符串表示形式
 */
- (NSString *)stringFromBytes:(uint8_t *)bytes length:(int)length {
    NSMutableString *strM = [NSMutableString string];
    for (int i = 0; i < length; i++) {
        [strM appendFormat:@"%02x", bytes[i]];
    }
    return [strM copy];
}

@end
