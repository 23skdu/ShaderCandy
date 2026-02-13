//
//  StyleLibrary.h
//  ShaderCandy
//
//  Manages bundled and user-installed style models
//

#import <Foundation/Foundation.h>

@class StyleTransferModel;
@class StylePreset;

NS_ASSUME_NONNULL_BEGIN

@interface StyleLibrary : NSObject

@property(nonatomic, strong, readonly, nullable)
    NSArray<StylePreset *> *allStyles;
@property(nonatomic, strong, readonly, nullable)
    NSArray<NSString *> *categories;
@property(nonatomic, strong, readonly, nullable) StylePreset *currentStyle;
@property(nonatomic, strong, readonly, nullable) NSString *libraryPath;

+ (nullable instancetype)sharedLibrary;

- (void)scanForStyles;
- (void)reloadLibrary;

- (nullable NSArray<StylePreset *> *)stylesForCategory:
    (nullable NSString *)category;
- (nullable StylePreset *)styleNamed:(nullable NSString *)name;
- (nullable StylePreset *)styleAtIndex:(NSInteger)index;

- (BOOL)downloadStyle:(nullable NSString *)styleName
           completion:(void (^_Nullable)(BOOL success,
                                         NSError *_Nullable error))completion;
- (BOOL)importStyleFromURL:(nullable NSURL *)url error:(NSError **)error;
- (BOOL)deleteStyle:(nullable StylePreset *)style error:(NSError **)error;

- (void)addToFavorites:(nullable StylePreset *)style;
- (void)removeFromFavorites:(nullable StylePreset *)style;
- (nullable NSArray<StylePreset *> *)favoriteStyles;

- (void)prewarmStyle:(nullable NSString *)styleName;
- (void)prewarmAllStyles;

@end

NS_ASSUME_NONNULL_END

NS_ASSUME_NONNULL_BEGIN

@interface StylePreset : NSObject

@property(nonatomic, copy) NSString *identifier;
@property(nonatomic, copy) NSString *name;
@property(nonatomic, copy) NSString *displayName;
@property(nonatomic, copy) NSString *category;
@property(nonatomic, copy, nullable) NSString *styleDescription;
@property(nonatomic, copy, nullable) NSString *author;
@property(nonatomic, strong, nullable) NSImage *thumbnail;
@property(nonatomic, copy, nullable) NSString *version;
@property(nonatomic, strong, nullable) NSDate *installDate;
@property(nonatomic, assign) float recommendedStrength;
@property(nonatomic, assign) BOOL isBuiltIn;
@property(nonatomic, assign) BOOL isFavorite;
@property(nonatomic, assign) NSInteger useCount;
@property(nonatomic, strong, nullable) NSURL *modelURL;

- (instancetype)initWithIdentifier:(NSString *)identifier
                              name:(NSString *)name
                          category:(NSString *)category;

- (void)loadThumbnail;
- (void)incrementUseCount;

@end

NS_ASSUME_NONNULL_END
