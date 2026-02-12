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

@property(nonatomic, strong, readonly, nullable) NSArray<StylePreset *> *allStyles;
@property(nonatomic, strong, readonly, nullable) NSArray<NSString *> *categories;
@property(nonatomic, strong, readonly, nullable) StylePreset *currentStyle;
@property(nonatomic, strong, readonly, nullable) NSString *libraryPath;

+ (instancetype _Nullable)sharedLibrary;

- (void)scanForStyles;
- (void)reloadLibrary;

- (NSArray<StylePreset *> * _Nullable)stylesForCategory:(NSString * _Nullable)category;
- (StylePreset * _Nullable)styleNamed:(NSString * _Nullable)name;
- (nullable StylePreset *)styleAtIndex:(NSInteger)index;

- (BOOL)downloadStyle:(NSString * _Nullable)styleName completion:(void (^ _Nullable)(BOOL success, NSError * _Nullable error))completion;
- (BOOL)importStyleFromURL:(NSURL * _Nullable)url error:(NSError * _Nullable *)error;
- (BOOL)deleteStyle:(StylePreset * _Nullable)style error:(NSError * _Nullable *__nullable)error;

- (void)addToFavorites:(StylePreset * _Nullable)style;
- (void)removeFromFavorites:(StylePreset * _Nullable)style;
- (NSArray<StylePreset *> * _Nullable)favoriteStyles;

- (void)prewarmStyle:(NSString * _Nullable)styleName;
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

- (instancetype _Nullable)initWithIdentifier:(NSString * _Nullable)identifier
                                         name:(NSString * _Nullable)name
                                   category:(NSString * _Nullable)category;

- (void)loadThumbnail;
- (void)incrementUseCount;

@end
