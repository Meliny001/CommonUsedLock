//
//  ViewController.m
//  Lock
//
//  Created by Magic on 2018/4/11.
//  Copyright © 2018年 magic. All rights reserved.
//
/*
 
 */

#import "ViewController.h"
#import <pthread.h>

@interface ViewController ()
@property (nonatomic,strong) dispatch_queue_t queue;
@end

static inline dispatch_queue_t ZGLockQueue()
{
    return dispatch_queue_create("Lock queue", DISPATCH_QUEUE_CONCURRENT);
}

@implementation ViewController
{
    pthread_mutex_t _lockRecursive;
    pthread_mutex_t _mutexLock;
    int ticketCount;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self initPthread_Mutex_lock_recursive];
    pthread_mutex_init(&_mutexLock, NULL);
}
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [self mockSaleTicket];
}

#pragma mark - 模拟卖票
- (void)mockSaleTicket
{
    ticketCount = 10;
    dispatch_async(ZGLockQueue(), ^{
        [self saleTickets];
    });
    dispatch_async(ZGLockQueue(), ^{
        [self saleTickets];
    });
    dispatch_async(ZGLockQueue(), ^{
        [self saleTickets];
    });
    
}
- (void)saleTickets
{
    NSLock * _lock = [[NSLock alloc] init];// NSLock打开多次点击模拟多次出现异常
    while (1) {
        pthread_mutex_lock(&_mutexLock);
        //[_lock lock];
        if (ticketCount>0) {
            ticketCount --;
            NSLog(@"卖掉一张票还有%d张-%@",ticketCount,[NSThread currentThread]);
        }else
        {
            NSLog(@"已售罄");
            pthread_mutex_unlock(&_mutexLock);
            //[_lock lock];
            break;
        }
        pthread_mutex_unlock(&_mutexLock);
        //[_lock unlock];
    }
    
}

#pragma mark -条件锁
- (void)testConditionLock
{
    // 条件锁
    NSConditionLock * _lock = [[NSConditionLock alloc] init];
    static NSInteger condition = 2;
    dispatch_async(ZGLockQueue(), ^{
        for (int i =0;i <= 3; i++) {
            [_lock lock];
            NSLog(@"Thread1:%d-%@",i,[NSThread currentThread]);
            sleep(1);
            [_lock unlockWithCondition:i];
            // 需要主动调用_lock.condition 才执行
            if (condition == _lock.condition) NSLog(@"Thread 2 will start");
        }
    });
    dispatch_async(ZGLockQueue(), ^{
        [_lock lockWhenCondition:condition];
        NSLog(@"Thread2 start");
        [_lock unlock];
    });
}

#pragma mark - 递归解决循环死锁
- (void)testRecursiveLock
{
    //创建锁
    NSLock * _lock = [[NSLock alloc]init];
//    NSRecursiveLock * _lock = [[NSRecursiveLock alloc] init];
    
    dispatch_async(ZGLockQueue(), ^{
        static void(^TestMethod)(int);
        TestMethod = ^(int value)
        {
            [_lock lock];
            if (value > 0)
            {
                NSLog(@"value:%d",value);
                [NSThread sleepForTimeInterval:1];
                value -= 1;
                //[_lock unlock]; // NSLock时打开试试(如果注释掉 则会造成死锁-可以使用NSRecursiveLock递归锁解决)
                TestMethod(value);
            }
            [_lock unlock];
        };
        
        TestMethod(5);
    });
}

// 推荐使用
- (void)testPthred_mutex_lockRecursive
{
    dispatch_async(ZGLockQueue(), ^{
        static void(^TestMethod)(int);
        TestMethod = ^(int value)
        {
            pthread_mutex_lock(&_lockRecursive);
            if (value > 0)
            {
                NSLog(@"value:%d",value);
                [NSThread sleepForTimeInterval:1];
                value -= 1;
                TestMethod(value);
            }
            pthread_mutex_unlock(&_lockRecursive);
        };
        
        TestMethod(5);
    });
}

- (void)initPthread_Mutex_lock_recursive
{
    // 适用于内存处理
    pthread_mutexattr_t attr;
    pthread_mutexattr_init (&attr);
    pthread_mutexattr_settype (&attr, PTHREAD_MUTEX_RECURSIVE);
    pthread_mutex_init (&_lockRecursive, &attr);
    pthread_mutexattr_destroy (&attr);
}

#pragma mark - 信号量
- (void)testDispatch_semaphore
{
    // 等待时不会消耗CPU资源,适用于磁盘存储,无等待时性能高于pthread_mutex,等待时性能下降很快
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(1);
    dispatch_async(ZGLockQueue(), ^{
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
        NSLog(@"Thread 1");
        sleep(3);
        dispatch_semaphore_signal(semaphore);
    });
    
    dispatch_async(ZGLockQueue(), ^{
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
        NSLog(@"Thread 2");
        dispatch_semaphore_signal(semaphore);
    });
}

@end
