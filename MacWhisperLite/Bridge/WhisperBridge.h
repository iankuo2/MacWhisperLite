//
//  WhisperBridge.h
//  MacWhisperLite
//
//  Created by ian kuo on 2026-07-11.
//

#ifndef WhisperBridge_h
#define WhisperBridge_h


#endif /* WhisperBridge_h */
#import <Foundation/Foundation.h>

@interface WhisperBridge : NSObject

- (instancetype _Nullable)initWithModelPath:(NSString * _Nonnull)modelPath;
- (NSString * _Nullable)transcribePCMBuffer:(float * _Nonnull)buffer samples:(int)samples;
- (void)dealloc;

@end
