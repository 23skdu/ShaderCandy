//
//  PresetImportExportSheet.mm
//  ShaderCandy
//
//  Import/Export sheet implementation
//

#import "PresetImportExportSheet.h"

@implementation PresetImportExportSheet

+ (void)showImportSheetForWindow:(NSWindow *)window completion:(void (^)(NSArray<NSURL *> *urls))completion {
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    openPanel.allowsMultipleSelection = YES;
    openPanel.canChooseDirectories = NO;
    openPanel.canChooseFiles = YES;
    
    [openPanel beginSheetModalForWindow:window completionHandler:^(NSModalResponse result) {
        if (result == NSModalResponseOK && completion) {
            completion(openPanel.URLs);
        }
    }];
}

+ (void)showExportSheetForWindow:(NSWindow *)window presetName:(NSString *)name completion:(void (^)(NSURL *url))completion {
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    savePanel.nameFieldStringValue = name ?: @"preset";
    
    [savePanel beginSheetModalForWindow:window completionHandler:^(NSModalResponse result) {
        if (result == NSModalResponseOK && completion) {
            completion(savePanel.URL);
        }
    }];
}

@end
