#if __APPLE__
#import "StandInBackgroundTasks.h"

@implementation StandInTask
- (void)setTaskCompletedWithSuccess:(BOOL)success {
}
@end

@implementation StandInScheduler {
  void (^_launchHandler)(StandInTask *);
}

- (BOOL)registerForTaskWithIdentifier:(NSString *)identifier
                           usingQueue:(dispatch_queue_t)queue
                        launchHandler:(void (^)(__kindof StandInTask *))launchHandler {
  _launchHandler = [launchHandler copy];
  return YES;
}

- (void)wakeOffTheMainThread {
  StandInTask *task = [StandInTask new];
  void (^launchHandler)(StandInTask *) = _launchHandler;
  dispatch_semaphore_t returned = dispatch_semaphore_create(0);
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
    launchHandler(task);
    dispatch_semaphore_signal(returned);
  });
  dispatch_semaphore_wait(returned, DISPATCH_TIME_FOREVER);
  void (^expirationHandler)(void) = task.expirationHandler;
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
    if (expirationHandler) {
      expirationHandler();
    }
    dispatch_semaphore_signal(returned);
  });
  dispatch_semaphore_wait(returned, DISPATCH_TIME_FOREVER);
}
@end
#endif
