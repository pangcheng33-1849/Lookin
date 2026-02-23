//
//  LKMCPRequirementCodeInfoBoardController.m
//  Lookin
//
//  Created by Codex on 2026/2/23.
//

#import "LKMCPRequirementCodeInfoBoardController.h"
#import "LKRequirementBindingStore.h"
#import "LKMCPError.h"
#import "LKMCPNotifications.h"

static NSString * const LKMCPCodeInfoFieldRequirementId = @"requirementId";
static NSString * const LKMCPCodeInfoFieldDescription = @"description";
static NSString * const LKMCPCodeInfoFieldCodeInfo = @"codeInfo";

@interface LKMCPRequirementCodeInfoRowView : NSTableRowView

@property(nonatomic, assign) BOOL rowValid;

@end

@implementation LKMCPRequirementCodeInfoRowView

- (void)setRowValid:(BOOL)rowValid {
    if (_rowValid == rowValid) {
        return;
    }
    _rowValid = rowValid;
    [self setNeedsDisplay:YES];
}

- (void)drawBackgroundInRect:(NSRect)dirtyRect {
    NSColor *backgroundColor = self.rowValid
        ? [NSColor colorWithRed:0.16 green:0.62 blue:0.24 alpha:0.10]
        : [NSColor colorWithRed:0.78 green:0.25 blue:0.22 alpha:0.14];
    [backgroundColor setFill];
    NSRectFill(dirtyRect);
}

@end

@interface LKMCPRequirementCodeInfoBoardController () <NSTableViewDataSource, NSTableViewDelegate, NSWindowDelegate, NSTextFieldDelegate, NSTextViewDelegate>

@property(nonatomic, weak) LKRequirementCodeInfoStore *store;
@property(nonatomic, copy) NSString *sessionId;

@property(nonatomic, strong) NSView *topBar;
@property(nonatomic, strong) NSButton *addButton;
@property(nonatomic, strong) NSButton *deleteButton;
@property(nonatomic, strong) NSButton *reloadButton;
@property(nonatomic, strong) NSTextField *sessionLabel;
@property(nonatomic, strong) NSTextField *statusLabel;

@property(nonatomic, strong) NSScrollView *tableScrollView;
@property(nonatomic, strong) NSTableView *tableView;

@property(nonatomic, strong) NSView *editorPanel;
@property(nonatomic, strong) NSTextField *requirementLabel;
@property(nonatomic, strong) NSTextField *requirementField;
@property(nonatomic, strong) NSTextField *descriptionLabel;
@property(nonatomic, strong) NSTextField *descriptionField;
@property(nonatomic, strong) NSTextField *codeInfoLabel;
@property(nonatomic, strong) NSScrollView *codeInfoScrollView;
@property(nonatomic, strong) NSTextView *codeInfoTextView;

@property(nonatomic, strong) NSMutableArray<NSMutableDictionary<NSString *, NSString *> *> *draftRecords;
@property(nonatomic, assign) NSInteger editingRow;
@property(nonatomic, assign) BOOL suppressEditorCallbacks;

@end

@implementation LKMCPRequirementCodeInfoBoardController

- (instancetype)initWithStore:(LKRequirementCodeInfoStore *)store {
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 980, 620)
                                                   styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable | NSWindowStyleMaskMiniaturizable
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    window.minSize = NSMakeSize(860, 520);
    window.title = NSLocalizedString(@"Code Info Items", nil);

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
                                                     name:NotificationName_RequirementCodeInfoDidChange
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
    if (notification.object == self) {
        return;
    }
    NSString *eventSessionId = [notification.userInfo[LKMCPRequirementCodeInfoChangedSessionIdKey] isKindOfClass:[NSString class]] ? notification.userInfo[LKMCPRequirementCodeInfoChangedSessionIdKey] : @"";
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
    self.reloadButton = [self _makeButtonWithTitle:NSLocalizedString(@"Reload", nil) action:@selector(_handleReload:)];
    [self.topBar addSubview:self.addButton];
    [self.topBar addSubview:self.deleteButton];
    [self.topBar addSubview:self.reloadButton];

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

    NSTableColumn *ridColumn = [[NSTableColumn alloc] initWithIdentifier:LKMCPCodeInfoFieldRequirementId];
    ridColumn.title = NSLocalizedString(@"Requirement ID", nil);
    ridColumn.width = 130;
    [self.tableView addTableColumn:ridColumn];

    NSTableColumn *descColumn = [[NSTableColumn alloc] initWithIdentifier:LKMCPCodeInfoFieldDescription];
    descColumn.title = NSLocalizedString(@"Description", nil);
    descColumn.width = 210;
    [self.tableView addTableColumn:descColumn];

    NSTableColumn *codeInfoColumn = [[NSTableColumn alloc] initWithIdentifier:LKMCPCodeInfoFieldCodeInfo];
    codeInfoColumn.title = NSLocalizedString(@"Code Info", nil);
    codeInfoColumn.width = 280;
    [self.tableView addTableColumn:codeInfoColumn];

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
    self.requirementField.editable = NO;
    self.requirementField.selectable = YES;
    self.requirementField.textColor = [NSColor secondaryLabelColor];
    [self.editorPanel addSubview:self.requirementField];

    self.descriptionLabel = [NSTextField labelWithString:NSLocalizedString(@"Description", nil)];
    self.descriptionLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightSemibold];
    [self.editorPanel addSubview:self.descriptionLabel];

    self.descriptionField = [NSTextField new];
    self.descriptionField.delegate = self;
    [self.editorPanel addSubview:self.descriptionField];

    self.codeInfoLabel = [NSTextField labelWithString:NSLocalizedString(@"Code Info", nil)];
    self.codeInfoLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightSemibold];
    [self.editorPanel addSubview:self.codeInfoLabel];

    self.codeInfoScrollView = [NSScrollView new];
    self.codeInfoScrollView.hasVerticalScroller = YES;
    self.codeInfoScrollView.borderType = NSBezelBorder;
    self.codeInfoTextView = [NSTextView new];
    self.codeInfoTextView.richText = NO;
    self.codeInfoTextView.usesFindPanel = YES;
    self.codeInfoTextView.font = [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular];
    self.codeInfoTextView.delegate = self;
    self.codeInfoScrollView.documentView = self.codeInfoTextView;
    [self.editorPanel addSubview:self.codeInfoScrollView];
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
    NSArray<NSButton *> *buttons = @[self.addButton, self.deleteButton, self.reloadButton];
    [buttons enumerateObjectsUsingBlock:^(NSButton *obj, NSUInteger idx, BOOL *stop) {
        obj.frame = NSMakeRect(buttonX, (topBarHeight - buttonHeight) / 2.0, buttonWidth, buttonHeight);
        buttonX += buttonWidth + 8;
    }];

    CGFloat statusWidth = 220;
    self.statusLabel.frame = NSMakeRect(topBarWidth - statusWidth, 0, statusWidth, topBarHeight);

    NSButton *lastButton = buttons.lastObject;
    CGFloat sessionX = CGRectGetMaxX(lastButton.frame) + 16;
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
    self.codeInfoLabel.frame = NSMakeRect(editorMargin, y, editorWidth - editorMargin * 2, lineHeight);
    y -= (lineHeight + 6);

    CGFloat codeInfoHeight = MAX(140, y - editorMargin);
    self.codeInfoScrollView.frame = NSMakeRect(editorMargin, editorMargin, editorWidth - editorMargin * 2, codeInfoHeight);
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
            LKMCPCodeInfoFieldRequirementId: obj[LKMCPCodeInfoFieldRequirementId] ?: @"",
            LKMCPCodeInfoFieldDescription: obj[LKMCPCodeInfoFieldDescription] ?: @"",
            LKMCPCodeInfoFieldCodeInfo: obj[LKMCPCodeInfoFieldCodeInfo] ?: @""
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
    self.suppressEditorCallbacks = YES;
    self.requirementField.stringValue = @"";
    self.descriptionField.stringValue = @"";
    self.codeInfoTextView.string = @"";
    self.suppressEditorCallbacks = NO;
    self.editingRow = NSNotFound;
}

- (void)_populateEditorForSelectedRow {
    NSInteger row = self.tableView.selectedRow;
    if (row < 0 || row >= (NSInteger)self.draftRecords.count) {
        [self _clearEditor];
        return;
    }
    NSDictionary<NSString *, NSString *> *record = self.draftRecords[(NSUInteger)row];
    self.suppressEditorCallbacks = YES;
    self.requirementField.stringValue = record[LKMCPCodeInfoFieldRequirementId] ?: @"";
    self.descriptionField.stringValue = record[LKMCPCodeInfoFieldDescription] ?: @"";
    self.codeInfoTextView.string = record[LKMCPCodeInfoFieldCodeInfo] ?: @"";
    self.suppressEditorCallbacks = NO;
    self.editingRow = row;
}

- (void)_commitEditorToEditingRow {
    if (self.editingRow == NSNotFound || self.editingRow < 0 || self.editingRow >= (NSInteger)self.draftRecords.count) {
        return;
    }
    NSMutableDictionary<NSString *, NSString *> *record = self.draftRecords[(NSUInteger)self.editingRow];
    // requirementId is immutable in board UI; keep existing value.
    record[LKMCPCodeInfoFieldDescription] = [self.descriptionField.stringValue ?: @"" stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    record[LKMCPCodeInfoFieldCodeInfo] = self.codeInfoTextView.string ?: @"";
}

- (NSString *)_trimmedRequirementIdFromRecord:(NSDictionary<NSString *, NSString *> *)record {
    NSString *rid = [record[LKMCPCodeInfoFieldRequirementId] isKindOfClass:[NSString class]] ? record[LKMCPCodeInfoFieldRequirementId] : @"";
    return [rid stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (BOOL)_isDraftRecordValidAtRow:(NSInteger)row {
    if (row < 0 || row >= (NSInteger)self.draftRecords.count) {
        return NO;
    }

    NSDictionary<NSString *, NSString *> *record = self.draftRecords[(NSUInteger)row];
    NSString *rid = [self _trimmedRequirementIdFromRecord:record];
    if (rid.length == 0) {
        return NO;
    }

    __block NSUInteger duplicateCount = 0;
    [self.draftRecords enumerateObjectsUsingBlock:^(NSDictionary<NSString *,NSString *> *obj, NSUInteger idx, BOOL *stop) {
        NSString *candidate = [self _trimmedRequirementIdFromRecord:obj];
        if ([candidate isEqualToString:rid]) {
            duplicateCount += 1;
            if (duplicateCount > 1) {
                *stop = YES;
            }
        }
    }];
    return duplicateCount == 1;
}

- (nullable NSString *)_validateDraftRecords {
    NSMutableSet<NSString *> *seenIds = [NSMutableSet set];
    __block NSString *errorMessage = nil;
    [self.draftRecords enumerateObjectsUsingBlock:^(NSDictionary<NSString *,NSString *> *record, NSUInteger idx, BOOL *stop) {
        NSString *rid = [self _trimmedRequirementIdFromRecord:record];
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
            LKMCPCodeInfoFieldRequirementId: [record[LKMCPCodeInfoFieldRequirementId] isKindOfClass:[NSString class]] ? record[LKMCPCodeInfoFieldRequirementId] : @"",
            LKMCPCodeInfoFieldDescription: [record[LKMCPCodeInfoFieldDescription] isKindOfClass:[NSString class]] ? record[LKMCPCodeInfoFieldDescription] : @"",
            LKMCPCodeInfoFieldCodeInfo: [record[LKMCPCodeInfoFieldCodeInfo] isKindOfClass:[NSString class]] ? record[LKMCPCodeInfoFieldCodeInfo] : @""
        }];
    }];
    return result.copy;
}

- (NSString *)_defaultRequirementIdForNewRow {
    NSMutableSet<NSString *> *usedIds = [NSMutableSet set];
    [self.draftRecords enumerateObjectsUsingBlock:^(NSDictionary<NSString *,NSString *> *record, NSUInteger idx, BOOL *stop) {
        NSString *rid = [self _trimmedRequirementIdFromRecord:record];
        if (rid.length > 0) {
            [usedIds addObject:rid];
        }
    }];
    NSInteger sequence = 1;
    while (YES) {
        NSString *candidate = [NSString stringWithFormat:@"requirement_%ld", (long)sequence];
        if (![usedIds containsObject:candidate]) {
            return candidate;
        }
        sequence += 1;
    }
}

- (void)_persistDraftRecordsAndNotifyWithOperation:(NSString *)operation {
    if (self.sessionId.length == 0) {
        return;
    }
    NSArray<NSDictionary<NSString *, NSString *> *> *normalized = [self _normalizedDraftRecords];
    [self.store saveRecords:normalized sessionId:self.sessionId];

    [[NSNotificationCenter defaultCenter] postNotificationName:NotificationName_RequirementCodeInfoDidChange
                                                        object:self
                                                      userInfo:@{
        LKMCPRequirementCodeInfoChangedSessionIdKey: self.sessionId ?: @"",
        LKMCPRequirementCodeInfoChangedOperationKey: operation.length > 0 ? operation : @"edit"
    }];
}

- (void)_handleAdd:(id)sender {
    [self _commitEditorToEditingRow];
    [self.draftRecords addObject:[@{
        LKMCPCodeInfoFieldRequirementId: [self _defaultRequirementIdForNewRow],
        LKMCPCodeInfoFieldDescription: @"",
        LKMCPCodeInfoFieldCodeInfo: @""
    } mutableCopy]];
    [self _persistDraftRecordsAndNotifyWithOperation:@"append"];
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
    [self _persistDraftRecordsAndNotifyWithOperation:@"remove"];
    [self.tableView reloadData];
    if (self.draftRecords.count > 0) {
        NSInteger nextRow = MIN(row, (NSInteger)self.draftRecords.count - 1);
        [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)nextRow] byExtendingSelection:NO];
    } else {
        [self _clearEditor];
    }
    [self _setStatus:NSLocalizedString(@"Deleted selected row.", nil)];
}

- (void)_handleReload:(id)sender {
    [self _reloadFromStore];
    [self _setStatus:NSLocalizedString(@"Reloaded from store.", nil)];
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
    BOOL isValidRow = [self _isDraftRecordValidAtRow:row];
    cellView.textField.stringValue = record[columnID] ?: @"";
    cellView.textField.textColor = isValidRow ? [NSColor labelColor] : [NSColor systemRedColor];
    return cellView;
}

- (NSTableRowView *)tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row {
    static NSString * const rowIdentifier = @"RequirementCodeInfoRowView";
    LKMCPRequirementCodeInfoRowView *rowView = [tableView makeViewWithIdentifier:rowIdentifier owner:self];
    if (!rowView) {
        rowView = [[LKMCPRequirementCodeInfoRowView alloc] initWithFrame:NSMakeRect(0, 0, tableView.bounds.size.width, tableView.rowHeight)];
        rowView.identifier = rowIdentifier;
    }
    rowView.rowValid = [self _isDraftRecordValidAtRow:row];
    return rowView;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    NSInteger previousEditingRow = self.editingRow;
    [self _commitEditorToEditingRow];
    if (previousEditingRow != NSNotFound && previousEditingRow >= 0 && previousEditingRow < (NSInteger)self.draftRecords.count) {
        NSIndexSet *rows = [NSIndexSet indexSetWithIndex:(NSUInteger)previousEditingRow];
        NSIndexSet *columns = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, self.tableView.tableColumns.count)];
        [self.tableView reloadDataForRowIndexes:rows columnIndexes:columns];
    }
    [self _populateEditorForSelectedRow];
}

#pragma mark - NSTextFieldDelegate

- (void)controlTextDidChange:(NSNotification *)notification {
    if (self.suppressEditorCallbacks) {
        return;
    }
    if (notification.object != self.descriptionField) {
        return;
    }
    if (self.editingRow == NSNotFound || self.editingRow < 0 || self.editingRow >= (NSInteger)self.draftRecords.count) {
        return;
    }
    [self _commitEditorToEditingRow];
    [self _persistDraftRecordsAndNotifyWithOperation:@"edit"];
    NSIndexSet *rows = [NSIndexSet indexSetWithIndex:(NSUInteger)self.editingRow];
    NSIndexSet *columns = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, self.tableView.tableColumns.count)];
    [self.tableView reloadDataForRowIndexes:rows columnIndexes:columns];
}

#pragma mark - NSTextViewDelegate

- (void)textDidChange:(NSNotification *)notification {
    if (self.suppressEditorCallbacks) {
        return;
    }
    if (notification.object != self.codeInfoTextView) {
        return;
    }
    if (self.editingRow == NSNotFound || self.editingRow < 0 || self.editingRow >= (NSInteger)self.draftRecords.count) {
        return;
    }
    [self _commitEditorToEditingRow];
    [self _persistDraftRecordsAndNotifyWithOperation:@"edit"];
    NSIndexSet *rows = [NSIndexSet indexSetWithIndex:(NSUInteger)self.editingRow];
    NSIndexSet *columns = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, self.tableView.tableColumns.count)];
    [self.tableView reloadDataForRowIndexes:rows columnIndexes:columns];
}

@end

