#import "Tweak.h"
#import <objc/runtime.h>

#pragma mark - Preferences

static NSString * const kPreferencesDomain = @"com.tako3s.PrintempsPrefs";
static NSString * const kPreferencesChangedNotification = @"com.tako3s.printemps/preferencesChanged";

// Cached so that the layout hooks, which run on every pass, never touch cfprefs.
static BOOL sHideKnob;      // stored under the historical "showKnob" key
static BOOL sHidePrevious;
static BOOL sHideAppIcon;
static BOOL sDebugLogging;

static void PrintempsLoadPreferences(void)
{
	NSUserDefaults *preferences = [[NSUserDefaults alloc] initWithSuiteName:kPreferencesDomain];
	sHideKnob = [preferences boolForKey:@"showKnob"];
	sHidePrevious = [preferences boolForKey:@"hidePrevious"];
	sHideAppIcon = [preferences boolForKey:@"hideAppIcon"];
	sDebugLogging = [preferences boolForKey:@"debugLogging"];
}

static void PrintempsPreferencesChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	PrintempsLoadPreferences();
}

#define PrintempsLog(fmt, ...) \
	do { if (sDebugLogging) PrintempsLogMessage([NSString stringWithFormat:fmt, ##__VA_ARGS__]); } while (0)

// The unified logging tools are hit and miss on a jailbroken device, so debug
// lines are also appended to a file that can just be read with cat.
static NSString * const kLogFilePath = @"/var/mobile/Library/Logs/Printemps.log";
static const unsigned long long kLogFileSizeLimit = 256 * 1024;
static const NSUInteger kHierarchyDumpLimit = 8000;

static void PrintempsAppendToLogFile(NSString *message)
{
	static NSDateFormatter *formatter;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		formatter = [NSDateFormatter new];
		formatter.dateFormat = @"HH:mm:ss.SSS";
	});

	NSFileManager *fileManager = NSFileManager.defaultManager;
	if ([fileManager attributesOfItemAtPath:kLogFilePath error:NULL].fileSize > kLogFileSizeLimit) {
		[fileManager removeItemAtPath:kLogFilePath error:NULL];
	}

	NSString *line = [NSString stringWithFormat:@"%@ %@\n", [formatter stringFromDate:NSDate.date], message];
	NSData *data = [line dataUsingEncoding:NSUTF8StringEncoding];

	NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:kLogFilePath];
	if (handle == nil) {
		[data writeToFile:kLogFilePath atomically:YES];
		return;
	}

	[handle seekToEndOfFile];
	[handle writeData:data];
	[handle closeFile];
}

static void PrintempsLogMessage(NSString *message)
{
	NSLog(@"[Printemps] %@", message);
	if (sDebugLogging) PrintempsAppendToLogFile(message);
}

#pragma mark - Metrics

// The player is laid out as
//
//   +--------------------------------------------------+
//   | [artwork] title / artist            [<] [>] [>>] |
//   |           ------------------------------------   |
//   +--------------------------------------------------+
//
static const CGFloat kPlayerHeight = 118.0;
static const CGFloat kPlayerHeightWithoutKnob = 117.0;

static const CGFloat kArtworkSize = 70.0;
static const CGFloat kArtworkTrailingInsetRTL = 102.0;

static const CGFloat kControlsOriginY = 21.0;
static const CGFloat kControlsHeight = 25.0;
static const CGFloat kControlsWidth = 100.0;
static const CGFloat kControlsTrailingInset = 125.5;
static const CGFloat kControlsOriginXRTL = -6.5;
static const CGFloat kControlsOriginXRTLWithoutPrevious = -42.0;

static const CGFloat kLabelOriginY = kControlsOriginY - 13.0;
static const CGFloat kLabelOriginX = 80.0;

// The label has to clear the artwork on one side and the transport controls on
// the other, and the controls did not sit in the same place on every firmware.
static const CGFloat kLabelWidthInset14 = 200.0;
static const CGFloat kLabelWidthInset14WithoutPrevious = 170.0;
static const CGFloat kLabelOriginXRTL14 = 90.0;
static const CGFloat kLabelOriginXRTL14WithoutPrevious = 58.0;

static const CGFloat kLabelWidthInset15 = 210.0;
static const CGFloat kLabelWidthInset15WithoutPrevious = 180.0;
static const CGFloat kLabelOriginXRTL15 = 95.0;
static const CGFloat kLabelOriginXRTL15WithoutPrevious = 63.0;

static const CGFloat kTimeControlsOriginY = 60.0;

#pragma mark - Shared state

// Width of the media controls area, published by the CoverSheet hooks and read
// back by the iOS 14/15 layout hooks, which only ever see their own subview.
static CGFloat sPlayerWidth;

// Set while a collapsed lock screen player is on screen, so that CoverSheet is
// asked for the Printemps height instead of the stock one (iOS 16).
static BOOL sCompactPlayerNeedsPrintempsHeight;

static CGFloat PrintempsPlayerHeight(void)
{
	return sHideKnob ? kPlayerHeightWithoutKnob : kPlayerHeight;
}

static BOOL PrintempsIsRightToLeft(UIView *view)
{
	return view.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft;
}

#pragma mark - iOS 14 / 15

%group Legacy

//Media Controls
%hook MRUNowPlayingTransportControlsView

	- (void)setFrame: (CGRect)frame
	{
		// 4 -> LS
		// 0 -> CC
		if(self.layout == 4)
		{
			self.leftButton.hidden = sHidePrevious;

			//Remove all the constraints our object holds
			self.translatesAutoresizingMaskIntoConstraints = NO;

			if (PrintempsIsRightToLeft(self)) {
				frame.origin.x = sHidePrevious ? kControlsOriginXRTLWithoutPrevious : kControlsOriginXRTL;
			} else {
				frame.origin.x = sPlayerWidth - kControlsTrailingInset;
			}
			frame.origin.y = kControlsOriginY;
			frame.size.width = kControlsWidth;
			frame.size.height = kControlsHeight;
		}
		%orig;
	}

%end

//Artwork
%hook MRUArtworkView

	- (void)setFrame: (CGRect)frame
	{
		// 0 -> CC
		// 1 -> LS
		if(self.style == 1){
			frame.size.width = kArtworkSize;
			frame.size.height = kArtworkSize;
			if (PrintempsIsRightToLeft(self)) {
				frame.origin.x = sPlayerWidth - kArtworkTrailingInsetRTL;
			}
			// hide app icon
			self.iconView.hidden = sHideAppIcon;
			self.iconShadowView.hidden = sHideAppIcon;
		}
		%orig;
	}

%end

//Volume Slider
%hook MRUNowPlayingControlsView

	- (void)setNeedsLayout
	{
		//Only make changes for the lockscreen player by checking for parent view controller
		//Thanks to https://github.com/MrGcGamer/Loli/blob/9379ff30f985f8faae277269414a48357a32c544/Sources/Layout.x
		if(self.context == 2)
			self.volumeControlsView.hidden = true;
		%orig;
	}
%end

//Airplay Icon
%hook MRUNowPlayingHeaderView

	-(void)setShowRoutingButton:(BOOL)arg1{
		if(self.context == 2){
			return %orig(NO);
		}
		return %orig;
	}
%end

//Time Bar
%hook MRUNowPlayingTimeControlsView

	- (void)setFrame: (CGRect)frame
	{
		if(self.context == 2){
			frame.origin.y = kTimeControlsOriginY;
		}
		%orig;
	}

	-(void)setNeedsLayout
	{
		if(self.context == 2){
			// Hidden rather than removed from the hierarchy, so that turning the
			// tweak's options back off restores the stock player.
			self.elapsedTimeLabel.hidden = true;
			self.remainingTimeLabel.hidden = true;
			self.knobView.hidden = sHideKnob;
		}
		%orig;
	}
%end

%end // Legacy

//Player Height
// ios 14
%group LegacyHeight14
%hook CSMediaControlsViewController

	- (CGRect)_suggestedFrameForMediaControls
	{
		CGRect frame = %orig;
		frame.size.height = PrintempsPlayerHeight();
		sPlayerWidth = frame.size.width;

		return frame;
	}
%end
%end

// ios 15
%group LegacyHeight15
%hook CSMediaControlsViewController

	- (CGRect)_suggestedFrameForMediaControls
	{
		CGRect frame = %orig;
		frame.size.height = PrintempsPlayerHeight();
		sPlayerWidth = frame.size.width;

		return frame;
	}

	- (double)_preferredMediaRemoteHeight
	{
		return PrintempsPlayerHeight();
	}
%end
%end

//Header Labels
// ios 14.0 - 14.4
%group LegacyLabel14
%hook MRUNowPlayingLabelView

	- (void)setFrame: (CGRect)frame
	{
		//Only make changes for the lockscreen player by checking for parent view controller
		//Thanks to https://github.com/MrGcGamer/Loli/blob/9379ff30f985f8faae277269414a48357a32c544/Sources/Layout.x
		if(self.context == 2) {
			frame.origin.y = kLabelOriginY;
			if (sHidePrevious) {
				frame.origin.x = PrintempsIsRightToLeft(self) ? kLabelOriginXRTL14WithoutPrevious : kLabelOriginX;
				frame.size.width = sPlayerWidth - kLabelWidthInset14WithoutPrevious;
			} else {
				frame.origin.x = PrintempsIsRightToLeft(self) ? kLabelOriginXRTL14 : kLabelOriginX;
				frame.size.width = sPlayerWidth - kLabelWidthInset14;
			}
		}
		%orig;
	}

%end
%end

// ios 14.5 - 15
%group LegacyLabel15
%hook MRUNowPlayingLabelView

	- (void)setFrame: (CGRect)frame
	{
		if(self.context == 2) {
			frame.origin.y = kLabelOriginY;
			if (sHidePrevious) {
				frame.origin.x = PrintempsIsRightToLeft(self) ? kLabelOriginXRTL15WithoutPrevious : kLabelOriginX;
				frame.size.width = sPlayerWidth - kLabelWidthInset15WithoutPrevious;
			} else {
				frame.origin.x = PrintempsIsRightToLeft(self) ? kLabelOriginXRTL15 : kLabelOriginX;
				frame.size.width = sPlayerWidth - kLabelWidthInset15;
			}
		}
		%orig;
	}

%end
%end

#pragma mark - iOS 16

// iOS 16 collapses the lock screen player and expands it again when it is
// tapped. Only the collapsed one is restyled, the expanded one is left stock.
//
// The `layout` enum behind that state is undocumented and moves between
// firmwares, so the collapsed state is recognised by what the stock player does
// with it instead: it is the only lock screen layout that hides the transport
// controls.
//
// Everything is decided in -layoutSubviews. -updateVisibility runs once, while
// the view is still detached and its bounds are empty, which is too early to
// tell where the player ended up.

static const void *kPrintempsCompactKey = &kPrintempsCompactKey;

// Guards against the re-entrancy of -updateVisibility, whose setters call it
// back before we are done.
static BOOL sUpdatingVisibility;

// Superviews first, then the view controllers above them, which is what the
// lock screen test looks at.
static NSString *PrintempsAncestry(UIView *view)
{
	NSMutableArray<NSString *> *names = [NSMutableArray array];
	for (UIView *ancestor = view; ancestor != nil; ancestor = ancestor.superview) {
		[names addObject:NSStringFromClass(ancestor.class)];
	}
	for (UIResponder *responder = view; responder != nil; responder = responder.nextResponder) {
		if ([responder isKindOfClass:UIViewController.class]) {
			[names addObject:[@"@" stringByAppendingString:NSStringFromClass(responder.class)]];
		}
	}
	return [names componentsJoinedByString:@" < "];
}

static BOOL PrintempsIsLockScreenClassName(NSString *name)
{
	return [name hasPrefix:@"CS"] || [name hasPrefix:@"SBDashBoard"] || [name containsString:@"CoverSheet"];
}

static BOOL PrintempsIsLockScreenView(UIView *view)
{
	for (UIView *ancestor = view; ancestor != nil; ancestor = ancestor.superview) {
		if (PrintempsIsLockScreenClassName(NSStringFromClass(ancestor.class))) return YES;
	}
	for (UIResponder *responder = view; responder != nil; responder = responder.nextResponder) {
		if ([responder isKindOfClass:UIViewController.class]
			&& PrintempsIsLockScreenClassName(NSStringFromClass(responder.class))) return YES;
	}
	return NO;
}

static BOOL PrintempsWantsCompactStyling(MRUNowPlayingView *view)
{
	NSNumber *cached = objc_getAssociatedObject(view, kPrintempsCompactKey);
	if (cached != nil) return cached.boolValue;

	return PrintempsIsLockScreenView(view) && !view.showTransportControlsView;
}

static void PrintempsLayoutCompactPlayer(MRUNowPlayingView *view)
{
	CGFloat width = CGRectGetWidth(view.bounds);
	if (width <= 0.0) return;

	BOOL rightToLeft = PrintempsIsRightToLeft(view);
	MRUArtworkView *artworkView = view.artworkView;
	MRUNowPlayingHeaderView *headerView = view.headerView;
	MRUNowPlayingTransportControlsView *transportControlsView = view.transportControlsView;
	MRUNowPlayingTimeControlsView *timeControlsView = view.timeControlsView;

	CGRect frame = artworkView.frame;
	frame.origin.y = 0.0;
	frame.size = CGSizeMake(kArtworkSize, kArtworkSize);
	if (rightToLeft) frame.origin.x = width - kArtworkTrailingInsetRTL;
	artworkView.frame = frame;

	frame = headerView.frame;
	frame.origin.y = kLabelOriginY;
	if (sHidePrevious) {
		frame.origin.x = rightToLeft ? kLabelOriginXRTL15WithoutPrevious : kLabelOriginX;
		frame.size.width = width - kLabelWidthInset15WithoutPrevious;
	} else {
		frame.origin.x = rightToLeft ? kLabelOriginXRTL15 : kLabelOriginX;
		frame.size.width = width - kLabelWidthInset15;
	}
	headerView.frame = frame;

	frame = transportControlsView.frame;
	frame.origin.y = kControlsOriginY;
	frame.size = CGSizeMake(kControlsWidth, kControlsHeight);
	if (rightToLeft) {
		frame.origin.x = sHidePrevious ? kControlsOriginXRTLWithoutPrevious : kControlsOriginXRTL;
	} else {
		frame.origin.x = width - kControlsTrailingInset;
	}
	transportControlsView.frame = frame;

	frame = timeControlsView.frame;
	frame.origin.y = kTimeControlsOriginY;
	timeControlsView.frame = frame;

	// Only -hidden is touched here. Writing the show* flags would send the view
	// back through -updateVisibility and -setNeedsLayout on every pass.
	artworkView.hidden = NO;
	headerView.hidden = NO;
	transportControlsView.hidden = NO;
	timeControlsView.hidden = NO;
	view.volumeControlsView.hidden = YES;
	headerView.showWaveform = NO;

	transportControlsView.leftButton.hidden = sHidePrevious;
	artworkView.iconView.hidden = sHideAppIcon;
	artworkView.iconShadowView.hidden = sHideAppIcon;
	timeControlsView.elapsedTimeLabel.hidden = YES;
	timeControlsView.remainingTimeLabel.hidden = YES;

	PrintempsLog(@"styled %@ artwork %@ header %@ transport %@ time %@",
		NSStringFromCGRect(view.bounds), NSStringFromCGRect(artworkView.frame),
		NSStringFromCGRect(headerView.frame), NSStringFromCGRect(transportControlsView.frame),
		NSStringFromCGRect(timeControlsView.frame));
}

%group Modern

%hook MRUNowPlayingView

	- (void)layoutSubviews
	{
		%orig;

		BOOL lockScreen = PrintempsIsLockScreenView(self);
		if (sDebugLogging) {
			PrintempsLog(@"layout %ld context %ld show a%d t%d s%d v%d lockScreen %d bounds %@ in %@",
				(long)self.layout, (long)self.context, self.showArtworkView,
				self.showTransportControlsView, self.showTimeControlsView, self.showVolumeControlsView,
				lockScreen, NSStringFromCGRect(self.bounds), PrintempsAncestry(self));
		}
		if (!lockScreen) return;

		BOOL compact = !self.showTransportControlsView;
		objc_setAssociatedObject(self, kPrintempsCompactKey, @(compact), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		sCompactPlayerNeedsPrintempsHeight = compact;

		if (compact) PrintempsLayoutCompactPlayer(self);
	}

	- (void)updateVisibility
	{
		%orig;

		if (sUpdatingVisibility || !PrintempsIsLockScreenView(self)) return;
		if (self.showTransportControlsView) return;

		sUpdatingVisibility = YES;
		self.showArtworkView = YES;
		self.showTransportControlsView = YES;
		self.showTimeControlsView = YES;
		self.showVolumeControlsView = NO;
		self.headerView.showWaveform = NO;
		self.headerView.showRoutingButton = NO;
		self.useArtworkOverrideSize = YES;
		self.artworkOverrideSize = CGSizeMake(kArtworkSize, kArtworkSize);
		sUpdatingVisibility = NO;
	}

	- (CGSize)sizeThatFits: (CGSize)size
	{
		CGSize fitted = %orig;
		if (PrintempsWantsCompactStyling(self)) fitted.height = PrintempsPlayerHeight();

		return fitted;
	}

%end

%hook MRUNowPlayingViewController

	- (void)viewDidAppear: (BOOL)animated
	{
		%orig;

		if (!sDebugLogging) return;

		PrintempsLog(@"controller %@ context %ld layout %ld view %@",
			NSStringFromClass(self.class), (long)self.context, (long)self.layout,
			PrintempsAncestry(self.view));

		NSString *hierarchy = [self.view recursiveDescription];
		PrintempsLog(@"hierarchy %@", hierarchy.length > kHierarchyDumpLimit
			? [hierarchy substringToIndex:kHierarchyDumpLimit] : hierarchy);
	}

%end

%hook CSMediaControlsViewController

	- (double)_preferredMediaRemoteHeight
	{
		return sCompactPlayerNeedsPrintempsHeight ? PrintempsPlayerHeight() : %orig;
	}

%end

%end // Modern

#pragma mark - Entry point

%ctor {
	PrintempsLoadPreferences();
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL,
		PrintempsPreferencesChanged, (__bridge CFStringRef)kPreferencesChangedNotification,
		NULL, CFNotificationSuspensionBehaviorCoalesce);

	if (sDebugLogging) {
		NSMutableArray<NSString *> *present = [NSMutableArray array];
		for (NSString *name in @[@"MRUNowPlayingView", @"MRUNowPlayingViewController",
			@"MRUActivityNowPlayingViewController", @"MRUActivityArtworkView", @"MRPlatterViewController",
			@"MRUSessionNowPlayingView", @"CSMediaControlsViewController", @"CSMediaControlsView"]) {
			if (NSClassFromString(name) != nil) [present addObject:name];
		}
		PrintempsLog(@"classes present: %@", [present componentsJoinedByString:@", "]);
	}

	if (@available(iOS 16.0, *)) {
		PrintempsLogMessage([NSString stringWithFormat:@"loaded on iOS %@, using the iOS 16 hooks", UIDevice.currentDevice.systemVersion]);
		%init(Modern);
	} else {
		PrintempsLogMessage([NSString stringWithFormat:@"loaded on iOS %@, using the iOS 14/15 hooks", UIDevice.currentDevice.systemVersion]);
		%init(Legacy);

		if (@available(iOS 15.0, *)) {
			%init(LegacyHeight15);
		} else {
			%init(LegacyHeight14);
		}

		if (@available(iOS 14.5, *)) {
			%init(LegacyLabel15);
		} else {
			%init(LegacyLabel14);
		}
	}
}

