//
//  ReceiverViewController.m
//  BLEFun
//
//  Created by Anish Basu on 1/24/14.
//  Copyright (c) 2014 Anish Basu. All rights reserved.
//

#import "ReceiverViewController.h"
#import "CentralManager.h"
#import "AppDelegate.h"

@interface ReceiverViewController ()

@end

@implementation ReceiverViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
	CentralManager *manager = [CentralManager default];
	__weak ReceiverViewController *weakSelf = self;
	[manager subscribeForCharacteristic:CHARACTERISTIC_UUID
							  inService:SERVICE_UUID
							 usingBlock:^(NSString *characteristicUUID, NSData *data, NSError *error) {
								 dispatch_async(dispatch_get_main_queue(), ^{
									 if (error) {
										 NSLog(@"Error receiving background color from remote controller: %@", [error localizedDescription]);
									 } else if (data != nil) {
										 NSLog(@"Received %lu bytes.", (unsigned long)[data length]);
										 unsigned int colorIndex;
										 [data getBytes:&colorIndex length:sizeof(colorIndex)];
										 NSLog(@"Color index = %u", colorIndex);
										 UIColor *backgroundColor;
										 switch (colorIndex) {
											 case 0:
												 backgroundColor = [UIColor redColor];
												 break;
											 case 1:
												 backgroundColor = [UIColor greenColor];
												 break;
											 case 2:
												 backgroundColor = [UIColor blueColor];
												 break;
											 default:
												 break;
										 }
										 weakSelf.view.backgroundColor = backgroundColor;
									 }
								 });
							 }];
	[manager start];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
