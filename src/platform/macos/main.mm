//
//  main.mm
//  ShaderCandy Player
//
//  Standalone application entry point
//

#import <Cocoa/Cocoa.h>
#import "StandaloneAppDelegate.h"

int main(int argc, const char * argv[]) {
    // Create autorelease pool
    @autoreleasepool {
        // Create application
        NSApplication *app = [NSApplication sharedApplication];
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];
        
        // Create delegate
        StandaloneAppDelegate *delegate = [[StandaloneAppDelegate alloc] init];
        app.delegate = delegate;
        
        // Process command line arguments
        for (int i = 1; i < argc; i++) {
            NSString *arg = [NSString stringWithUTF8String:argv[i]];
            
            if ([arg isEqualToString:@"--fullscreen"]) {
                // Will be handled by delegate after launch
            } else if ([arg hasPrefix:@"--shader="]) {
                NSString *shaderName = [arg substringFromIndex:8];
                delegate.currentShader = shaderName;
            } else if ([arg hasPrefix:@"--fps="]) {
                NSInteger fps = [[arg substringFromIndex:5] integerValue];
                delegate.preferredFPS = fps;
            }
        }
        
        // Run the application
        [app run];
    }
    return 0;
}
