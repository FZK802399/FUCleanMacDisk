//
//  ViewController.m
//  FUCleanMacDisk
//

#import "ViewController.h"
#import "FUScanner.h"
#import "FUCleaner.h"
#import "FUShell.h"

static NSString * const kColSelect = @"select";
static NSString * const kColTitle  = @"title";
static NSString * const kColDetail = @"detail";
static NSString * const kColSize   = @"size";
static NSString * const kColSafety = @"safety";

@interface ViewController () <NSTableViewDataSource, NSTableViewDelegate>

@property (nonatomic, strong) FUScanner *scanner;

@property (nonatomic, strong) NSTextField *diskLabel;
@property (nonatomic, strong) NSProgressIndicator *diskBar;
@property (nonatomic, strong) NSButton *scanButton;
@property (nonatomic, strong) NSButton *cleanButton;
@property (nonatomic, strong) NSProgressIndicator *spinner;
@property (nonatomic, strong) NSTextField *statusLabel;

@property (nonatomic, strong) NSTableView *junkTable;
@property (nonatomic, strong) NSTableView *runtimeTable;
@property (nonatomic, strong) NSTableView *largeTable;

@property (nonatomic, strong) NSMutableArray<FUCleanItem *> *junkItems;
@property (nonatomic, strong) NSMutableArray<FUCleanItem *> *runtimeItems;
@property (nonatomic, strong) NSMutableArray<FUCleanItem *> *largeItems;

@property (nonatomic, assign) BOOL busy;

@end

@implementation ViewController

#pragma mark - Lifecycle

- (void)loadView {
    NSView *root = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 1000, 640)];
    self.view = root;

    [self buildHeaderInView:root];
    [self buildTabsInView:root];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.scanner = [[FUScanner alloc] init];
    self.junkItems = [NSMutableArray array];
    self.runtimeItems = [NSMutableArray array];
    self.largeItems = [NSMutableArray array];
    [self refreshDiskUsage];
    self.statusLabel.stringValue = @"点击「扫描」开始分析磁盘占用";
}

- (void)viewDidAppear {
    [super viewDidAppear];
    NSWindow *win = self.view.window;
    win.title = @"FUCleanMacDisk — 磁盘清理";
    win.minSize = NSMakeSize(820, 520);
    [win setContentSize:NSMakeSize(1000, 640)];
    [win center];
}

#pragma mark - Header UI

- (void)buildHeaderInView:(NSView *)root {
    CGFloat W = root.bounds.size.width;
    CGFloat top = root.bounds.size.height;

    NSView *header = [[NSView alloc] initWithFrame:NSMakeRect(0, top - 96, W, 96)];
    header.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
    [root addSubview:header];

    self.diskLabel = [self labelWithFrame:NSMakeRect(16, 64, W - 32, 20) bold:YES];
    self.diskLabel.autoresizingMask = NSViewWidthSizable;
    self.diskLabel.font = [NSFont systemFontOfSize:14 weight:NSFontWeightSemibold];
    [header addSubview:self.diskLabel];

    self.diskBar = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(16, 48, W - 32, 10)];
    self.diskBar.style = NSProgressIndicatorStyleBar;
    self.diskBar.indeterminate = NO;
    self.diskBar.minValue = 0;
    self.diskBar.maxValue = 1;
    self.diskBar.autoresizingMask = NSViewWidthSizable;
    [header addSubview:self.diskBar];

    self.scanButton = [NSButton buttonWithTitle:@"扫描" target:self action:@selector(onScan:)];
    self.scanButton.frame = NSMakeRect(16, 10, 96, 30);
    self.scanButton.bezelStyle = NSBezelStyleRounded;
    self.scanButton.keyEquivalent = @"\r";
    [header addSubview:self.scanButton];

    self.cleanButton = [NSButton buttonWithTitle:@"清理选中" target:self action:@selector(onClean:)];
    self.cleanButton.frame = NSMakeRect(120, 10, 110, 30);
    self.cleanButton.bezelStyle = NSBezelStyleRounded;
    [header addSubview:self.cleanButton];

    self.spinner = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(240, 17, 18, 18)];
    self.spinner.style = NSProgressIndicatorStyleSpinning;
    self.spinner.displayedWhenStopped = NO;
    [header addSubview:self.spinner];

    self.statusLabel = [self labelWithFrame:NSMakeRect(266, 14, W - 282, 20) bold:NO];
    self.statusLabel.autoresizingMask = NSViewWidthSizable;
    self.statusLabel.textColor = [NSColor secondaryLabelColor];
    [header addSubview:self.statusLabel];
}

- (NSTextField *)labelWithFrame:(NSRect)frame bold:(BOOL)bold {
    NSTextField *l = [[NSTextField alloc] initWithFrame:frame];
    l.bezeled = NO;
    l.drawsBackground = NO;
    l.editable = NO;
    l.selectable = NO;
    l.font = bold ? [NSFont boldSystemFontOfSize:13] : [NSFont systemFontOfSize:12];
    return l;
}

#pragma mark - Tabs

- (void)buildTabsInView:(NSView *)root {
    CGFloat W = root.bounds.size.width;
    CGFloat H = root.bounds.size.height;
    NSTabView *tabs = [[NSTabView alloc] initWithFrame:NSMakeRect(12, 12, W - 24, H - 96 - 12)];
    tabs.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [root addSubview:tabs];

    self.junkTable = [self addTabTo:tabs label:@"垃圾清理"
                            columns:@[kColSelect, kColTitle, kColDetail, kColSize, kColSafety]];
    self.runtimeTable = [self addTabTo:tabs label:@"模拟器运行时"
                               columns:@[kColSelect, kColTitle, kColDetail, kColSize]];
    self.largeTable = [self addTabTo:tabs label:@"大文件 (>500MB)"
                             columns:@[kColSelect, kColTitle, kColDetail, kColSize]];

    self.largeTable.target = self;
    self.largeTable.doubleAction = @selector(onRevealLargeFile:);
}

- (NSTableView *)addTabTo:(NSTabView *)tabs label:(NSString *)label columns:(NSArray<NSString *> *)cols {
    NSTabViewItem *tab = [[NSTabViewItem alloc] initWithIdentifier:label];
    tab.label = label;

    NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:tab.view.bounds];
    scroll.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    scroll.hasVerticalScroller = YES;
    scroll.borderType = NSBezelBorder;

    NSTableView *table = [[NSTableView alloc] initWithFrame:scroll.bounds];
    table.usesAlternatingRowBackgroundColors = YES;
    table.rowHeight = 26;
    table.dataSource = self;
    table.delegate = self;
    table.allowsMultipleSelection = YES;

    for (NSString *cid in cols) {
        NSTableColumn *col = [[NSTableColumn alloc] initWithIdentifier:cid];
        col.title = [self titleForColumn:cid];
        col.width = [self widthForColumn:cid];
        if ([cid isEqualToString:kColDetail] || [cid isEqualToString:kColTitle]) {
            col.resizingMask = NSTableColumnAutoresizingMask | NSTableColumnUserResizingMask;
        }
        [table addTableColumn:col];
    }

    scroll.documentView = table;
    [tab.view addSubview:scroll];
    [tabs addTabViewItem:tab];
    return table;
}

- (NSString *)titleForColumn:(NSString *)cid {
    if ([cid isEqualToString:kColSelect]) { return @""; }
    if ([cid isEqualToString:kColTitle])  { return @"项目"; }
    if ([cid isEqualToString:kColDetail]) { return @"说明 / 路径"; }
    if ([cid isEqualToString:kColSize])   { return @"大小"; }
    if ([cid isEqualToString:kColSafety]) { return @"安全等级"; }
    return cid;
}

- (CGFloat)widthForColumn:(NSString *)cid {
    if ([cid isEqualToString:kColSelect]) { return 28; }
    if ([cid isEqualToString:kColTitle])  { return 230; }
    if ([cid isEqualToString:kColDetail]) { return 420; }
    if ([cid isEqualToString:kColSize])   { return 90; }
    if ([cid isEqualToString:kColSafety]) { return 80; }
    return 100;
}

#pragma mark - Data source helpers

- (NSMutableArray<FUCleanItem *> *)itemsForTable:(NSTableView *)table {
    if (table == self.junkTable)    { return self.junkItems; }
    if (table == self.runtimeTable) { return self.runtimeItems; }
    if (table == self.largeTable)   { return self.largeItems; }
    return [NSMutableArray array];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return [self itemsForTable:tableView].count;
}

- (NSView *)tableView:(NSTableView *)tableView
   viewForTableColumn:(NSTableColumn *)tableColumn
                  row:(NSInteger)row {
    NSArray<FUCleanItem *> *items = [self itemsForTable:tableView];
    if (row >= (NSInteger)items.count) { return nil; }
    FUCleanItem *item = items[row];
    NSString *cid = tableColumn.identifier;

    if ([cid isEqualToString:kColSelect]) {
        NSButton *cb = [tableView makeViewWithIdentifier:kColSelect owner:self];
        if (cb == nil) {
            cb = [NSButton checkboxWithTitle:@"" target:self action:@selector(onToggle:)];
            cb.identifier = kColSelect;
        }
        cb.state = item.selected ? NSControlStateValueOn : NSControlStateValueOff;
        return cb;
    }

    NSTableCellView *cell = [tableView makeViewWithIdentifier:cid owner:self];
    if (cell == nil) {
        cell = [[NSTableCellView alloc] initWithFrame:NSMakeRect(0, 0, tableColumn.width, 24)];
        NSTextField *tf = [[NSTextField alloc] initWithFrame:NSMakeRect(4, 3, tableColumn.width - 8, 18)];
        tf.bezeled = NO; tf.drawsBackground = NO; tf.editable = NO; tf.selectable = NO;
        tf.lineBreakMode = NSLineBreakByTruncatingMiddle;
        tf.autoresizingMask = NSViewWidthSizable;
        [cell addSubview:tf];
        cell.textField = tf;
        cell.identifier = cid;
    }

    if ([cid isEqualToString:kColTitle]) {
        cell.textField.stringValue = item.title ?: @"";
        cell.textField.textColor = [NSColor labelColor];
        cell.textField.alignment = NSTextAlignmentLeft;
    } else if ([cid isEqualToString:kColDetail]) {
        cell.textField.stringValue = item.detail ?: @"";
        cell.textField.textColor = [NSColor secondaryLabelColor];
        cell.textField.alignment = NSTextAlignmentLeft;
    } else if ([cid isEqualToString:kColSize]) {
        cell.textField.stringValue = [self humanSize:item.sizeBytes];
        cell.textField.textColor = [NSColor labelColor];
        cell.textField.alignment = NSTextAlignmentRight;
    } else if ([cid isEqualToString:kColSafety]) {
        cell.textField.stringValue = item.safetyLabel;
        cell.textField.textColor = [self colorForSafety:item.safety];
        cell.textField.alignment = NSTextAlignmentLeft;
    }
    return cell;
}

- (NSColor *)colorForSafety:(FUSafetyLevel)safety {
    switch (safety) {
        case FUSafetyLevelSafe:    return [NSColor systemGreenColor];
        case FUSafetyLevelMedium:  return [NSColor systemOrangeColor];
        case FUSafetyLevelCaution: return [NSColor systemRedColor];
    }
    return [NSColor labelColor];
}

#pragma mark - Actions

- (void)onToggle:(NSButton *)sender {
    for (NSTableView *t in @[self.junkTable, self.runtimeTable, self.largeTable]) {
        NSInteger row = [t rowForView:sender];
        if (row >= 0) {
            NSArray<FUCleanItem *> *items = [self itemsForTable:t];
            if (row < (NSInteger)items.count) {
                items[row].selected = (sender.state == NSControlStateValueOn);
            }
            break;
        }
    }
    [self updateReclaimStatus];
}

- (void)onRevealLargeFile:(id)sender {
    NSInteger row = self.largeTable.clickedRow;
    if (row < 0 || row >= (NSInteger)self.largeItems.count) { return; }
    NSString *path = self.largeItems[row].paths.firstObject;
    if (path.length) {
        [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[[NSURL fileURLWithPath:path]]];
    }
}

- (void)onScan:(id)sender {
    if (self.busy) { return; }
    [self setBusy:YES status:@"正在扫描…（首次扫描大文件可能耗时较久）"];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSArray *junk = [self.scanner scanJunkCategories];
        NSArray *runtimes = [self.scanner scanSimulatorRuntimes];
        NSArray *large = [self.scanner scanLargeFilesWithMinBytes:(500LL * 1024 * 1024)];

        dispatch_async(dispatch_get_main_queue(), ^{
            [self.junkItems setArray:junk];
            [self.runtimeItems setArray:runtimes];
            [self.largeItems setArray:large];
            [self.junkTable reloadData];
            [self.runtimeTable reloadData];
            [self.largeTable reloadData];
            [self refreshDiskUsage];
            [self setBusy:NO status:nil];
            [self updateReclaimStatus];
        });
    });
}

- (void)onClean:(id)sender {
    if (self.busy) { return; }
    NSArray<FUCleanItem *> *selected = [self selectedItems];
    if (selected.count == 0) {
        self.statusLabel.stringValue = @"没有勾选任何项目";
        return;
    }

    long long total = 0;
    NSMutableString *list = [NSMutableString string];
    for (FUCleanItem *it in selected) {
        total += it.sizeBytes;
        [list appendFormat:@"• %@  (%@)\n", it.title, [self humanSize:it.sizeBytes]];
    }

    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = [NSString stringWithFormat:@"确认清理 %lu 项，预计释放 %@？",
                         (unsigned long)selected.count, [self humanSize:total]];
    alert.informativeText = [NSString stringWithFormat:
                             @"%@\n注意：缓存类为彻底删除，大文件移到废纸篓（可恢复）。此操作不可撤销。",
                             list];
    [alert addButtonWithTitle:@"清理"];
    [alert addButtonWithTitle:@"取消"];
    alert.alertStyle = NSAlertStyleWarning;
    if ([alert runModal] != NSAlertFirstButtonReturn) { return; }

    [self setBusy:YES status:@"正在清理…"];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSMutableArray<NSString *> *log = [NSMutableArray array];
        FUCleaner *cleaner = [[FUCleaner alloc] init];
        long long freed = [cleaner cleanItems:selected log:log];

        dispatch_async(dispatch_get_main_queue(), ^{
            [self setBusy:NO status:[NSString stringWithFormat:@"清理完成，本次释放约 %@",
                                     [self humanSize:freed]]];
            [self showCleanLog:log freed:freed];
            [self onScan:nil]; // re-scan to refresh sizes & disk usage
        });
    });
}

- (void)showCleanLog:(NSArray<NSString *> *)log freed:(long long)freed {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = [NSString stringWithFormat:@"清理完成 — 释放约 %@", [self humanSize:freed]];
    alert.informativeText = [log componentsJoinedByString:@"\n"];
    [alert addButtonWithTitle:@"好"];
    [alert runModal];
}

#pragma mark - Selection / status

- (NSArray<FUCleanItem *> *)selectedItems {
    NSMutableArray<FUCleanItem *> *out = [NSMutableArray array];
    for (NSArray<FUCleanItem *> *arr in @[self.junkItems, self.runtimeItems, self.largeItems]) {
        for (FUCleanItem *it in arr) {
            if (it.selected) { [out addObject:it]; }
        }
    }
    return out;
}

- (void)updateReclaimStatus {
    if (self.busy) { return; }
    long long total = 0;
    NSUInteger count = 0;
    for (FUCleanItem *it in [self selectedItems]) { total += it.sizeBytes; count++; }
    if (count == 0) {
        self.statusLabel.stringValue = @"勾选要清理的项目";
    } else {
        self.statusLabel.stringValue = [NSString stringWithFormat:@"已选 %lu 项，预计释放 %@",
                                        (unsigned long)count, [self humanSize:total]];
    }
}

- (void)setBusy:(BOOL)busy status:(NSString *)status {
    self.busy = busy;
    self.scanButton.enabled = !busy;
    self.cleanButton.enabled = !busy;
    if (busy) { [self.spinner startAnimation:nil]; } else { [self.spinner stopAnimation:nil]; }
    if (status) { self.statusLabel.stringValue = status; }
}

#pragma mark - Disk usage

- (void)refreshDiskUsage {
    long long total = [FUShell totalDiskBytes];
    long long free = [FUShell freeDiskBytes];
    long long used = MAX(0, total - free);
    self.diskLabel.stringValue = [NSString stringWithFormat:@"磁盘：可用 %@ / 共 %@（已用 %@）",
                                  [self humanSize:free], [self humanSize:total], [self humanSize:used]];
    self.diskBar.doubleValue = total > 0 ? (double)used / (double)total : 0;
}

#pragma mark - Formatting

- (NSString *)humanSize:(long long)bytes {
    return [NSByteCountFormatter stringFromByteCount:bytes countStyle:NSByteCountFormatterCountStyleFile];
}

@end
