//
//  ViewController.m
//  RealReachability
//
//  Created by Dustturtle on 16/1/9.
//  Copyright © 2016 Dustturtle. All rights reserved.
//

#import "ViewController.h"
#import "RealReachability.h"
#import "NSObject+SimpleKVO.h"

@interface ViewController ()

@property (nonatomic, weak) IBOutlet UILabel *flagLabel;

@property (nonatomic, strong) UIAlertView *alert;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(networkChanged:)
                                                 name:kRealReachabilityChangedNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(VPNStatusChanged:)
                                                 name:kRRVPNStatusChangedNotification
                                               object:nil];
    
    ReachabilityStatus status = [GLobalRealReachability currentReachabilityStatus];
    NSLog(@"Initial reachability status:%@",@(status));
    
    [self setupFlagLabelWithStatus:status
                           isVPNOn:[GLobalRealReachability isVPNOn]
                        accessType:[GLobalRealReachability currentWWANtype]];
    
    self.alert = [[UIAlertView alloc] initWithTitle:@"RealReachability" message:@"" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (IBAction)testAction:(id)sender
{
//    NSLog(@"begin");
//    // performance test of this method; ok.
//    for (NSInteger i=0; i<10000; i++)
//    {
//        [GLobalRealReachability isVPNOn];
//    }
//    NSLog(@"end");
    
    [GLobalRealReachability reachabilityWithBlock:^(ReachabilityStatus status) {
        switch (status)
        {
            case RealStatusNotReachable:
            {
                self.alert.message = @"Nothing to do! offlineMode";
                [self.alert show];
                
                break;
            }
                
            case RealStatusViaWiFi:
            {
                self.alert.message = @"Do what you want! free!";
                [self.alert show];
                
                break;
            }
                
            case RealStatusViaWWAN:
            {
                self.alert.message = @"Take care of your money! You are in charge!";
                break;
            }
                
            default:
            {
                self.alert.message = @"Error status, needs debugging!";
                break;
            }
        }
        
        [self.alert show];
    }];
}

- (void)networkChanged:(NSNotification *)notification
{
    RealReachability *reachability = (RealReachability *)notification.object;
    ReachabilityStatus status = [reachability currentReachabilityStatus];
    ReachabilityStatus previousStatus = [reachability previousReachabilityStatus];
    NSLog(@"networkChanged, currentStatus:%@, previousStatus:%@", @(status), @(previousStatus));
    
    [self setupFlagLabelWithStatus:status
                           isVPNOn:[GLobalRealReachability isVPNOn]
                        accessType:[GLobalRealReachability currentWWANtype]];
}

- (void)VPNStatusChanged:(NSNotification *)notification
{
    // refreshing the status.
    [self setupFlagLabelWithStatus:[GLobalRealReachability currentReachabilityStatus]
                           isVPNOn:[GLobalRealReachability isVPNOn]
                        accessType:[GLobalRealReachability currentWWANtype]];
}

- (void)setupFlagLabelWithStatus:(ReachabilityStatus)status
                         isVPNOn:(BOOL)isVPNOn
                      accessType:(WWANAccessType)accessType
{
    NSMutableString *labelStr = [@"" mutableCopy];
    
    switch (status)
    {
        case RealStatusNotReachable:
        {
            [labelStr appendString:@"Network unreachable! "];
            break;
        }
            
        case RealStatusViaWiFi:
        {
            [labelStr appendString:@"Network wifi! Free! "];
            break;
        }
            
        case RealStatusViaWWAN:
        {
            [labelStr appendString:@"WWAN in charge! "];
            break;
        }
            
        case RealStatusUnknown:
        {
            [labelStr appendString:@"Unknown status! Needs debugging! "];
            break;
        }
            
        default:
        {
            [labelStr appendString:@"Status error! Needs debugging! "];
            break;
        }
    }
    
    if (isVPNOn)
    {
        [labelStr appendString:@"VPN On! "];
    }
    
    if (status == RealStatusViaWWAN)
    {
        NSString *descStr;
        if (accessType == WWANType2G)
        {
            descStr = @"2G";
        }
        else if (accessType == WWANType3G)
        {
            descStr = @"3G";
        }
        else if (accessType == WWANType4G)
        {
            descStr = @"4G";
        }
        else
        {
            descStr = @"Unknown Status, might be iOS6";
        }

        [labelStr appendString:descStr];
    }
    
    self.flagLabel.text = [labelStr copy];
}

@end
