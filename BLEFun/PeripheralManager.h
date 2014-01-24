//
//  PeripheralManager.h
//  BluetoothPeripheral
//
//  Created by Anish Basu on 1/14/14.
//  Copyright (c) 2014 Anish Basu. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol CharacteristicDataSource <NSObject>
- (NSData *)valueForCharacteristic:(NSString *)characteristicUUID;
@end

@interface PeripheralManager : NSObject

@property (nonatomic, weak) id<CharacteristicDataSource> dataSource;

+ (PeripheralManager *)default;
- (void)addCharacteristic:(NSString *)characteristicUUID
			   forService:(NSString *)serviceUUID;
- (void)start;
- (void)updateSubscribedCentrals;

@end
