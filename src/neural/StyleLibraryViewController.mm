//
//  StyleLibraryViewController.mm
//  ShaderCandy
//
//  Style library browser UI
//

#import "StyleLibraryViewController.h"
#import "StyleLibrary.h"

NS_ASSUME_NONNULL_BEGIN

@interface StyleLibraryViewController () <NSCollectionViewDataSource,
                                          NSCollectionViewDelegate>

@property(nonatomic, strong) NSScrollView *scrollView;
@property(nonatomic, strong) NSCollectionView *collectionView;
@property(nonatomic, strong) NSPopUpButton *categoryPopup;
@property(nonatomic, strong) NSSlider *strengthSlider;
@property(nonatomic, strong) NSTextField *strengthLabel;
@property(nonatomic, strong) NSButton *favoritesButton;
@property(nonatomic, strong) NSArray<StylePreset *> *displayedStyles;
@property(nonatomic, strong) NSString *currentFilter;

@end

@implementation StyleLibraryViewController

- (void)viewDidLoad {
  [super viewDidLoad];

  [self setupUI];
  [self reloadStyles];
}

- (void)setupUI {
  self.view.frame = NSMakeRect(0, 0, 700, 500);

  // Category filter
  _categoryPopup = [[NSPopUpButton alloc]
      initWithFrame:NSMakeRect(20, self.view.bounds.size.height - 40, 150, 28)];
  [_categoryPopup addItemWithTitle:@"All Categories"];
  [_categoryPopup setTarget:self];
  [_categoryPopup setAction:@selector(categoryChanged:)];
  [self.view addSubview:_categoryPopup];

  // Favorites button
  _favoritesButton = [[NSButton alloc]
      initWithFrame:NSMakeRect(180, self.view.bounds.size.height - 40, 100,
                               28)];
  _favoritesButton.title = @"Favorites";
  _favoritesButton.bezelStyle = NSBezelStyleRounded;
  [_favoritesButton setTarget:self];
  [_favoritesButton setAction:@selector(showFavorites)];
  [self.view addSubview:_favoritesButton];

  // Strength slider
  _strengthSlider = [[NSSlider alloc]
      initWithFrame:NSMakeRect(300, self.view.bounds.size.height - 40, 200,
                               28)];
  _strengthSlider.minValue = 0.0;
  _strengthSlider.maxValue = 1.0;
  _strengthSlider.floatValue = 0.8;
  _strengthSlider.target = self;
  _strengthSlider.action = @selector(strengthChanged:);
  [self.view addSubview:_strengthSlider];

  _strengthLabel = [[NSTextField alloc]
      initWithFrame:NSMakeRect(510, self.view.bounds.size.height - 40, 60, 22)];
  _strengthLabel.stringValue = @"80%";
  _strengthLabel.editable = NO;
  _strengthLabel.bordered = NO;
  _strengthLabel.backgroundColor = [NSColor clearColor];
  [self.view addSubview:_strengthLabel];

  // Collection view for styles
  NSCollectionViewFlowLayout *layout =
      [[NSCollectionViewFlowLayout alloc] init];
  layout.itemSize = NSMakeSize(150, 180);
  layout.sectionInset = NSEdgeInsetsMake(20, 20, 20, 20);
  layout.minimumInteritemSpacing = 20;
  layout.minimumLineSpacing = 20;

  _collectionView = [[NSCollectionView alloc] init];
  _collectionView.collectionViewLayout = layout;
  _collectionView.dataSource = self;
  _collectionView.delegate = self;
  _collectionView.selectable = YES;
  _collectionView.allowsMultipleSelection = NO;

  _scrollView = [[NSScrollView alloc]
      initWithFrame:NSMakeRect(0, 60, self.view.bounds.size.width,
                               self.view.bounds.size.height - 100)];
  _scrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  _scrollView.documentView = _collectionView;
  [self.view addSubview:_scrollView];

  // Apply button
  NSButton *applyButton = [[NSButton alloc]
      initWithFrame:NSMakeRect(self.view.bounds.size.width - 120, 10, 100, 32)];
  applyButton.title = @"Apply";
  applyButton.bezelStyle = NSBezelStyleRounded;
  applyButton.target = self;
  applyButton.action = @selector(applySelectedStyle);
  applyButton.autoresizingMask = NSViewMinXMargin | NSViewMaxYMargin;
  [self.view addSubview:applyButton];

  // Close button
  NSButton *closeButton =
      [[NSButton alloc] initWithFrame:NSMakeRect(20, 10, 100, 32)];
  closeButton.title = @"Close";
  closeButton.bezelStyle = NSBezelStyleRounded;
  closeButton.target = self;
  closeButton.action = @selector(closeLibrary);
  [self.view addSubview:closeButton];
}

- (void)reloadStyles {
  StyleLibrary *library = [StyleLibrary sharedLibrary];

  // Update categories
  [_categoryPopup removeAllItems];
  [_categoryPopup addItemWithTitle:@"All Categories"];
  for (NSString *category in library.categories) {
    [_categoryPopup addItemWithTitle:category];
  }

  // Reload collection
  _displayedStyles = library.allStyles;
  [_collectionView reloadData];
}

- (void)showCategory:(nullable NSString *)category {
  StyleLibrary *library = [StyleLibrary sharedLibrary];
  _displayedStyles = [library stylesForCategory:category];
  [_collectionView reloadData];
}

- (void)showFavorites {
  StyleLibrary *library = [StyleLibrary sharedLibrary];
  _displayedStyles = library.favoriteStyles;
  [_collectionView reloadData];
}

- (void)categoryChanged:(NSPopUpButton *)sender {
  NSString *selected = sender.titleOfSelectedItem;
  if ([selected isEqualToString:@"All Categories"]) {
    [self reloadStyles];
  } else {
    [self showCategory:selected];
  }
}

- (void)strengthChanged:(NSSlider *)sender {
  _previewStrength = sender.floatValue;
  _strengthLabel.stringValue =
      [NSString stringWithFormat:@"%d%%", (int)(_previewStrength * 100)];
}

- (void)applySelectedStyle {
  if (_selectedStyle) {
    if ([self.delegate respondsToSelector:@selector(styleLibrary:
                                                   didApplyStyle:)]) {
      [self.delegate styleLibrary:self didApplyStyle:_selectedStyle];
    }
  }
}

- (void)closeLibrary {
  if ([self.delegate respondsToSelector:@selector(styleLibraryDidClose:)]) {
    [self.delegate styleLibraryDidClose:self];
  }
}

#pragma mark - NSCollectionViewDataSource

- (NSInteger)collectionView:(NSCollectionView *)collectionView
     numberOfItemsInSection:(NSInteger)section {
  return _displayedStyles.count;
}

- (NSCollectionViewItem *)collectionView:(NSCollectionView *)collectionView
     itemForRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath {
  NSCollectionViewItem *item =
      [collectionView makeItemWithIdentifier:@"StyleItem"
                                forIndexPath:indexPath];

  if (indexPath.item < (NSInteger)_displayedStyles.count) {
    StylePreset *style = _displayedStyles[indexPath.item];

    // Configure item view
    NSView *view = item.view;
    view.wantsLayer = YES;
    view.layer.backgroundColor = [NSColor controlBackgroundColor].CGColor;
    view.layer.cornerRadius = 8;

    // Remove old subviews
    for (NSView *subview in view.subviews) {
      [subview removeFromSuperview];
    }

    // Thumbnail
    NSImageView *imageView =
        [[NSImageView alloc] initWithFrame:NSMakeRect(10, 50, 130, 100)];
    imageView.image =
        style.thumbnail ?: [NSImage imageNamed:@"style_placeholder"];
    imageView.imageScaling = NSImageScaleProportionallyUpOrDown;
    [view addSubview:imageView];

    // Name label
    NSTextField *nameLabel =
        [[NSTextField alloc] initWithFrame:NSMakeRect(10, 25, 130, 20)];
    nameLabel.stringValue = style.displayName;
    nameLabel.alignment = NSTextAlignmentCenter;
    nameLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    nameLabel.editable = NO;
    nameLabel.bordered = NO;
    nameLabel.backgroundColor = [NSColor clearColor];
    [view addSubview:nameLabel];

    // Category label
    NSTextField *catLabel =
        [[NSTextField alloc] initWithFrame:NSMakeRect(10, 5, 130, 16)];
    catLabel.stringValue = style.category;
    catLabel.alignment = NSTextAlignmentCenter;
    catLabel.font = [NSFont systemFontOfSize:10];
    catLabel.textColor = [NSColor secondaryLabelColor];
    catLabel.editable = NO;
    catLabel.bordered = NO;
    catLabel.backgroundColor = [NSColor clearColor];
    [view addSubview:catLabel];

    // Favorite indicator
    if (style.isFavorite) {
      NSTextField *favIndicator =
          [[NSTextField alloc] initWithFrame:NSMakeRect(125, 155, 20, 20)];
      favIndicator.stringValue = @"★";
      favIndicator.font = [NSFont systemFontOfSize:14];
      favIndicator.textColor = [NSColor systemYellowColor];
      favIndicator.editable = NO;
      favIndicator.bordered = NO;
      favIndicator.backgroundColor = [NSColor clearColor];
      [view addSubview:favIndicator];
    }
  }

  return item;
}

#pragma mark - NSCollectionViewDelegate

- (void)collectionView:(NSCollectionView *)collectionView
    didSelectItemsAtIndexPaths:(NSSet<NSIndexPath *> *)indexPaths {
  NSIndexPath *indexPath = indexPaths.anyObject;
  if (indexPath && indexPath.item < (NSInteger)_displayedStyles.count) {
    _selectedStyle = _displayedStyles[indexPath.item];
    [_selectedStyle incrementUseCount];

    if ([self.delegate respondsToSelector:@selector(styleLibrary:
                                                  didSelectStyle:)]) {
      [self.delegate styleLibrary:self didSelectStyle:_selectedStyle];
    }
  }
}

@end

NS_ASSUME_NONNULL_END
