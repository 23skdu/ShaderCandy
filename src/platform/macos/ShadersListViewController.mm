//
//  ShadersListViewController.mm
//  ShaderCandy
//
//  View controller for the shader list sidebar
//

#import "ShadersListViewController.h"

@interface ShadersListViewController () <NSTableViewDataSource, NSTableViewDelegate>

@property(nonatomic, strong) NSTableView *tableView;
@property(nonatomic, strong) NSSearchField *searchField;
@property(nonatomic, strong) NSArray<NSString *> *filteredShaders;
@property(nonatomic, strong) NSString *filterText;

@end

@implementation ShadersListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _shaders = @[];
    _filteredShaders = @[];
    _filterText = @"";
    
    [self setupUI];
}

- (void)setupUI {
    self.view.frame = NSMakeRect(0, 0, 200, 500);
    self.view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    
    // Search field
    _searchField = [[NSSearchField alloc] initWithFrame:NSMakeRect(10, self.view.bounds.size.height - 35, 180, 24)];
    _searchField.placeholderString = @"Search shaders...";
    _searchField.action = @selector(searchChanged:);
    _searchField.target = self;
    _searchField.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
    [self.view addSubview:_searchField];
    
    // Table view
    NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 35, 200, self.view.bounds.size.height - 75)];
    scrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    scrollView.hasVerticalScroller = YES;
    scrollView.borderType = NSNoBorder;
    
    _tableView = [[NSTableView alloc] initWithFrame:scrollView.bounds];
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.headerView = nil;
    _tableView.rowHeight = 32;
    _tableView.backgroundColor = [NSColor clearColor];
    _tableView.selectionHighlightStyle = NSTableViewSelectionHighlightStyleSourceList;
    
    NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:@"shader"];
    column.width = 180;
    [_tableView addTableColumn:column];
    
    scrollView.documentView = _tableView;
    [self.view addSubview:scrollView];
    
    // Category headers
    [self setupCategories];
}

- (void)setupCategories {
    // Shader categories
    _shaderCategories = @{
        @"Fractals": @[@"mandelbulb_3d", @"julia_3d", @"julia_set", @"mandelbrot_set"],
        @"Abstract": @[@"plasma", @"vortex", @"spiral", @"neon_pulse", @"liquid_gradient"],
        @"Space": @[@"nebula", @"starfield_warp", @"tunnel", @"kaleidoscopic_tunnel"],
        @"Effects": @[@"ripples", @"flying_toasters", @"fractal_zoom"]
    };
}

#pragma mark - Data

- (void)setShaders:(NSArray<NSString *> *)shaders {
    _shaders = shaders ?: @[];
    [self updateFilteredShaders];
}

- (void)updateFilteredShaders {
    if (_filterText.length == 0) {
        _filteredShaders = _shaders;
    } else {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF CONTAINS[cd] %@", _filterText];
        _filteredShaders = [_shaders filteredArrayUsingPredicate:predicate];
    }
    [_tableView reloadData];
}

- (void)refreshPresets {
    [_tableView reloadData];
}

#pragma mark - Actions

- (void)searchChanged:(NSSearchField *)sender {
    _filterText = sender.stringValue;
    [self updateFilteredShaders];
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return _filteredShaders.count;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (row >= 0 && row < (NSInteger)_filteredShaders.count) {
        return _filteredShaders[row];
    }
    return @"";
}

#pragma mark - NSTableViewDelegate

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (row >= 0 && row < (NSInteger)_filteredShaders.count) {
        NSString *shaderName = _filteredShaders[row];
        
        NSTableCellView *cell = [tableView makeViewWithIdentifier:@"shader" owner:self];
        if (!cell) {
            cell = [[NSTableCellView alloc] initWithFrame:NSMakeRect(0, 0, 180, 32)];
            cell.identifier = @"shader";
            
            NSTextField *textField = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 6, 160, 20)];
            textField.editable = NO;
            textField.bordered = NO;
            textField.backgroundColor = [NSColor clearColor];
            textField.autoresizingMask = NSViewWidthSizable;
            cell.textField = textField;
            [cell addSubview:textField];
        }
        
        cell.textField.stringValue = shaderName;
        
        // Highlight selected
        if ([shaderName isEqualToString:_selectedShader]) {
            cell.textField.textColor = [NSColor selectedControlTextColor];
        } else {
            cell.textField.textColor = [NSColor controlTextColor];
        }
        
        return cell;
    }
    return nil;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    NSInteger row = _tableView.selectedRow;
    if (row >= 0 && row < (NSInteger)_filteredShaders.count) {
        NSString *shaderName = _filteredShaders[row];
        _selectedShader = shaderName;
        [self onShaderSelected:shaderName];
    }
}

#pragma mark - Callbacks

- (void)onShaderSelected:(NSString *)shaderName {
    // Post notification for parent controllers
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ShaderDidChange"
                                                        object:self
                                                      userInfo:@{@"shader": shaderName}];
}

@end
