//
//  NSObject+SimpleKVO.m
//  ExMobi
//
//  Created by achen on 16/7/1.
//
//

#import "NSObject+SimpleKVO.h"
#import <objc/runtime.h>

static const int block_key;

@interface SimpleKVOBlockTarget : NSObject

@property (nonatomic, copy) void (^block)(id newVal);

- (id)initWithBlock:(void (^)(id newValue))block;

@end

@implementation SimpleKVOBlockTarget

- (id)initWithBlock:(void (^)(id newValue))block
{
    self = [super init];
    if (self)
    {
        self.block = block;
    }
    
    return self;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (self.block != nil)
    {
        id oldValue = [change objectForKey:NSKeyValueChangeOldKey];
        if (oldValue == [NSNull null])
        {
            oldValue = nil;
        }
        
        id newValue = [change objectForKey:NSKeyValueChangeNewKey];
        if (newValue == [NSNull null])
        {
            newValue = nil;
        }
        
        if (oldValue == nil && newValue == nil)
        {
            return;
        }
        
        if (oldValue == nil || newValue == nil)
        {
            self.block(newValue);
        }
        // 根据测试发现这里所有的基本类型值都被系统自动转换成了NSXXX,因此可以对其使用isEqual进行比较。
        else if (![oldValue isEqual:newValue])
        {
            self.block(newValue);
        }
    }
}

@end

@implementation NSObject (SimpleKVO)

- (void)addKVOForPath:(NSString *)path withBlock:(void (^)(id newValue))block
{
    if ([path length] <= 0 || block == nil)
    {
        return;
    }
    
    SimpleKVOBlockTarget *target = [[SimpleKVOBlockTarget alloc] initWithBlock:block];
    NSMutableDictionary *dic = [self simpleKVOBlocksLazyLoad];
    NSMutableArray *blockTargetsForPath = dic[path];
    if (!blockTargetsForPath)
    {
        blockTargetsForPath = [NSMutableArray new];
        dic[path] = blockTargetsForPath;
    }
    [blockTargetsForPath addObject:target];
    [self addObserver:target forKeyPath:path options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:NULL];
}

- (void)removeKVOForPath:(NSString *)path
{
    if ([path length] > 0)
    {
        NSMutableDictionary *dic = [self simpleKVOBlocks];
        
        if (dic == nil)
        {
            return;
        }
        
        NSMutableArray *arr = dic[path];
        [arr enumerateObjectsUsingBlock: ^(id obj, NSUInteger idx, BOOL *stop) {
            [self removeObserver:obj forKeyPath:path];
        }];
        
        [dic removeObjectForKey:path];
    }
}

- (void)removeAllKVOs
{
    NSMutableDictionary *dic = [self simpleKVOBlocks];
    
    if (dic == nil)
    {
        return;
    }
    
    [dic enumerateKeysAndObjectsUsingBlock: ^(NSString *key, NSArray *arr, BOOL *stop) {
        [arr enumerateObjectsUsingBlock: ^(id obj, NSUInteger idx, BOOL *stop) {
            [self removeObserver:obj forKeyPath:key];
        }];
    }];
    
    [dic removeAllObjects];
    
    objc_setAssociatedObject(self, &block_key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSMutableDictionary *)simpleKVOBlocksLazyLoad
{
    NSMutableDictionary *targets = objc_getAssociatedObject(self, &block_key);
    
    if (!targets)
    {
        targets = [NSMutableDictionary new];
        objc_setAssociatedObject(self, &block_key, targets, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    
    return targets;
}

- (NSMutableDictionary *)simpleKVOBlocks
{
    return objc_getAssociatedObject(self, &block_key);
}

#ifdef ENABLE_SWIZZ_IN_SIMPLEKVO

+ (void)load
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *selString = @"dealloc";
        NSString *kvoSelString = [@"simpleKVO_" stringByAppendingString:selString];
        Method originalDealloc = class_getInstanceMethod(self, NSSelectorFromString(selString));
        Method kvoDealloc = class_getInstanceMethod(self, NSSelectorFromString(kvoSelString));
        method_exchangeImplementations(originalDealloc, kvoDealloc);
    });
}

- (BOOL)isSimpleKVO
{
    if (objc_getAssociatedObject(self,  &block_key) != nil)
    {
        return YES;
    }
    else
    {
        return NO;
    }
}

- (void)simpleKVO_dealloc
{
    
    if ([self isSimpleKVO])
    {
        [self removeAllKVOs];
    }
    
    [self simpleKVO_dealloc];
}

#endif

@end


