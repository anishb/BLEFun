//
//  RemoteControllerViewController.m
//  BLEFun
//
//  Created by Anish Basu on 1/24/14.
//  Copyright (c) 2014 Anish Basu. All rights reserved.
//

#import "RemoteControllerViewController.h"
#import "PeripheralManager.h"
#import "AppDelegate.h"

@interface RemoteControllerViewController () <CharacteristicDataSource>
@property (nonatomic, weak) IBOutlet UISegmentedControl *colorPicker;
@end

@implementation RemoteControllerViewController

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
	PeripheralManager *manager = [PeripheralManager default];
	manager.dataSource = self;
	[manager addCharacteristic:CHARACTERISTIC_UUID
					forService:SERVICE_UUID];
	[manager start];
}

- (IBAction)updateColor:(id)sender
{
	[[PeripheralManager default] updateSubscribedCentrals];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - CharacteristicDataSource

- (NSData *)valueForCharacteristic:(NSString *)characteristicUUID
{
	unsigned int colorIndex = (unsigned int)self.colorPicker.selectedSegmentIndex;
	NSData *data = [NSData dataWithBytes:&colorIndex
								  length:sizeof(colorIndex)];
	return data;
}

@end
