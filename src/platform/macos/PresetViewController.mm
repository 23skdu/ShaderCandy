#import "PresetViewController.h"
#import "PresetObject.h"
#import "../../config/PresetManager.h"
#import "../../config/ConfigurationManager.h"
#import "PresetImportExportSheet.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

using namespace ShaderCandy::Config;

@interface PresetViewController () <NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate>

@property(nonatomic, strong) NSScrollView *scrollView;
@property(nonatomic, strong) NSTableView *tableView;
@property(nonatomic, strong) NSSearchField *searchField;
@property(nonatomic, strong) NSPopUpButton *categoryPopup;
@property(nonatomic, strong) NSButton *importButton;
@property(nonatomic, strong) NSButton *exportButton;
@property(nonatomic, strong) NSButton *deleteButton;
@property(nonatomic, strong) NSButton *applyButton;

@property(nonatomic, strong) NSArray<PresetObject *> *filteredPresets;
@property(nonatomic, strong) NSArray<NSString *> *categories;

@end

@implementation PresetViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupUI];
    [self loadPresets];
}

- (void)setupUI {
    self.view.frame = NSMakeRect(0, 0, 600, 400);
    
    // Search field
    _searchField = [[NSSearchField alloc] initWithFrame:NSMakeRect(10, self.view.bounds.size.height - 35, 200, 24)];
    _searchField.placeholderString = @"Search presets...";
    _searchField.delegate = self;
    _searchField.autoresizingMask = NSViewMinYMargin | NSViewMaxXMargin;
    [self.view addSubview:_searchField];
    
    // Category filter
    _categoryPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(220, self.view.bounds.size.height - 35, 150, 24)];
    [_categoryPopup addItemWithTitle:@"All Categories"];
    [_categoryPopup addItemsWithTitles:@[@"Fractals", @"Abstract", @"Space", @"Nature", @"Custom"]];
    [_categoryPopup setTarget:self];
    [_categoryPopup setAction:@selector(categoryChanged:)];
    _categoryPopup.autoresizingMask = NSViewMinYMargin | NSViewMaxXMargin;
    [self.view addSubview:_categoryPopup];
    
    // Table view
    _scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(10, 50, 580, self.view.bounds.size.height - 95)];
    _scrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    _scrollView.hasVerticalScroller = YES;
    _scrollView.borderType = NSBezelBorder;
    
    _tableView = [[NSTableView alloc] initWithFrame:_scrollView.bounds];
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.allowsMultipleSelection = NO;
    _tableView.rowHeight = 40;
    
    NSTableColumn *nameColumn = [[NSTableColumn alloc] initWithIdentifier:@"name"];
    nameColumn.title = @"Preset";
    nameColumn.width = 200;
    [_tableView addTableColumn:nameColumn];
    
    NSTableColumn *shaderColumn = [[NSTableColumn alloc] initWithIdentifier:@"shader"];
    shaderColumn.title = @"Shader";
    shaderColumn.width = 120;
    [_tableView addTableColumn:shaderColumn];
    
    NSTableColumn *categoryColumn = [[NSTableColumn alloc] initWithIdentifier:@"category"];
    categoryColumn.title = @"Category";
    categoryColumn.width = 100;
    [_tableView addTableColumn:categoryColumn];
    
    NSTableColumn *authorColumn = [[NSTableColumn alloc] initWithIdentifier:@"author"];
    authorColumn.title = @"Author";
    authorColumn.width = 120;
    [_tableView addTableColumn:authorColumn];
    
    _scrollView.documentView = _tableView;
    [self.view addSubview:_scrollView];
    
    // Buttons
    CGFloat buttonY = 10;
    CGFloat buttonWidth = 80;
    CGFloat spacing = 10;
    
    _applyButton = [[NSButton alloc] initWithFrame:NSMakeRect(10, buttonY, buttonWidth, 28)];
    _applyButton.title = @"Apply";
    _applyButton.bezelStyle = NSBezelStyleRounded;
    _applyButton.target = self;
    _applyButton.action = @selector(applySelectedPreset);
    [self.view addSubview:_applyButton];
    
    _importButton = [[NSButton alloc] initWithFrame:NSMakeRect(100, buttonY, buttonWidth, 28)];
    _importButton.title = @"Import";
    _importButton.bezelStyle = NSBezelStyleRounded;
    _importButton.target = self;
    _importButton.action = @selector(importButtonClicked:);
    [self.view addSubview:_importButton];
    
    _exportButton = [[NSButton alloc] initWithFrame:NSMakeRect(190, buttonY, buttonWidth, 28)];
    _exportButton.title = @"Export";
    _exportButton.bezelStyle = NSBezelStyleRounded;
    _exportButton.target = self;
    _exportButton.action = @selector(exportButtonClicked:);
    [self.view addSubview:_exportButton];
    
    _deleteButton = [[NSButton alloc] initWithFrame:NSMakeRect(280, buttonY, buttonWidth, 28)];
    _deleteButton.title = @"Delete";
    _deleteButton.bezelStyle = NSBezelStyleRounded;
    _deleteButton.target = self;
    _deleteButton.action = @selector(deleteSelectedPreset);
    [self.view addSubview:_deleteButton];
}

#pragma mark - Data Loading

- (void)loadPresets {
    std::string error;
    auto allPresets = PresetManager::getInstance().allUserPresets();
    
    NSMutableArray *presets = [NSMutableArray array];
    for (const auto& preset : allPresets) {
        PresetObject *obj = [[PresetObject alloc] initWithCPPConfig:(void *)&preset];
        [presets addObject:obj];
    }
    
    _presets = presets;
    [self filterPresets];
}

- (void)refreshPresets {
    [self loadPresets];
    [_tableView reloadData];
}

#pragma mark - Filtering

- (void)filterPresets {
    NSMutableArray *filtered = [NSMutableArray array];
    NSString *category = [_categoryPopup.titleOfSelectedItem isEqualToString:@"All Categories"] ? nil : _categoryPopup.titleOfSelectedItem;

    for (PresetObject *preset in _presets) {
        BOOL matchesSearch = YES;
        BOOL matchesCategory = YES;

        if (_filterText.length > 0) {
            matchesSearch = [preset.name localizedCaseInsensitiveContainsString:_filterText];
        }

        if (category && preset.category) {
            matchesCategory = [preset.category isEqualToString:category];
        }

        if (matchesSearch && matchesCategory) {
            [filtered addObject:preset];
        }
    }

    _filteredPresets = filtered;
    [_tableView reloadData];
}

- (void)controlTextDidChange:(NSNotification *)obj {
    if (obj.object == _searchField) {
        _filterText = _searchField.stringValue;
        [self filterPresets];
    }
}

- (void)categoryChanged:(NSPopUpButton *)sender {
    [self filterPresets];
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return _filteredPresets.count;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (row >= (NSInteger)_filteredPresets.count) return @"";

    PresetObject *preset = _filteredPresets[row];

    if ([tableColumn.identifier isEqualToString:@"name"]) {
        return preset.name;
    } else if ([tableColumn.identifier isEqualToString:@"shader"]) {
        return preset.shaderName;
    } else if ([tableColumn.identifier isEqualToString:@"category"]) {
        return preset.category ?: @"Uncategorized";
    } else if ([tableColumn.identifier isEqualToString:@"author"]) {
        return preset.author ?: @"Unknown";
    }

    return @"";
}

#pragma mark - NSTableViewDelegate

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    NSInteger row = _tableView.selectedRow;
    if (row >= 0 && row < (NSInteger)_filteredPresets.count) {
        _selectedPreset = _filteredPresets[row];
        
        if ([self.delegate respondsToSelector:@selector(presetViewController:didSelectPreset:)]) {
            [self.delegate presetViewController:self didSelectPreset:_selectedPreset];
        }
    }
}

#pragma mark - Actions

- (void)applySelectedPreset {
    if (!_selectedPreset) return;
    
    if ([self.delegate respondsToSelector:@selector(presetViewController:didApplyPreset:)]) {
        [self.delegate presetViewController:self didApplyPreset:_selectedPreset];
    }
}

- (void)deleteSelectedPreset {
    if (!_selectedPreset) return;

    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Delete Preset?";
    alert.informativeText = [NSString stringWithFormat:@"Are you sure you want to delete '%@'?", _selectedPreset.name];
    [alert addButtonWithTitle:@"Delete"];
    [alert addButtonWithTitle:@"Cancel"];
    alert.alertStyle = NSAlertStyleWarning;

    [alert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertFirstButtonReturn) {
            std::string error;
            std::string path = std::string([_selectedPreset.filePath UTF8String] ?: "");
            if (PresetManager::getInstance().deletePreset(path, error)) {
                [self refreshPresets];
            }
        }
    }];
}

- (void)favoriteSelectedPreset {
    // Implementation for favoriting
}

#pragma mark - Import/Export

- (void)importButtonClicked:(id)sender {
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    openPanel.allowsMultipleSelection = YES;
    openPanel.canChooseDirectories = NO;
    openPanel.canChooseFiles = YES;

    if (@available(macOS 11.0, *)) {
        openPanel.allowedContentTypes = @[[UTType typeWithIdentifier:@"public.json"]];
    } else {
        openPanel.allowedFileTypes = @[@"json"];
    }

    [openPanel beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse result) {
        if (result == NSModalResponseOK) {
            [self importPresetsFromFiles:openPanel.URLs];
        }
    }];
}

- (void)importPresetsFromFiles:(NSArray<NSURL *> *)urls {
    for (NSURL *url in urls) {
        std::string error;
        std::string path = std::string([url.path UTF8String]);
        
        auto preset = PresetManager::getInstance().loadPreset(path, error);
        if (preset.has_value()) {
            // Save to user presets directory
            std::string destPath = ConfigurationManager::getPresetDirectory() + "/User/" + preset->name + ".json";
            PresetManager::getInstance().savePreset(preset.value(), destPath, error);
        }
    }
    
    [self refreshPresets];
}

- (void)exportButtonClicked:(id)sender {
    if (!_selectedPreset) return;

    NSSavePanel *savePanel = [NSSavePanel savePanel];
    savePanel.nameFieldStringValue = [NSString stringWithFormat:@"%@.json", _selectedPreset.name];

    if (@available(macOS 11.0, *)) {
        savePanel.allowedContentTypes = @[[UTType typeWithIdentifier:@"public.json"]];
    } else {
        savePanel.allowedFileTypes = @[@"json"];
    }

    [savePanel beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse result) {
        if (result == NSModalResponseOK) {
            [self exportPreset:_selectedPreset toURL:savePanel.URL];
        }
    }];
}

- (void)exportPreset:(PresetObject *)preset toURL:(NSURL *)url {
    std::string error;
    std::string path = std::string([url.path UTF8String] ?: "");

    void *cppConfig = [preset toCPPConfig];
    if (cppConfig) {
        ShaderCandy::Config::Preset *cppPreset = static_cast<ShaderCandy::Config::Preset *>(cppConfig);
        PresetManager::getInstance().exportPreset(*cppPreset, path, error);
        delete cppPreset;
    }
}

@end
