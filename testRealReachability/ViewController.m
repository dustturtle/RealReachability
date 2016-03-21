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

@property (weak, nonatomic) IBOutlet UILabel *flagLabel;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(networkChanged:)
                                                 name:kRealReachabilityChangedNotification
                                               object:nil];
    
    ReachabilityStatus status = [GLobalRealReachability currentReachabilityStatus];
    NSLog(@"Initial reachability status:%@",@(status));
    
    if (status == RealStatusNotReachable)
    {
        self.flagLabel.text = @"Network unreachable!";
    }
    
    if (status == RealStatusViaWiFi)
    {
        self.flagLabel.text = @"Network wifi! Free!";
    }
    
    if (status == RealStatusViaWWAN)
    {
        self.flagLabel.text = @"Network WWAN! In charge!";
    }
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (IBAction)testAction:(id)sender
{
    [GLobalRealReachability reachabilityWithBlock:^(ReachabilityStatus status) {
        switch (status)
        {
            case RealStatusNotReachable:
            {
                [[[UIAlertView alloc] initWithTitle:@"RealReachability" message:@"Nothing to do! offlineMode" delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil , nil] show];
                break;
            }
                
            case RealStatusViaWiFi:
            {
                [[[UIAlertView alloc] initWithTitle:@"RealReachability" message:@"Do what you want! free!" delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil , nil] show];
                break;
            }
                
            case RealStatusViaWWAN:
            {
                [[[UIAlertView alloc] initWithTitle:@"RealReachability" message:@"Take care of your money! You are in charge!" delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil , nil] show];
                
                WWANAccessType accessType = [GLobalRealReachability currentWWANtype];
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
    
    if (status == RealStatusNotReachable)
    {
        self.flagLabel.text = @"Network unreachable!";
    }
    
    if (status == RealStatusViaWiFi)
    {
        self.flagLabel.text = @"Network wifi! Free!";
    }
    
    if (status == RealStatusViaWWAN)
    {
        self.flagLabel.text = @"Network WWAN! In charge!";
    }
    
    WWANAccessType accessType = [GLobalRealReachability currentWWANtype];
    
    if (status == RealStatusViaWWAN)
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
