//
//  ShadersListViewController.h
//  ShaderCandy
//
//  View controller for the shader list sidebar
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface ShadersListViewController : NSViewController

@property(nonatomic, strong) NSArray<NSString *> *shaders;
@property(nonatomic, strong, nullable) NSString *selectedShader;
@property(nonatomic, strong) NSDictionary<NSString *, NSArray<NSString *> *> *shaderCategories;

// Callbacks
- (void)onShaderSelected:(NSString *)shaderName;
- (void)refreshPresets;

@end

NS_ASSUME_NONNULL_END
