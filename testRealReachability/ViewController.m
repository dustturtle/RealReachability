//
//  ViewController.m
//  RealReachability
//
//  Created by Dustturtle on 16/1/9.
//  Copyright © 2016 QCStudio. All rights reserved.
//

#import "ViewController.h"
#import "LocalConnection.h"

#import "RealReachability.h"

#import "PingHelper.h"

@interface ViewController ()

@property (weak, nonatomic) IBOutlet UILabel *flagLabel;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    [GLobalRealReachability startNotifier];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(networkChanged:)
                                                 name:kRealReachabilityChangedNotification
                                               object:nil];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)networkChanged:(NSNotification *)notification
{
    RealReachability *rr = (RealReachability *)notification.object;
    ReachabilityStatus status = [rr currentReachabilityStatus];
    NSLog(@"%@",@(status));
    
    if (status == NotReachable)
    {
        self.flagLabel.text = @"Network unreachable!";
    }
    
    if (status == ReachableViaWiFi)
    {
        self.flagLabel.text = @"Network wifi! free!";
    }
    
    if (status == ReachableViaWWAN)
    {
        self.flagLabel.text = @"Network WWAN! take care of the charge!";
    }
    
}
@end
