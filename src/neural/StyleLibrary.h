//
//  StyleLibrary.h
//  ShaderCandy
//
//  Manages bundled and user-installed style models
//

#import <Foundation/Foundation.h>

@class StyleTransferModel;
@class StylePreset;

@interface StyleLibrary : NSObject

@property(nonatomic, strong, readonly) NSArray<StylePreset *> *allStyles;
@property(nonatomic, strong, readonly) NSArray<NSString *> *categories;
@property(nonatomic, strong, readonly, nullable) StylePreset *currentStyle;
@property(nonatomic, strong, readonly) NSString *libraryPath;

+ (instancetype)sharedLibrary;

- (void)scanForStyles;
- (void)reloadLibrary;

- (NSArray<StylePreset *> *)stylesForCategory:(NSString *)category;
- (nullable StylePreset *)styleNamed:(NSString *)name;
- (nullable StylePreset *)styleAtIndex:(NSInteger)index;

- (BOOL)downloadStyle:(NSString *)styleName completion:(void (^)(BOOL success, NSError *error))completion;
- (BOOL)importStyleFromURL:(NSURL *)url error:(NSError **)error;
- (BOOL)deleteStyle:(StylePreset *)style error:(NSError **)error;

- (void)addToFavorites:(StylePreset *)style;
- (void)removeFromFavorites:(StylePreset *)style;
- (NSArray<StylePreset *> *)favoriteStyles;

- (void)prewarmStyle:(NSString *)styleName;
- (void)prewarmAllStyles;

@end

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
