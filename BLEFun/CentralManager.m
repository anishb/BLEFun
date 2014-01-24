//
//  CentralManager.m
//  BluetoothCentral
//
//  Created by Anish Basu on 1/14/14.
//  Copyright (c) 2014 Anish Basu. All rights reserved.
//

#import "CentralManager.h"
@import CoreBluetooth;
#import "CBUUID+StringExtraction.h"

@interface CentralManager() <CBCentralManagerDelegate, CBPeripheralDelegate>
@property (nonatomic, strong) CBCentralManager *centralManager;
// Dictionary of peripheral CBUUID to discovered CBPeripherals
@property (nonatomic, strong) NSMutableDictionary *discoveredPeripherals;
// Dictionary of service CBUUIDs to NSArray of characteristic CBUUIDs
@property (nonatomic, strong) NSMutableDictionary *scanDictionary;
// Dictionary of characteristic CBUIID keys to UpdateBlocks
@property (nonatomic, strong) NSMutableDictionary *updateBlocks;
@end

@implementation CentralManager

@synthesize centralManager = _centralManager;
@synthesize discoveredPeripherals = _discoveredPeripherals;
@synthesize scanDictionary = _scanDictionary;
@synthesize updateBlocks = _updateBlocks;

- (id)init
{
	self = [super init];
	if (self) {
		self.discoveredPeripherals = [[NSMutableDictionary alloc] init];
		self.scanDictionary = [[NSMutableDictionary alloc] init];
		self.updateBlocks = [[NSMutableDictionary alloc] init];
	}
	
	return self;
}


+ (CentralManager *)default
{
	static dispatch_once_t pred = 0;
    __strong static CentralManager *_manager = nil;
    dispatch_once(&pred, ^{
        _manager = [[self alloc] init];
    });
    return _manager;
}

- (void)start
{
	NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], CBCentralManagerOptionShowPowerAlertKey, nil];
	dispatch_queue_t backgroundQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
	self.centralManager = [[CBCentralManager alloc] initWithDelegate:self
															   queue:backgroundQueue
															 options:options];
}

- (NSString *)notificationNameForCharacteristic:(NSString *)UUID
{
	return [NSString stringWithFormat:@"CHARACTERISTIC_UPDATE_%@", UUID];
}

- (NSString *)UUIDForNotificationName:(NSString *)notificationName
{
	NSArray *components = [notificationName componentsSeparatedByString:@"_"];
	return [components lastObject];
}

- (void)subscribeForCharacteristic:(NSString *)characteristicUUID
						 inService:(NSString *)serviceUUID
						usingBlock:(UpdateBlock)updateBlock
{
	// First add characteristic UUID to scanDictionary
	NSArray *uuids = (NSArray *)[self.scanDictionary objectForKey:[CBUUID UUIDWithString:serviceUUID]];
	if (uuids == nil) {
		uuids = [NSArray arrayWithObject:[CBUUID UUIDWithString:characteristicUUID]];
		[self.scanDictionary setObject:uuids forKey:[CBUUID UUIDWithString:serviceUUID]];
	} else if (![uuids containsObject:[CBUUID UUIDWithString:characteristicUUID]]) {
		NSMutableArray *newUUIDs = [uuids mutableCopy];
		[newUUIDs addObject:[CBUUID UUIDWithString:characteristicUUID]];
		[self.scanDictionary setObject:newUUIDs forKey:[CBUUID UUIDWithString:serviceUUID]];
	}
	
	// Now add updateBlock to updateBlocks
	[self.updateBlocks setObject:updateBlock forKey:[CBUUID UUIDWithString:characteristicUUID]];
}

#pragma mark - CBCentralManagerDelegate

- (void)centralManager:(CBCentralManager *)central
 didDiscoverPeripheral:(CBPeripheral *)peripheral
	 advertisementData:(NSDictionary *)advertisementData
				  RSSI:(NSNumber *)RSSI
{
	NSLog(@"Discovered %@", peripheral.name);
	NSLog(@"Peripheral UUID = %@", [peripheral.identifier UUIDString]);
	NSLog(@"RSSI Strength = %ld decibles", [RSSI longValue]);
	[self.discoveredPeripherals setObject:peripheral forKey:peripheral.identifier];
	peripheral.delegate = self;
	[self.centralManager connectPeripheral:peripheral options:nil];
	
}

- (void)centralManager:(CBCentralManager *)central
  didConnectPeripheral:(CBPeripheral *)peripheral
{
	NSLog(@"Connected to peripheral with UUID %@", [peripheral.identifier UUIDString]);
	[peripheral discoverServices:[self.scanDictionary allKeys]];
}

- (void)centralManager:(CBCentralManager *)central
didDisconnectPeripheral:(CBPeripheral *)peripheral
				 error:(NSError *)error
{
	[self.discoveredPeripherals removeObjectForKey:peripheral.identifier];
	NSLog(@"Disconnected peripheral %@", peripheral.identifier);
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
	NSLog(@"CentralManager state = %d", (int)central.state);
	if(central.state == CBCentralManagerStatePoweredOn)
	{
		[central scanForPeripheralsWithServices:[self.scanDictionary allKeys] options:nil];
	}
}

#pragma mark - CBPeripheralDelegate

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
	for (CBService *service in peripheral.services) {
		NSLog(@"Discovered service with UUID %@", [service.UUID representativeString]);
		NSArray *characteristicUUIDs = [self.scanDictionary objectForKey:service.UUID];
		if (characteristicUUIDs != nil) {
			[peripheral discoverCharacteristics:characteristicUUIDs
									 forService:service];
		}
	}
}

- (void)peripheral:(CBPeripheral *)peripheral
didDiscoverCharacteristicsForService:(CBService *)service
			 error:(NSError *)error
{
	if (error) {
		NSLog(@"Error discovering characteristic: %@", [error localizedDescription]);
	}
	for (CBCharacteristic *characteristic in service.characteristics) {
		NSLog(@"Discovered characteristic with UUID %@", [characteristic.UUID representativeString]);
		[peripheral setNotifyValue:YES forCharacteristic:characteristic];
	}
	
}

- (void)peripheral:(CBPeripheral *)peripheral
didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic
			 error:(NSError *)error
{
	UpdateBlock updateBlock = [self.updateBlocks objectForKey:characteristic.UUID];
	if (error) {
		updateBlock([characteristic.UUID representativeString], nil, error);
	} else {
		NSLog(@"Got characteristic value");
		updateBlock([characteristic.UUID representativeString], characteristic.value, nil);
	}
}

- (void)peripheral:(CBPeripheral *)peripheral
didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic
			 error:(NSError *)error
{
	if (error) {
        NSLog(@"Error changing notification state: %@",
			  [error localizedDescription]);
    } else {
		NSLog(@"Successfully updated notification state for characterstic %@",
			  [characteristic.UUID representativeString]);
	}
}

- (void)peripheral:(CBPeripheral *)peripheral
 didModifyServices:(NSArray *)invalidatedServices
{
	NSLog(@"Invalidated some services");
}


@end
