//
//  StyleLibrary.mm
//  ShaderCandy
//
//  Style library implementation
//

#import "StyleLibrary.h"
#import "StyleTransferModel.h"
#import <AppKit/AppKit.h>

@interface StyleLibrary ()

@property(nonatomic, strong) NSMutableArray<StylePreset *> *styles;
@property(nonatomic, strong) NSMutableSet<NSString *> *favoriteIdentifiers;
@property(nonatomic, strong) NSMutableDictionary<NSString *, StyleTransferModel *> *loadedModels;
@property(nonatomic, strong) dispatch_queue_t libraryQueue;
@property(nonatomic, copy) NSString *libraryPath;
@property(nonatomic, strong, nullable) StylePreset *currentStyle;

@end

@implementation StyleLibrary

+ (instancetype)sharedLibrary {
    static StyleLibrary *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[StyleLibrary alloc] init];
    });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _styles = [NSMutableArray array];
        _favoriteIdentifiers = [NSMutableSet set];
        _loadedModels = [NSMutableDictionary dictionary];
        _libraryQueue = dispatch_queue_create("com.shadercandy.stylelibrary", DISPATCH_QUEUE_SERIAL);

        NSString *appSupport = [@"~/Library/Application Support/ShaderCandy/Styles" stringByExpandingTildeInPath];
        _libraryPath = appSupport;

        [self createLibraryDirectory];
        [self loadFavorites];
        [self scanForStyles];
    }
    return self;
}

- (void)createLibraryDirectory {
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:_libraryPath]) {
        [fm createDirectoryAtPath:_libraryPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
}

- (void)loadFavorites {
    NSString *favoritesPath = [_libraryPath stringByAppendingPathComponent:@"favorites.plist"];
    NSArray *favorites = [NSArray arrayWithContentsOfFile:favoritesPath];
    if (favorites) {
        [_favoriteIdentifiers addObjectsFromArray:favorites];
    }
}

- (void)saveFavorites {
    NSString *favoritesPath = [_libraryPath stringByAppendingPathComponent:@"favorites.plist"];
    [[_favoriteIdentifiers allObjects] writeToFile:favoritesPath atomically:YES];
}

- (void)scanForStyles {
    dispatch_async(_libraryQueue, ^{
        NSMutableArray *foundStyles = [NSMutableArray array];

        // Scan bundled styles
        [foundStyles addObjectsFromArray:[self scanBundledStyles]];

        // Scan user styles
        [foundStyles addObjectsFromArray:[self scanUserStyles]];

        dispatch_async(dispatch_get_main_queue(), ^{
            self.styles = foundStyles;
            [self updateFavoritesStatus];
        });
    });
}

- (NSArray<StylePreset *> *)scanBundledStyles {
    NSMutableArray *bundled = [NSMutableArray array];

    NSBundle *bundle = [NSBundle mainBundle];
    NSArray *modelURLs = [bundle URLsForResourcesWithExtension:@"mlmodelc" subdirectory:@"Styles"];

    for (NSURL *url in modelURLs) {
        NSString *name = url.lastPathComponent.stringByDeletingPathExtension;
        StylePreset *preset = [[StylePreset alloc] initWithIdentifier:name name:name category:@"Art"];
        [bundled addObject:preset];
    }

    // Add metadata for known styles
    NSDictionary *styleInfo = @{
        @"starry_night": @{@"name": @"Starry Night", @"category": @"Art", @"strength": @(0.9)},
        @"monet": @{@"name": @"Monet", @"category": @"Art", @"strength": @(0.8)},
        @"picasso": @{@"name": @"Picasso", @"category": @"Art", @"strength": @(0.85)},
        @"hokusai": @{@"name": @"Hokusai Wave", @"category": @"Art", @"strength": @(0.8)},
        @"mondrian": @{@"name": @"Mondrian", @"category": @"Abstract", @"strength": @(0.9)},
        @"cyberpunk": @{@"name": @"Cyberpunk", @"category": @"Modern", @"strength": @(0.85)},
        @"oil_painting": @{@"name": @"Oil Painting", @"category": @"Art", @"strength": @(0.75)},
        @"watercolor": @{@"name": @"Watercolor", @"category": @"Art", @"strength": @(0.8)},
        @"sketch": @{@"name": @"Pencil Sketch", @"category": @"Art", @"strength": @(0.85)},
        @"vintage": @{@"name": @"Vintage Film", @"category": @"Photo", @"strength": @(0.7)}
    };

    for (StylePreset *preset in bundled) {
        NSDictionary *info = styleInfo[preset.identifier];
        if (info) {
            preset.displayName = info[@"name"];
            preset.category = info[@"category"];
            preset.recommendedStrength = [info[@"strength"] floatValue];
        }
        preset.isBuiltIn = YES;
    }

    return bundled;
}

- (NSArray<StylePreset *> *)scanUserStyles {
    NSMutableArray *userStyles = [NSMutableArray array];

    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *contents = [fm contentsOfDirectoryAtPath:_libraryPath error:nil];

    for (NSString *filename in contents) {
        if ([filename.pathExtension isEqualToString:@"mlmodelc"]) {
            NSString *name = filename.stringByDeletingPathExtension;
            NSString *path = [_libraryPath stringByAppendingPathComponent:filename];
            StylePreset *preset = [[StylePreset alloc] initWithIdentifier:name name:name category:@"Custom"];
            preset.isBuiltIn = NO;
            [userStyles addObject:preset];
        }
    }

    return userStyles;
}

- (void)updateFavoritesStatus {
    for (StylePreset *style in _styles) {
        style.isFavorite = [_favoriteIdentifiers containsObject:style.identifier];
    }
}

- (void)reloadLibrary {
    [self scanForStyles];
}

- (NSArray<StylePreset *> *)allStyles {
    return [_styles copy];
}

- (NSArray<NSString *> *)categories {
    NSMutableSet *cats = [NSMutableSet set];
    for (StylePreset *style in _styles) {
        [cats addObject:style.category];
    }
    return [[cats allObjects] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
}

- (NSArray<StylePreset *> *)stylesForCategory:(NSString *)category {
    NSMutableArray *filtered = [NSMutableArray array];
    for (StylePreset *style in _styles) {
        if ([style.category isEqualToString:category]) {
            [filtered addObject:style];
        }
    }
    return filtered;
}

- (nullable StylePreset *)styleNamed:(NSString *)name {
    for (StylePreset *style in _styles) {
        if ([style.name isEqualToString:name] || [style.identifier isEqualToString:name]) {
            return style;
        }
    }
    return nil;
}

- (nullable StylePreset *)styleAtIndex:(NSInteger)index {
    if (index >= 0 && index < (NSInteger)_styles.count) {
        return _styles[index];
    }
    return nil;
}

- (BOOL)downloadStyle:(NSString *)styleName completion:(void (^)(BOOL success, NSError *error))completion {
    // In a real implementation, this would download from a server
    // For now, simulate success
    if (completion) {
        completion(NO, [NSError errorWithDomain:@"StyleLibrary" code:1001 userInfo:@{NSLocalizedDescriptionKey: @"Download not implemented"}]);
    }
    return NO;
}

- (BOOL)importStyleFromURL:(NSURL *)url error:(NSError **)error {
    if (![url.pathExtension isEqualToString:@"mlmodelc"] && ![url.pathExtension isEqualToString:@"mlmodel"]) {
        if (error) {
            *error = [NSError errorWithDomain:@"StyleLibrary" code:1002 userInfo:@{NSLocalizedDescriptionKey: @"Invalid model format"}];
        }
        return NO;
    }

    NSString *filename = url.lastPathComponent;
    NSString *destPath = [_libraryPath stringByAppendingPathComponent:filename];

    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:destPath]) {
        [fm removeItemAtPath:destPath error:nil];
    }

    NSError *copyError = nil;
    BOOL success = [fm copyItemAtPath:url.path toPath:destPath error:&copyError];

    if (!success && error) {
        *error = copyError;
    } else if (success) {
        [self scanForStyles];
    }

    return success;
}

- (BOOL)deleteStyle:(StylePreset *)style error:(NSError **)error {
    if (style.isBuiltIn) {
        if (error) {
            *error = [NSError errorWithDomain:@"StyleLibrary" code:1003 userInfo:@{NSLocalizedDescriptionKey: @"Cannot delete built-in styles"}];
        }
        return NO;
    }

    NSString *path = [_libraryPath stringByAppendingPathComponent:[style.identifier stringByAppendingString:@".mlmodelc"]];
    NSFileManager *fm = [NSFileManager defaultManager];

    NSError *removeError = nil;
    BOOL success = [fm removeItemAtPath:path error:&removeError];

    if (success) {
        [_styles removeObject:style];
        [_favoriteIdentifiers removeObject:style.identifier];
        [self saveFavorites];
    } else if (error) {
        *error = removeError;
    }

    return success;
}

- (void)addToFavorites:(StylePreset *)style {
    [_favoriteIdentifiers addObject:style.identifier];
    style.isFavorite = YES;
    [self saveFavorites];
}

- (void)removeFromFavorites:(StylePreset *)style {
    [_favoriteIdentifiers removeObject:style.identifier];
    style.isFavorite = NO;
    [self saveFavorites];
}

- (NSArray<StylePreset *> *)favoriteStyles {
    NSMutableArray *favorites = [NSMutableArray array];
    for (StylePreset *style in _styles) {
        if (style.isFavorite) {
            [favorites addObject:style];
        }
    }
    return favorites;
}

- (void)prewarmStyle:(NSString *)styleName {
    dispatch_async(_libraryQueue, ^{
        StyleTransferModel *model = self.loadedModels[styleName];
        if (!model) {
            StylePreset *preset = [self styleNamed:styleName];
            if (preset) {
                model = [[StyleTransferModel alloc] initWithBundleStyle:styleName];
                NSError *error = nil;
                if ([model loadWithError:&error]) {
                    self.loadedModels[styleName] = model;
                }
            }
        }
    });
}

- (void)prewarmAllStyles {
    for (StylePreset *style in _styles) {
        [self prewarmStyle:style.identifier];
    }
}

@end

@implementation StylePreset

- (instancetype)initWithIdentifier:(NSString *)identifier name:(NSString *)name category:(NSString *)category {
    self = [super init];
    if (self) {
        _identifier = identifier;
        _name = name;
        _displayName = name;
        _category = category;
        _recommendedStrength = 0.8;
        _isBuiltIn = NO;
        _isFavorite = NO;
        _useCount = 0;
        _installDate = [NSDate date];
    }
    return self;
}

- (void)loadThumbnail {
    if (_thumbnail) return;

    // Load thumbnail from bundle or generate
    NSBundle *bundle = [NSBundle mainBundle];
    NSString *thumbName = [NSString stringWithFormat:@"%@_thumb", _identifier];
    NSString *thumbPath = [bundle pathForResource:thumbName ofType:@"png"];

    if (thumbPath) {
        _thumbnail = [[NSImage alloc] initWithContentsOfFile:thumbPath];
    }
}

- (void)incrementUseCount {
    _useCount++;
}

@end
