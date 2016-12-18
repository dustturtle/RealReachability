//
//  ViewController.m
//  RealReachability
//
//  Created by Dustturtle on 16/1/9.
//  Copyright © 2016 Dustturtle. All rights reserved.
//

#import "ViewController.h"
#import "RealReachability.h"

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
    
    ReachabilityStatus status = [[RealReachability sharedInstance] currentReachabilityStatus];
	
    NSLog(@"Initial reachability status:%@",@(status));
    
    if (status == ReachabilityStatusNotReachable) {
        self.flagLabel.text = @"Network unreachable!";
    }
    
    if (status == ReachabilityStatusViaWiFi) {
        self.flagLabel.text = @"Network wifi! Free!";
    }
    
    if (status == ReachabilityStatusWWAN) {
        self.flagLabel.text = @"Network WWAN! In charge!";
    }
    
    self.alert = [[UIAlertView alloc] initWithTitle:@"RealReachability" message:@"" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (IBAction)testAction:(id)sender
{
    [[RealReachability sharedInstance] reachabilityWithBlock:^(ReachabilityStatus status) {
        switch (status)
        {
            case ReachabilityStatusNotReachable:
            {
                self.alert.message = @"Nothing to do! offlineMode";
                [self.alert show];
                
                break;
            }
                
            case ReachabilityStatusViaWiFi:
            {
                self.alert.message = @"Do what you want! free!";
                [self.alert show];
                
                break;
            }
                
            case ReachabilityStatusWWAN:
            {
                self.alert.message = @"Take care of your money! You are in charge!";
                [self.alert show];
                
                WWANAccessType accessType = [[RealReachability sharedInstance] currentWWANtype];
                if (accessType == WWANType2G)
                {
                    self.flagLabel.text = @"RealReachabilityStatus2G";
                }
                else if (accessType == WWANType3G)
                {
                    self.flagLabel.text = @"RealReachabilityStatus3G";
                }
                else if (accessType == WWANType4G)
                {
                    self.flagLabel.text = @"RealReachabilityStatus4G";
                }
                else
                {
                    self.flagLabel.text = @"Unknown RealReachability WWAN Status, might be iOS6";
                }
                
                break;
            }
                
            default:
                break;
        }
    }];
}

- (void)networkChanged:(NSNotification *)notification
{
    RealReachability *reachability = (RealReachability *)notification.object;
    ReachabilityStatus status = [reachability currentReachabilityStatus];
    ReachabilityStatus previousStatus = [reachability previousReachabilityStatus];
    NSLog(@"networkChanged, currentStatus:%@, previousStatus:%@", @(status), @(previousStatus));
    
    if (status == ReachabilityStatusNotReachable)
    {
        self.flagLabel.text = @"Network unreachable!";
    }
    
    if (status == ReachabilityStatusViaWiFi)
    {
        self.flagLabel.text = @"Network wifi! Free!";
    }
    
    if (status == ReachabilityStatusWWAN)
    {
        self.flagLabel.text = @"Network WWAN! In charge!";
    }
    
    WWANAccessType accessType = [[RealReachability sharedInstance] currentWWANtype];
    
    if (status == ReachabilityStatusWWAN)
    {
        if (accessType == WWANType2G)
        {
            self.flagLabel.text = @"RealReachabilityStatus2G";
        }
        else if (accessType == WWANType3G)
        {
            self.flagLabel.text = @"RealReachabilityStatus3G";
        }
        else if (accessType == WWANType4G)
        {
            self.flagLabel.text = @"RealReachabilityStatus4G";
        }
        else
        {
            self.flagLabel.text = @"Unknown RealReachability WWAN Status, might be iOS6";
        }
    }
}

@end
