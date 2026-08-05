//
//  WhisperBridge.mm
//  MacWhisperLite
//
//  Created by ian kuo on 2026-07-11.
//

#import <Foundation/Foundation.h>

#import "WhisperBridge.h"
#import "whisper.h"
#import <vector>

@implementation WhisperBridge {
    struct whisper_context * ctx;
}

- (instancetype _Nullable)initWithModelPath:(NSString * _Nonnull)modelPath {
    self = [super init];
    if (self) {
        // Configure context parameters
        struct whisper_context_params cparams = whisper_context_default_params();
        
        // Initialize the whisper context with the model file
        ctx = whisper_init_from_file_with_params([modelPath UTF8String], cparams);
        
        if (ctx == nullptr) {
            NSLog(@"Failed to initialize Whisper context.");
            return nil;
        }
    }
    return self;
}

- (NSString * _Nullable)transcribePCMBuffer:(float * _Nonnull)buffer samples:(int)samples {
    if (ctx == nullptr) return nil;
    
    // Configure full strategy parameters (greedy sampling by default)
    struct whisper_full_params wparams = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
    
    // Use the number of available processor cores for threading
    wparams.n_threads = (int)[[NSProcessInfo processInfo] processorCount];
    wparams.language = "auto"; // Set language ("auto" for auto-detection)
    
    // Run the transcription
    if (whisper_full(ctx, wparams, buffer, samples) != 0) {
        NSLog(@"Failed to process audio with Whisper.");
        return nil;
    }
    
    // Gather text segments results
    NSMutableString *result = [[NSMutableString alloc] init];
    int n_segments = whisper_full_n_segments(ctx);
    
    for (int i = 0; i < n_segments; ++i) {
        const char *text = whisper_full_get_segment_text(ctx, i);
        [result appendString:[NSString stringWithUTF8String:text]];
    }
    
    return [result copy];
}

- (void)dealloc {
    if (ctx != nullptr) {
        whisper_free(ctx);
        ctx = nullptr;
    }
}

@end
