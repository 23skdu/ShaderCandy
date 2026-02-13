//
//  StyleLibraryViewController.h
//  ShaderCandy
//
//  UI for browsing and selecting neural styles
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class StylePreset;

@protocol StyleLibraryViewControllerDelegate <NSObject>

@optional
- (void)styleLibrary:(id)controller didSelectStyle:(StylePreset *)style;
- (void)styleLibrary:(id)controller didApplyStyle:(StylePreset *)style;
- (void)styleLibraryDidClose:(id)controller;

@end

@interface StyleLibraryViewController : NSViewController

@property(nonatomic, weak, nullable) id<StyleLibraryViewControllerDelegate>
    delegate;
@property(nonatomic, strong, nullable) StylePreset *selectedStyle;
@property(nonatomic, assign) float previewStrength;

- (void)reloadStyles;
- (void)showCategory:(nullable NSString *)category;
- (void)showFavorites;

@end

NS_ASSUME_NONNULL_END
