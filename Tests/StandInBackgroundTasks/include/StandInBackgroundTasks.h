#if __APPLE__
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// A task with the two members of `BGTask` in `BGTask.h`, under the Swift names `BackgroundTasks.apinotes` gives
/// them, and no isolation annotations.
@interface StandInTask : NSObject
@property (nullable, strong) void (^expirationHandler)(void);
- (void)setTaskCompletedWithSuccess:(BOOL)success NS_SWIFT_NAME(setTaskCompleted(success:));
@end

/// A scheduler whose registration method has the declaration of `BGTaskScheduler`'s in `BGTaskScheduler.h`: an
/// unannotated block parameter.
@interface StandInScheduler : NSObject
- (BOOL)registerForTaskWithIdentifier:(NSString *)identifier
                           usingQueue:(nullable dispatch_queue_t)queue
                        launchHandler:(void (^)(__kindof StandInTask *task))launchHandler
    NS_SWIFT_NAME(register(forTaskWithIdentifier:using:launchHandler:));

/// Calls the registered launch handler on a global queue, then the expiration handler it set on another, and returns
/// when both have returned.
- (void)wakeOffTheMainThread;
@end

NS_ASSUME_NONNULL_END
#endif
