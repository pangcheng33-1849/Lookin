//
//  LKRequirementBindingStore.m
//  Lookin
//
//  Created by Codex on 2026/2/23.
//

#import "LKRequirementBindingStore.h"
#import "LKMCPError.h"
#import "LKMCPNotifications.h"
@import AppKit;

static NSString * const LKMCPBindingsPersistencePrefix = @"mcp_requirement_bindings_";
static NSString * const LKMCPBindingsPayloadSavedAtKey = @"savedAtMs";
static NSString * const LKMCPBindingsPayloadRecordsKey = @"records";

static NSString * const LKMCPBindingFieldRequirementId = @"requirementId";
static NSString * const LKMCPBindingFieldDescription = @"description";
static NSString * const LKMCPBindingFieldBindings = @"bindings";

@class LKMCPRequirementBindingBoardController;

@interface LKRequirementBindingStore ()

@property(nonatomic, strong) NSMutableDictionary<NSString *, NSArray<NSDictionary<NSString *, NSString *> *> *> *memoryStore;
@property(nonatomic, strong) LKMCPRequirementBindingBoardController *bindingBoardController;

@end

@interface LKMCPRequirementBindingBoardController : NSWindowController <NSTableViewDataSource, NSTableViewDelegate, NSWindowDelegate>

- (instancetype)initWithStore:(LKRequirementBindingStore *)store;
- (void)showBoardForSessionId:(NSString *)sessionId;

@end

@implementation LKRequirementBindingStore

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    static LKRequirementBindingStore *instance = nil;
    dispatch_once(&onceToken,^{
        instance = [[super allocWithZone:NULL] init];
    });
    return instance;
}

+ (id)allocWithZone:(struct _NSZone *)zone {
    return [self sharedInstance];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _memoryStore = [NSMutableDictionary dictionary];
        _ttlMode = LKMCPBindingTTLModeSessionOnly;
    }
    return self;
}

- (NSArray<NSDictionary<NSString *,NSString *> *> *)recordsForSessionId:(NSString *)sessionId {
    [self cleanupExpiredRecords];
    NSArray<NSDictionary<NSString *, NSString *> *> *records = self.memoryStore[sessionId];
    if (records) {
        return records.copy;
    }

    if (self.ttlMode == LKMCPBindingTTLModeSessionOnly) {
        return @[];
    }

    NSDictionary *payload = [[NSUserDefaults standardUserDefaults] objectForKey:[self _persistedKeyForSessionId:sessionId]];
    if (![payload isKindOfClass:[NSDictionary class]]) {
        return @[];
    }

    NSArray *persistedRecords = payload[LKMCPBindingsPayloadRecordsKey];
    if (![persistedRecords isKindOfClass:[NSArray class]]) {
        return @[];
    }

    NSArray<NSDictionary<NSString *, NSString *> *> *normalized = [self _normalizeRecordsArray:persistedRecords];
    self.memoryStore[sessionId] = normalized;
    return normalized.copy;
}

- (void)saveRecords:(NSArray<NSDictionary<NSString *,NSString *> *> *)records sessionId:(NSString *)sessionId {
    NSArray<NSDictionary<NSString *, NSString *> *> *normalized = [self _normalizeRecordsArray:records];
    self.memoryStore[sessionId] = normalized;

    NSString *persistedKey = [self _persistedKeyForSessionId:sessionId];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (self.ttlMode == LKMCPBindingTTLModeSessionOnly) {
        [defaults removeObjectForKey:persistedKey];
        return;
    }

    NSDictionary *payload = @{
        LKMCPBindingsPayloadSavedAtKey: [LKMCPError currentTimestampMs],
        LKMCPBindingsPayloadRecordsKey: normalized
    };
    [defaults setObject:payload forKey:persistedKey];
}

- (void)removeRecordsForSessionId:(NSString *)sessionId {
    [self.memoryStore removeObjectForKey:sessionId];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:[self _persistedKeyForSessionId:sessionId]];
}

- (void)cleanupExpiredRecords {
    if (self.ttlMode == LKMCPBindingTTLModeSessionOnly) {
        return;
    }
    NSTimeInterval ttlSeconds = [self _ttlSeconds];
    if (ttlSeconds <= 0) {
        return;
    }

    long long nowMs = [LKMCPError currentTimestampMs].longLongValue;
    NSDictionary<NSString *, id> *allDefaults = [[NSUserDefaults standardUserDefaults] dictionaryRepresentation];
    [allDefaults enumerateKeysAndObjectsUsingBlock:^(NSString *key, id obj, BOOL *stop) {
        if (![key hasPrefix:LKMCPBindingsPersistencePrefix]) {
            return;
        }
        NSDictionary *payload = [obj isKindOfClass:[NSDictionary class]] ? (NSDictionary *)obj : nil;
        NSNumber *savedAt = [payload[LKMCPBindingsPayloadSavedAtKey] isKindOfClass:[NSNumber class]] ? payload[LKMCPBindingsPayloadSavedAtKey] : nil;
        if (!savedAt) {
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
            return;
        }
        long long elapsedMs = nowMs - savedAt.longLongValue;
        if (elapsedMs > (long long)(ttlSeconds * 1000.0)) {
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
            NSString *sessionId = [key substringFromIndex:LKMCPBindingsPersistencePrefix.length];
            [self.memoryStore removeObjectForKey:sessionId];
        }
    }];
}

- (void)showRequirementBindingBoardForSessionId:(NSString *)sessionId {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.bindingBoardController) {
            self.bindingBoardController = [[LKMCPRequirementBindingBoardController alloc] initWithStore:self];
        }
        [self.bindingBoardController showBoardForSessionId:sessionId ?: @""];
    });
}

- (NSString *)_persistedKeyForSessionId:(NSString *)sessionId {
    return [LKMCPBindingsPersistencePrefix stringByAppendingString:sessionId];
}

- (NSTimeInterval)_ttlSeconds {
    switch (self.ttlMode) {
        case LKMCPBindingTTLMode1Hour:
            return 3600;
        case LKMCPBindingTTLMode1Day:
            return 24 * 3600;
        case LKMCPBindingTTLModeSessionOnly:
        default:
            return 0;
    }
}

- (NSArray<NSDictionary<NSString *, NSString *> *> *)_normalizeRecordsArray:(NSArray *)records {
    NSMutableArray<NSDictionary<NSString *, NSString *> *> *result = [NSMutableArray array];
    [records enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSDictionary *raw = [obj isKindOfClass:[NSDictionary class]] ? (NSDictionary *)obj : nil;
        if (!raw) {
            return;
        }
        NSString *rid = [raw[LKMCPBindingFieldRequirementId] isKindOfClass:[NSString class]] ? raw[LKMCPBindingFieldRequirementId] : @"";
        NSString *desc = [raw[LKMCPBindingFieldDescription] isKindOfClass:[NSString class]] ? raw[LKMCPBindingFieldDescription] : @"";
        NSString *bindings = [raw[LKMCPBindingFieldBindings] isKindOfClass:[NSString class]] ? raw[LKMCPBindingFieldBindings] : @"";
        if (rid.length == 0) {
            return;
        }
        [result addObject:@{
            LKMCPBindingFieldRequirementId: rid,
            LKMCPBindingFieldDescription: desc,
            LKMCPBindingFieldBindings: bindings
        }];
    }];
    return result.copy;
}

@end

@interface LKMCPRequirementBindingBoardController ()

@property(nonatomic, weak) LKRequirementBindingStore *store;
@property(nonatomic, copy) NSString *sessionId;

@property(nonatomic, strong) NSView *topBar;
@property(nonatomic, strong) NSButton *addButton;
@property(nonatomic, strong) NSButton *deleteButton;
@property(nonatomic, strong) NSButton *applyButton;
@property(nonatomic, strong) NSButton *reloadButton;
@property(nonatomic, strong) NSButton *saveButton;
@property(nonatomic, strong) NSTextField *sessionLabel;
@property(nonatomic, strong) NSTextField *statusLabel;

@property(nonatomic, strong) NSScrollView *tableScrollView;
@property(nonatomic, strong) NSTableView *tableView;

@property(nonatomic, strong) NSView *editorPanel;
@property(nonatomic, strong) NSTextField *requirementLabel;
@property(nonatomic, strong) NSTextField *requirementField;
@property(nonatomic, strong) NSTextField *descriptionLabel;
@property(nonatomic, strong) NSTextField *descriptionField;
@property(nonatomic, strong) NSTextField *bindingsLabel;
@property(nonatomic, strong) NSScrollView *bindingsScrollView;
@property(nonatomic, strong) NSTextView *bindingsTextView;

@property(nonatomic, strong) NSMutableArray<NSMutableDictionary<NSString *, NSString *> *> *draftRecords;
@property(nonatomic, assign) NSInteger editingRow;

@end

@implementation LKMCPRequirementBindingBoardController

- (instancetype)initWithStore:(LKRequirementBindingStore *)store {
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 980, 620)
                                                   styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable | NSWindowStyleMaskMiniaturizable
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    window.minSize = NSMakeSize(860, 520);
    window.title = NSLocalizedString(@"Requirement Binding Items", nil);

    self = [super initWithWindow:window];
    if (self) {
        _store = store;
        _draftRecords = [NSMutableArray array];
        _editingRow = NSNotFound;

        [self _buildViews];
        [self _layoutViews];
        self.window.delegate = self;

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(_handleBindingChangedNotification:)
                                                     name:NotificationName_RequirementBindingDidChange
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)showBoardForSessionId:(NSString *)sessionId {
    self.sessionId = sessionId ?: @"";
    [self _setStatus:@""];
    [self _reloadFromStore];
    [self _updateSessionLabel];

    [self showWindow:nil];
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

- (void)windowDidResize:(NSNotification *)notification {
    [self _layoutViews];
}

- (void)_handleBindingChangedNotification:(NSNotification *)notification {
    NSString *eventSessionId = [notification.userInfo[LKMCPRequirementBindingChangedSessionIdKey] isKindOfClass:[NSString class]] ? notification.userInfo[LKMCPRequirementBindingChangedSessionIdKey] : @"";
    if (self.sessionId.length == 0 || eventSessionId.length == 0 || ![eventSessionId isEqualToString:self.sessionId]) {
        return;
    }
    [self _reloadFromStore];
}

- (void)_buildViews {
    NSView *contentView = self.window.contentView;

    self.topBar = [NSView new];
    [contentView addSubview:self.topBar];

    self.addButton = [self _makeButtonWithTitle:NSLocalizedString(@"Add", nil) action:@selector(_handleAdd:)];
    self.deleteButton = [self _makeButtonWithTitle:NSLocalizedString(@"Delete", nil) action:@selector(_handleDelete:)];
    self.applyButton = [self _makeButtonWithTitle:NSLocalizedString(@"Apply Row", nil) action:@selector(_handleApply:)];
    self.reloadButton = [self _makeButtonWithTitle:NSLocalizedString(@"Reload", nil) action:@selector(_handleReload:)];
    self.saveButton = [self _makeButtonWithTitle:NSLocalizedString(@"Save All", nil) action:@selector(_handleSave:)];
    [self.topBar addSubview:self.addButton];
    [self.topBar addSubview:self.deleteButton];
    [self.topBar addSubview:self.applyButton];
    [self.topBar addSubview:self.reloadButton];
    [self.topBar addSubview:self.saveButton];

    self.sessionLabel = [NSTextField labelWithString:@""];
    self.sessionLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    self.sessionLabel.textColor = [NSColor secondaryLabelColor];
    self.sessionLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    [self.topBar addSubview:self.sessionLabel];

    self.statusLabel = [NSTextField labelWithString:@""];
    self.statusLabel.font = [NSFont systemFontOfSize:12];
    self.statusLabel.textColor = [NSColor secondaryLabelColor];
    self.statusLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.topBar addSubview:self.statusLabel];

    self.tableView = [NSTableView new];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.usesAlternatingRowBackgroundColors = YES;
    self.tableView.rowHeight = 26;
    self.tableView.headerView = [NSTableHeaderView new];

    NSTableColumn *ridColumn = [[NSTableColumn alloc] initWithIdentifier:LKMCPBindingFieldRequirementId];
    ridColumn.title = NSLocalizedString(@"Requirement ID", nil);
    ridColumn.width = 130;
    [self.tableView addTableColumn:ridColumn];

    NSTableColumn *descColumn = [[NSTableColumn alloc] initWithIdentifier:LKMCPBindingFieldDescription];
    descColumn.title = NSLocalizedString(@"Description", nil);
    descColumn.width = 210;
    [self.tableView addTableColumn:descColumn];

    NSTableColumn *bindingsColumn = [[NSTableColumn alloc] initWithIdentifier:LKMCPBindingFieldBindings];
    bindingsColumn.title = NSLocalizedString(@"Bindings", nil);
    bindingsColumn.width = 280;
    [self.tableView addTableColumn:bindingsColumn];

    self.tableScrollView = [NSScrollView new];
    self.tableScrollView.hasVerticalScroller = YES;
    self.tableScrollView.hasHorizontalScroller = YES;
    self.tableScrollView.borderType = NSBezelBorder;
    self.tableScrollView.documentView = self.tableView;
    [contentView addSubview:self.tableScrollView];

    self.editorPanel = [NSView new];
    [contentView addSubview:self.editorPanel];

    self.requirementLabel = [NSTextField labelWithString:NSLocalizedString(@"Requirement ID", nil)];
    self.requirementLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightSemibold];
    [self.editorPanel addSubview:self.requirementLabel];

    self.requirementField = [NSTextField new];
    [self.editorPanel addSubview:self.requirementField];

    self.descriptionLabel = [NSTextField labelWithString:NSLocalizedString(@"Description", nil)];
    self.descriptionLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightSemibold];
    [self.editorPanel addSubview:self.descriptionLabel];

    self.descriptionField = [NSTextField new];
    [self.editorPanel addSubview:self.descriptionField];

    self.bindingsLabel = [NSTextField labelWithString:NSLocalizedString(@"Bindings", nil)];
    self.bindingsLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightSemibold];
    [self.editorPanel addSubview:self.bindingsLabel];

    self.bindingsScrollView = [NSScrollView new];
    self.bindingsScrollView.hasVerticalScroller = YES;
    self.bindingsScrollView.borderType = NSBezelBorder;
    self.bindingsTextView = [NSTextView new];
    self.bindingsTextView.richText = NO;
    self.bindingsTextView.usesFindPanel = YES;
    self.bindingsTextView.font = [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular];
    self.bindingsScrollView.documentView = self.bindingsTextView;
    [self.editorPanel addSubview:self.bindingsScrollView];
}

- (void)_layoutViews {
    NSView *contentView = self.window.contentView;
    if (!contentView) {
        return;
    }

    CGFloat margin = 12;
    CGFloat topBarHeight = 34;
    CGFloat topBarWidth = contentView.bounds.size.width - margin * 2;
    CGFloat topBarY = contentView.bounds.size.height - margin - topBarHeight;
    self.topBar.frame = NSMakeRect(margin, topBarY, topBarWidth, topBarHeight);

    __block CGFloat buttonX = 0;
    CGFloat buttonWidth = 92;
    CGFloat buttonHeight = 28;
    NSArray<NSButton *> *buttons = @[self.addButton, self.deleteButton, self.applyButton, self.reloadButton, self.saveButton];
    [buttons enumerateObjectsUsingBlock:^(NSButton *obj, NSUInteger idx, BOOL *stop) {
        obj.frame = NSMakeRect(buttonX, (topBarHeight - buttonHeight) / 2.0, buttonWidth, buttonHeight);
        buttonX += buttonWidth + 8;
    }];

    CGFloat statusWidth = 220;
    self.statusLabel.frame = NSMakeRect(topBarWidth - statusWidth, 0, statusWidth, topBarHeight);

    CGFloat sessionX = CGRectGetMaxX(self.saveButton.frame) + 16;
    CGFloat sessionWidth = MAX(0, topBarWidth - sessionX - statusWidth - 12);
    self.sessionLabel.frame = NSMakeRect(sessionX, 0, sessionWidth, topBarHeight);

    CGFloat contentBottom = margin;
    CGFloat contentTop = topBarY - margin;
    CGFloat contentHeight = contentTop - contentBottom;

    CGFloat tableWidth = 620;
    self.tableScrollView.frame = NSMakeRect(margin, contentBottom, tableWidth, contentHeight);

    CGFloat editorX = CGRectGetMaxX(self.tableScrollView.frame) + margin;
    CGFloat editorWidth = contentView.bounds.size.width - editorX - margin;
    self.editorPanel.frame = NSMakeRect(editorX, contentBottom, editorWidth, contentHeight);

    CGFloat editorMargin = 8;
    CGFloat lineHeight = 22;
    CGFloat y = self.editorPanel.bounds.size.height - editorMargin - lineHeight;

    self.requirementLabel.frame = NSMakeRect(editorMargin, y, editorWidth - editorMargin * 2, lineHeight);
    y -= (lineHeight + 6);
    self.requirementField.frame = NSMakeRect(editorMargin, y, editorWidth - editorMargin * 2, lineHeight + 2);

    y -= (lineHeight + 14);
    self.descriptionLabel.frame = NSMakeRect(editorMargin, y, editorWidth - editorMargin * 2, lineHeight);
    y -= (lineHeight + 6);
    self.descriptionField.frame = NSMakeRect(editorMargin, y, editorWidth - editorMargin * 2, lineHeight + 2);

    y -= (lineHeight + 14);
    self.bindingsLabel.frame = NSMakeRect(editorMargin, y, editorWidth - editorMargin * 2, lineHeight);
    y -= (lineHeight + 6);

    CGFloat bindingsHeight = MAX(140, y - editorMargin);
    self.bindingsScrollView.frame = NSMakeRect(editorMargin, editorMargin, editorWidth - editorMargin * 2, bindingsHeight);
}

- (NSButton *)_makeButtonWithTitle:(NSString *)title action:(SEL)action {
    NSButton *button = [NSButton buttonWithTitle:title target:self action:action];
    button.bezelStyle = NSBezelStyleRounded;
    return button;
}

- (void)_updateSessionLabel {
    if (self.sessionId.length > 0) {
        self.sessionLabel.stringValue = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"Session:", nil), self.sessionId];
    } else {
        self.sessionLabel.stringValue = NSLocalizedString(@"Session: (No active app)", nil);
    }
}

- (void)_setStatus:(NSString *)status {
    self.statusLabel.stringValue = status ?: @"";
}

- (void)_showAlertWithMessage:(NSString *)message {
    NSAlert *alert = [NSAlert new];
    alert.messageText = message ?: NSLocalizedString(@"Invalid input.", nil);
    alert.alertStyle = NSAlertStyleWarning;
    [alert beginSheetModalForWindow:self.window completionHandler:nil];
}

- (void)_reloadFromStore {
    NSArray<NSDictionary<NSString *, NSString *> *> *records = self.sessionId.length > 0 ? [self.store recordsForSessionId:self.sessionId] : @[];
    NSMutableArray<NSMutableDictionary<NSString *, NSString *> *> *mutableRecords = [NSMutableArray arrayWithCapacity:records.count];
    [records enumerateObjectsUsingBlock:^(NSDictionary<NSString *,NSString *> *obj, NSUInteger idx, BOOL *stop) {
        [mutableRecords addObject:[@{
            LKMCPBindingFieldRequirementId: obj[LKMCPBindingFieldRequirementId] ?: @"",
            LKMCPBindingFieldDescription: obj[LKMCPBindingFieldDescription] ?: @"",
            LKMCPBindingFieldBindings: obj[LKMCPBindingFieldBindings] ?: @""
        } mutableCopy]];
    }];
    self.draftRecords = mutableRecords;
    self.editingRow = NSNotFound;

    NSInteger preferredRow = self.tableView.selectedRow;
    [self.tableView reloadData];
    NSInteger rowToSelect = NSNotFound;
    if (self.draftRecords.count > 0) {
        rowToSelect = MIN(MAX(0, preferredRow), (NSInteger)self.draftRecords.count - 1);
    }
    if (rowToSelect != NSNotFound) {
        [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)rowToSelect] byExtendingSelection:NO];
    } else {
        [self _clearEditor];
    }
}

- (void)_clearEditor {
    self.requirementField.stringValue = @"";
    self.descriptionField.stringValue = @"";
    self.bindingsTextView.string = @"";
    self.editingRow = NSNotFound;
}

- (void)_populateEditorForSelectedRow {
    NSInteger row = self.tableView.selectedRow;
    if (row < 0 || row >= (NSInteger)self.draftRecords.count) {
        [self _clearEditor];
        return;
    }
    NSDictionary<NSString *, NSString *> *record = self.draftRecords[(NSUInteger)row];
    self.requirementField.stringValue = record[LKMCPBindingFieldRequirementId] ?: @"";
    self.descriptionField.stringValue = record[LKMCPBindingFieldDescription] ?: @"";
    self.bindingsTextView.string = record[LKMCPBindingFieldBindings] ?: @"";
    self.editingRow = row;
}

- (void)_commitEditorToEditingRow {
    if (self.editingRow == NSNotFound || self.editingRow < 0 || self.editingRow >= (NSInteger)self.draftRecords.count) {
        return;
    }
    NSMutableDictionary<NSString *, NSString *> *record = self.draftRecords[(NSUInteger)self.editingRow];
    record[LKMCPBindingFieldRequirementId] = [self.requirementField.stringValue ?: @"" stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    record[LKMCPBindingFieldDescription] = [self.descriptionField.stringValue ?: @"" stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    record[LKMCPBindingFieldBindings] = self.bindingsTextView.string ?: @"";
}

- (nullable NSString *)_validateDraftRecords {
    NSMutableSet<NSString *> *seenIds = [NSMutableSet set];
    __block NSString *errorMessage = nil;
    [self.draftRecords enumerateObjectsUsingBlock:^(NSDictionary<NSString *,NSString *> *record, NSUInteger idx, BOOL *stop) {
        NSString *rid = [record[LKMCPBindingFieldRequirementId] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (rid.length == 0) {
            errorMessage = [NSString stringWithFormat:NSLocalizedString(@"Row %lu: requirementId cannot be empty.", nil), (unsigned long)(idx + 1)];
            *stop = YES;
            return;
        }
        if ([seenIds containsObject:rid]) {
            errorMessage = [NSString stringWithFormat:NSLocalizedString(@"Duplicate requirementId: %@", nil), rid];
            *stop = YES;
            return;
        }
        [seenIds addObject:rid];
    }];
    return errorMessage;
}

- (NSArray<NSDictionary<NSString *, NSString *> *> *)_normalizedDraftRecords {
    NSMutableArray<NSDictionary<NSString *, NSString *> *> *result = [NSMutableArray arrayWithCapacity:self.draftRecords.count];
    [self.draftRecords enumerateObjectsUsingBlock:^(NSDictionary<NSString *,NSString *> *record, NSUInteger idx, BOOL *stop) {
        [result addObject:@{
            LKMCPBindingFieldRequirementId: [record[LKMCPBindingFieldRequirementId] isKindOfClass:[NSString class]] ? record[LKMCPBindingFieldRequirementId] : @"",
            LKMCPBindingFieldDescription: [record[LKMCPBindingFieldDescription] isKindOfClass:[NSString class]] ? record[LKMCPBindingFieldDescription] : @"",
            LKMCPBindingFieldBindings: [record[LKMCPBindingFieldBindings] isKindOfClass:[NSString class]] ? record[LKMCPBindingFieldBindings] : @""
        }];
    }];
    return result.copy;
}

- (void)_handleAdd:(id)sender {
    [self _commitEditorToEditingRow];
    [self.draftRecords addObject:[@{
        LKMCPBindingFieldRequirementId: @"",
        LKMCPBindingFieldDescription: @"",
        LKMCPBindingFieldBindings: @""
    } mutableCopy]];
    [self.tableView reloadData];
    NSInteger newRow = (NSInteger)self.draftRecords.count - 1;
    [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)newRow] byExtendingSelection:NO];
    [self _setStatus:NSLocalizedString(@"Added a new row.", nil)];
}

- (void)_handleDelete:(id)sender {
    NSInteger row = self.tableView.selectedRow;
    if (row < 0 || row >= (NSInteger)self.draftRecords.count) {
        return;
    }
    [self.draftRecords removeObjectAtIndex:(NSUInteger)row];
    [self.tableView reloadData];
    if (self.draftRecords.count > 0) {
        NSInteger nextRow = MIN(row, (NSInteger)self.draftRecords.count - 1);
        [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)nextRow] byExtendingSelection:NO];
    } else {
        [self _clearEditor];
    }
    [self _setStatus:NSLocalizedString(@"Deleted selected row.", nil)];
}

- (void)_handleApply:(id)sender {
    [self _commitEditorToEditingRow];
    NSInteger row = self.tableView.selectedRow;
    if (row >= 0 && row < (NSInteger)self.draftRecords.count) {
        NSIndexSet *rows = [NSIndexSet indexSetWithIndex:(NSUInteger)row];
        NSIndexSet *columns = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, self.tableView.tableColumns.count)];
        [self.tableView reloadDataForRowIndexes:rows columnIndexes:columns];
    }
    [self _setStatus:NSLocalizedString(@"Applied current row changes.", nil)];
}

- (void)_handleReload:(id)sender {
    [self _reloadFromStore];
    [self _setStatus:NSLocalizedString(@"Reloaded from store.", nil)];
}

- (void)_handleSave:(id)sender {
    if (self.sessionId.length == 0) {
        [self _showAlertWithMessage:NSLocalizedString(@"No active session. Please connect an app first.", nil)];
        return;
    }
    [self _commitEditorToEditingRow];
    NSString *errorMessage = [self _validateDraftRecords];
    if (errorMessage.length > 0) {
        [self _showAlertWithMessage:errorMessage];
        return;
    }

    NSArray<NSDictionary<NSString *, NSString *> *> *normalized = [self _normalizedDraftRecords];
    [self.store saveRecords:normalized sessionId:self.sessionId];

    [[NSNotificationCenter defaultCenter] postNotificationName:NotificationName_RequirementBindingDidChange
                                                        object:nil
                                                      userInfo:@{
        LKMCPRequirementBindingChangedSessionIdKey: self.sessionId ?: @"",
        LKMCPRequirementBindingChangedOperationKey: @"edit"
    }];
    [self _setStatus:NSLocalizedString(@"Saved.", nil)];
    [self _reloadFromStore];
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.draftRecords.count;
}

#pragma mark - NSTableViewDelegate

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (row < 0 || row >= (NSInteger)self.draftRecords.count) {
        return nil;
    }
    NSDictionary<NSString *, NSString *> *record = self.draftRecords[(NSUInteger)row];
    NSString *columnID = tableColumn.identifier;

    NSTableCellView *cellView = [tableView makeViewWithIdentifier:columnID owner:self];
    if (!cellView) {
        cellView = [[NSTableCellView alloc] initWithFrame:NSMakeRect(0, 0, tableColumn.width, tableView.rowHeight)];
        cellView.identifier = columnID;
        NSTextField *textField = [NSTextField labelWithString:@""];
        textField.frame = NSMakeRect(6, 3, tableColumn.width - 12, tableView.rowHeight - 6);
        textField.lineBreakMode = NSLineBreakByTruncatingTail;
        textField.autoresizingMask = NSViewWidthSizable;
        cellView.textField = textField;
        [cellView addSubview:textField];
    }
    cellView.textField.stringValue = record[columnID] ?: @"";
    return cellView;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    [self _commitEditorToEditingRow];
    [self _populateEditorForSelectedRow];
}

@end
