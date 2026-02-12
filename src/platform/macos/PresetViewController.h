#import <Cocoa/Cocoa.h>

@class PresetObject;

NS_ASSUME_NONNULL_BEGIN

@protocol PresetViewControllerDelegate <NSObject>

@optional
- (void)presetViewController:(id)controller didSelectPreset:(PresetObject *)preset;
- (void)presetViewController:(id)controller didApplyPreset:(PresetObject *)preset;

@end

@interface PresetViewController : NSViewController

@property(nonatomic, weak, nullable) id<PresetViewControllerDelegate> delegate;
@property(nonatomic, strong, nullable) PresetObject *selectedPreset;
@property(nonatomic, strong) NSArray<PresetObject *> *presets;
@property(nonatomic, strong, nullable) NSString *currentShader;

@property(nonatomic, copy, nullable) NSString *filterText;
@property(nonatomic, strong, nullable) NSString *selectedCategory;

- (void)refreshPresets;
- (void)applySelectedPreset;
- (void)deleteSelectedPreset;
- (void)favoriteSelectedPreset;

- (void)importPresetsFromFiles:(NSArray<NSURL *> *)urls;
- (void)exportPreset:(PresetObject *)preset toURL:(NSURL *)url;

@end

NS_ASSUME_NONNULL_END
