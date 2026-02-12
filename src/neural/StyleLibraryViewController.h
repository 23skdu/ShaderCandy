//
//  StyleLibraryViewController.h
//  ShaderCandy
//
//  UI for browsing and selecting neural styles
//

#import <Cocoa/Cocoa.h>

@class StylePreset;

@protocol StyleLibraryViewControllerDelegate <NSObject>

@optional
- (void)styleLibrary:(id _Nullable)controller didSelectStyle:(StylePreset * _Nullable)style;
- (void)styleLibrary:(id _Nullable)controller didApplyStyle:(StylePreset * _Nullable)style;
- (void)styleLibraryDidClose:(id _Nullable)controller;

@end

@interface StyleLibraryViewController : NSViewController

@property(nonatomic, weak, nullable) id<StyleLibraryViewControllerDelegate> delegate;
@property(nonatomic, strong, nullable) StylePreset *selectedStyle;
@property(nonatomic, assign) float previewStrength;

- (void)reloadStyles;
- (void)showCategory:(NSString * _Nullable)category;
- (void)showFavorites;

@end
