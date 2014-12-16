#import "JXOperation.h"

@interface JXOperation ()

@property (assign) BOOL isExecuting;
@property (assign) BOOL isFinished;

#if OS_OBJECT_USE_OBJC
@property (strong) dispatch_queue_t stateQueue;
#else
@property (assign) dispatch_queue_t stateQueue;
#endif

#if __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_4_0
@property (assign) UIBackgroundTaskIdentifier backgroundTaskID;
#endif

@end

@implementation JXOperation

#pragma mark - Initialization

- (void)dealloc
{
    #if !OS_OBJECT_USE_OBJC
    dispatch_release(_stateQueue);
    _stateQueue = NULL;
    #endif
}

- (instancetype)init
{
    if (self = [super init]) {
        NSString *queueName = [[NSString alloc] initWithFormat:@"%@.%p.state", NSStringFromClass([self class]), self];
        self.stateQueue = dispatch_queue_create([queueName UTF8String], DISPATCH_QUEUE_SERIAL);

        self.isExecuting = NO;
        self.isFinished = NO;
        
        #if __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_4_0
        self.backgroundTaskID = UIBackgroundTaskInvalid;
        #endif
    }
    return self;
}

#pragma mark - NSOperation

- (void)start
{
    __block BOOL shouldStart = YES;
    
    dispatch_sync(self.stateQueue, ^{
        if ([self isCancelled] || ![self isReady] || self.isExecuting || self.isFinished) {
            shouldStart = NO;
        } else {
            [self willChangeValueForKey:@"isExecuting"];
            self.isExecuting = YES;
            [self didChangeValueForKey:@"isExecuting"];
        }
    });
    
    if (!shouldStart)
        return;

    @autoreleasepool {
        [self main];
    }
}

#pragma mark - Public Methods

- (BOOL)isConcurrent
{
    return YES;
}

- (void)cancel
{
    [super cancel];

    [self finish];
}

- (void)willFinish
{

}

- (void)finish
{
    dispatch_sync(self.stateQueue, ^{
        if (self.isFinished)
            return;

        [self willFinish];

        if (self.isExecuting) {
            [self willChangeValueForKey:@"isExecuting"];
            [self willChangeValueForKey:@"isFinished"];
            self.isExecuting = NO;
            self.isFinished = YES;
            [self didChangeValueForKey:@"isExecuting"];
            [self didChangeValueForKey:@"isFinished"];
        } else if (!self.isFinished) {
            self.isExecuting = NO;
            self.isFinished = YES;
        }
    });
}

- (void)startAndWaitUntilFinished
{
    NSOperationQueue *tempQueue = [[NSOperationQueue alloc] init];
    [tempQueue addOperation:self];
    [tempQueue waitUntilAllOperationsAreFinished];
}

@end
