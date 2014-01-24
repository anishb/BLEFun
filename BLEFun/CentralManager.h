//
//  CentralManager.h
//  BluetoothCentral
//
//  Created by Anish Basu on 1/14/14.
//  Copyright (c) 2014 Anish Basu. All rights reserved.
//

#import <Foundation/Foundation.h>

//TODO: Should also have NSError for network related errors
typedef void (^UpdateBlock)(NSString *characteristicUUID, NSData *data, NSError *error);

@interface CentralManager : NSObject

+ (CentralManager *)default;
- (void)subscribeForCharacteristic:(NSString *)characteristicUUID
						  inService:(NSString *)serviceUUID
						 usingBlock:(UpdateBlock)updateBlock;
// Starts scanning for services and characteristics specified
- (void)start;

@end
