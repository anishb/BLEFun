//
//  PeripheralManager.m
//  BluetoothPeripheral
//
//  Created by Anish Basu on 1/14/14.
//  Copyright (c) 2014 Anish Basu. All rights reserved.
//

#import "PeripheralManager.h"
#import "CBUUID+StringExtraction.h"
@import CoreBluetooth;

@interface PeripheralManager () <CBPeripheralManagerDelegate>
@property (nonatomic, strong) CBPeripheralManager *peripheralManager;
// Dictionary of service UUID to array of CBMutableCharacteristics
@property (nonatomic, strong) NSMutableDictionary *characteristicsAdvertised;
// Dictionary of characterstic UUID to CBMutableCharacteristic
@property (nonatomic, strong) NSMutableDictionary *characteristics;
@property (nonatomic) BOOL started;
@end

@implementation PeripheralManager

@synthesize peripheralManager = _peripheralManager;
@synthesize characteristicsAdvertised = _characteristicsAdvertised;
@synthesize characteristics = _characteristics;
@synthesize dataSource = _dataSource;
@synthesize started = _started;

- (id)init
{
	self = [super init];
	if (self) {
		_characteristicsAdvertised = [[NSMutableDictionary alloc] init];
		_characteristics = [[NSMutableDictionary alloc] init];
		_started = NO;
	}
	return self;
}

+ (PeripheralManager *)default
{
	static dispatch_once_t pred = 0;
    __strong static PeripheralManager *_manager = nil;
    dispatch_once(&pred, ^{
        _manager = [[self alloc] init];
    });
    return _manager;
}

- (void)addCharacteristic:(NSString *)characteristicUUID
			   forService:(NSString *)serviceUUID
{
	if (self.started) {
		return;
	}
	CBUUID *serviceCBUUID = [CBUUID UUIDWithString:serviceUUID];
	CBMutableCharacteristic *characteristic = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:characteristicUUID]
																				 properties:CBCharacteristicPropertyRead | CBCharacteristicPropertyNotify
																					  value:nil
																				permissions:CBAttributePermissionsReadable];
	NSArray *existing = [self.characteristicsAdvertised objectForKey:serviceCBUUID];
	if (existing == nil) {
		[self.characteristicsAdvertised setObject:[NSArray arrayWithObject:characteristic] forKey:serviceCBUUID];
	} else {
		NSMutableArray *newCharacteristics = [NSMutableArray arrayWithArray:existing];
		[newCharacteristics addObject:characteristic];
		[self.characteristicsAdvertised setObject:newCharacteristics forKey:serviceCBUUID];
	}
	[self.characteristics setObject:characteristic forKey:characteristic.UUID];
}

- (void)start
{
	if (!self.started) {
		dispatch_queue_t backgroundQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
		NSDictionary *options = @{CBPeripheralManagerOptionShowPowerAlertKey: [NSNumber numberWithBool:YES]};
		self.peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self
																		 queue:backgroundQueue
																	   options:options];
	}
}

- (void)updateSubscribedCentrals
{
	for (CBMutableCharacteristic *characteristic in [self.characteristics allValues]) {
		NSData *value;
		if ([self.dataSource respondsToSelector:@selector(valueForCharacteristic:)]) {
			value = [self.dataSource valueForCharacteristic:[characteristic.UUID representativeString]];
		}
		if (value) {
			BOOL didSendValue = [self.peripheralManager updateValue:value
												  forCharacteristic:characteristic
											   onSubscribedCentrals:nil];
			if (didSendValue) {
				NSLog(@"Did send value to subscribed central");
			}
		}
	}
}

#pragma mark - CBPeripheralManagerDelegate

- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral
{
	NSLog(@"Current peripheral state = %ld", peripheral.state);
	if (peripheral.state == CBPeripheralManagerStatePoweredOn) {
		for (CBUUID *serviceUUID in self.characteristicsAdvertised) {
			CBMutableService *service = [[CBMutableService alloc] initWithType:serviceUUID primary:YES];
			service.characteristics = [self.characteristicsAdvertised objectForKey:serviceUUID];
			[self.peripheralManager addService:service];
		}
		
		// Advertise services
		//TODO: CBAdvertisementDataLocalNameKey can have peripheral name as NSString value. Perhaps
		//		we can put the 3rd party identifier in here. Could help with ad tracking?
		[_peripheralManager startAdvertising:@{CBAdvertisementDataServiceUUIDsKey : [_characteristicsAdvertised allKeys]}];
	}
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral
			didAddService:(CBService *)service
					error:(NSError *)error
{
	if (error) {
		NSLog(@"Error publishing service: %@", [error localizedDescription]);
	} else {
		NSLog(@"Service with UUID %@ added.", [service.UUID representativeString]);
	}
}

- (void)peripheralManagerDidStartAdvertising:(CBPeripheralManager *)peripheral
									   error:(NSError *)error
{
	if (error) {
		NSLog(@"Error advertising: %@", [error localizedDescription]);
	} else {
		NSLog(@"Started advertising");
	}
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral
	didReceiveReadRequest:(CBATTRequest *)request
{
	NSLog(@"Did receive read request");
	NSData *value;
	if ([self.dataSource respondsToSelector:@selector(valueForCharacteristic:)]) {
		value = [self.dataSource valueForCharacteristic:[request.characteristic.UUID representativeString]];
	}
	if (!value) {
		[peripheral respondToRequest:request withResult:CBATTErrorAttributeNotFound];
		return;
	}
	
	if (request.offset > value.length) {
		[peripheral respondToRequest:request withResult:CBATTErrorInvalidOffset];
		return;
	}
	request.value = [value subdataWithRange:NSMakeRange(request.offset, value.length - request.offset)];
	[peripheral respondToRequest:request withResult:CBATTErrorSuccess];
}


- (void)peripheralManager:(CBPeripheralManager *)peripheral
                  central:(CBCentral *)central
didSubscribeToCharacteristic:(CBCharacteristic *)characteristic {
	NSLog(@"Central subscribed to characteristic %@", [characteristic.UUID representativeString]);
	NSData *value;
	if ([self.dataSource respondsToSelector:@selector(valueForCharacteristic:)]) {
		value = [self.dataSource valueForCharacteristic:[characteristic.UUID representativeString]];
	}
	if (value) {
		BOOL didSendValue = [peripheral updateValue:value
								  forCharacteristic:[self.characteristics objectForKey:characteristic.UUID]
							   onSubscribedCentrals:nil];
		if (didSendValue) {
			NSLog(@"Did send value to subscribed central");
		}
	}
}

@end