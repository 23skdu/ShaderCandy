//
//  PresetImportExportSheet.h
//  ShaderCandy
//
//  Import/Export sheet for presets
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface PresetImportExportSheet : NSObject

+ (void)showImportSheetForWindow:(NSWindow *)window
                      completion:(void (^)(NSArray<NSURL *> *urls))completion;
+ (void)showExportSheetForWindow:(NSWindow *)window
                      presetName:(NSString *)name
                      completion:(void (^)(NSURL *url))completion;

@end

NS_ASSUME_NONNULL_END
