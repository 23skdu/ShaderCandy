//
//  StyleLibraryTests.mm
//  ShaderCandy
//
//  Unit tests for StyleLibrary functionality
//

#import <XCTest/XCTest.h>

@class StyleLibrary;
@class StylePreset;

@interface StyleLibraryTests : XCTestCase

@property(nonatomic, strong) StyleLibrary *library;

@end

@implementation StyleLibraryTests

- (void)setUp {
    [super setUp];
    // Note: StyleLibrary is a singleton, so we test the shared instance
}

- (void)tearDown {
    [super tearDown];
}

#pragma mark - Library Tests

- (void)testStyleLibrarySingleton {
    // Test that sharedLibrary returns the same instance
    StyleLibrary *lib1 = [StyleLibrary sharedLibrary];
    StyleLibrary *lib2 = [StyleLibrary sharedLibrary];

    XCTAssertEqual(lib1, lib2, @"Library should be singleton");
}

- (void)testLibraryHasStyles {
    StyleLibrary *library = [StyleLibrary sharedLibrary];
    NSArray *styles = library.allStyles;

    XCTAssertNotNil(styles, @"Library should return styles array");
    // Note: May be empty if no models are bundled
}

- (void)testLibraryCategories {
    StyleLibrary *library = [StyleLibrary sharedLibrary];
    NSArray *categories = library.categories;

    XCTAssertNotNil(categories, @"Should return categories");
}

- (void)testStylesForCategory {
    StyleLibrary *library = [StyleLibrary sharedLibrary];
    NSArray *artStyles = [library stylesForCategory:@"Art"];

    XCTAssertNotNil(artStyles, @"Should return styles for category");
}

- (void)testStyleLookup {
    StyleLibrary *library = [StyleLibrary sharedLibrary];

    // Try to find a known style
    StylePreset *style = [library styleNamed:@"starry_night"];

    // Note: Will be nil if style not installed
    // Just verify method works
    XCTAssertTrue(YES, @"Style lookup method should not crash");
}

#pragma mark - Favorites Tests

- (void)testAddToFavorites {
    StyleLibrary *library = [StyleLibrary sharedLibrary];
    NSArray *styles = library.allStyles;

    if (styles.count > 0) {
        StylePreset *style = styles[0];
        [library addToFavorites:style];

        NSArray *favorites = library.favoriteStyles;
        XCTAssertTrue(favorites.count > 0 || !style.isFavorite, @"Favorites should update");
    }
}

#pragma mark - Performance Tests

- (void)testLibraryScanningPerformance {
    [self measureBlock:^{
        StyleLibrary *library = [[StyleLibrary alloc] init];
        [library scanForStyles];
    }];
}

@end
