//
//  CYCustomURLCache.h
//  CYLocalCacheExample
//
//  Created by cheny on 16/1/2.
//  Copyright © 2016年 zhssit. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CYCustomURLCache : NSURLCache

@property (nonatomic, retain) NSString *diskPath;
@property (nonatomic, retain) NSMutableDictionary *responseDictionary;

/**
 * The maximum length of time to keep an image in the cache, in seconds
 * <br />缓存图像最长时间，以秒为单位，默认一周
 */
@property (assign, nonatomic) NSInteger maxCacheAge;

- (id)initWithMemoryCapacity:(NSUInteger)memoryCapacity diskCapacity:(NSUInteger)diskCapacity diskPath:(NSString *)path;

@end
