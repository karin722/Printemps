#import "PrintempsPlayerView.h"
#import <dlfcn.h>

#pragma mark - MediaRemote

// MediaRemote is already loaded into SpringBoard, and looking its symbols up at
// runtime keeps the build from depending on which private framework stubs the
// SDK happens to ship.
typedef void (*MRGetNowPlayingInfoFunction)(dispatch_queue_t queue, void (^handler)(NSDictionary *information));
typedef void (*MRRegisterForNotificationsFunction)(dispatch_queue_t queue);
typedef void (*MRSendCommandFunction)(int command, NSDictionary *userInfo);
typedef void (*MRSetElapsedTimeFunction)(double elapsedTime);

typedef NS_ENUM(int, PrintempsMediaCommand) {
	PrintempsMediaCommandTogglePlayPause = 2,
	PrintempsMediaCommandNextTrack = 4,
	PrintempsMediaCommandPreviousTrack = 5,
};

static MRGetNowPlayingInfoFunction PrintempsGetNowPlayingInfo;
static MRRegisterForNotificationsFunction PrintempsRegisterForNotifications;
static MRSendCommandFunction PrintempsSendCommand;
static MRSetElapsedTimeFunction PrintempsSetElapsedTime;

static void PrintempsLoadMediaRemote(void)
{
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		PrintempsGetNowPlayingInfo = (MRGetNowPlayingInfoFunction)dlsym(RTLD_DEFAULT, "MRMediaRemoteGetNowPlayingInfo");
		PrintempsRegisterForNotifications = (MRRegisterForNotificationsFunction)dlsym(RTLD_DEFAULT, "MRMediaRemoteRegisterForNowPlayingNotifications");
		PrintempsSendCommand = (MRSendCommandFunction)dlsym(RTLD_DEFAULT, "MRMediaRemoteSendCommand");
		PrintempsSetElapsedTime = (MRSetElapsedTimeFunction)dlsym(RTLD_DEFAULT, "MRMediaRemoteSetElapsedTime");
	});
}

// The info dictionary is keyed by exported string constants whose values happen
// to be their own symbol names, so the literal is a safe fallback.
static NSString *PrintempsInfoKey(const char *symbol)
{
	NSString * __unsafe_unretained *value = (NSString * __unsafe_unretained *)dlsym(RTLD_DEFAULT, symbol);
	return value == NULL ? @(symbol) : *value;
}

#pragma mark - Lock state

// SpringBoard keeps the lock state as a bitmask. Bit 0 says the lock screen is
// up, which stays set after Face ID has already matched; bit 1 is the one that
// clears on authentication, sampled across lock, wake, Face ID and unlock.
static const NSUInteger kLockStateNeedsAuthentication = 1 << 1;

@interface SBLockStateAggregator : NSObject
+ (instancetype)sharedInstance;
- (NSUInteger)lockState;
@end

static BOOL PrintempsDeviceIsAuthenticated(void)
{
	Class aggregatorClass = NSClassFromString(@"SBLockStateAggregator");
	if (aggregatorClass == nil) return YES;

	SBLockStateAggregator *aggregator = [aggregatorClass sharedInstance];
	if (![aggregator respondsToSelector:@selector(lockState)]) return YES;

	return (aggregator.lockState & kLockStateNeedsAuthentication) == 0;
}

#pragma mark - Labels

// The stock player scrolls long titles with this, so Printemps uses the same
// thing rather than reimplementing it. UILabel stands in if it ever goes away.
@protocol PrintempsTextView <NSObject>
@property (nonatomic, copy) NSString *text;
@property (nonatomic, retain) UIFont *font;
@property (nonatomic, retain) UIColor *textColor;
@property (nonatomic, assign) NSTextAlignment textAlignment;
@end

@interface MRUMarqueeLabel : UIView <PrintempsTextView>
@property (nonatomic, assign, getter=isMarqueeEnabled) BOOL marqueeEnabled;
// The label draws nothing until it is told how wide its text is, and scrolls
// once that is wider than the label itself.
@property (nonatomic, assign) CGSize contentSize;
// The view that actually draws the text.
@property (nonatomic, readonly) UIView *label;
@end

@interface UILabel (PrintempsTextView) <PrintempsTextView>
@end

@implementation UILabel (PrintempsTextView)
@end

#pragma mark - Metrics

static const CGFloat kProgressHeight = 3.0;
static const CGFloat kProgressTopGap = 6.0;
static const CGFloat kArtworkSize = 70.0;
static const CGFloat kPlayerHeight = kArtworkSize + kProgressTopGap + kProgressHeight;
static const CGFloat kArtworkCornerRadius = 4.0;
static const CGFloat kContentSpacing = 12.0;
static const CGFloat kTransportButtonSize = 28.0;
static const CGFloat kTransportSpacing = 8.0;
static const CGFloat kTitleHeight = 20.0;
static const CGFloat kSubtitleHeight = 18.0;
// A three point bar is not something a finger can hit, so the gestures get a
// taller area of their own.
static const CGFloat kProgressTouchHeight = 18.0;
// Above the cover sheet, so the share sheet is not buried under the lock screen.
static const CGFloat kShareWindowLevel = 1234.0;

@interface PrintempsPlayerView ()

@property (nonatomic, retain) UIImageView *artworkView;
@property (nonatomic, retain) UIView<PrintempsTextView> *titleLabel;
@property (nonatomic, retain) UIView<PrintempsTextView> *subtitleLabel;
@property (nonatomic, retain) UIButton *previousButton;
@property (nonatomic, retain) UIButton *playPauseButton;
@property (nonatomic, retain) UIButton *nextButton;
@property (nonatomic, retain) UIView *progressTrack;
@property (nonatomic, retain) UIView *progressFill;
@property (nonatomic, retain) UIView *progressTouchArea;
@property (nonatomic, retain) NSTimer *progressTimer;

@property (nonatomic, copy) NSString *currentTitle;
@property (nonatomic, copy) NSString *currentArtist;
@property (nonatomic, assign, getter=isScrubbing) BOOL scrubbing;
@property (nonatomic, retain) UIWindow *shareWindow;

@property (nonatomic, assign) BOOL playing;
@property (nonatomic, assign) double elapsedTime;
@property (nonatomic, assign) double duration;
@property (nonatomic, retain) NSDate *elapsedTimestamp;
@property (nonatomic, assign) double playbackRate;

@end

@implementation PrintempsPlayerView

+ (CGFloat)preferredHeight
{
	return kPlayerHeight;
}

- (instancetype)initWithFrame: (CGRect)frame
{
	self = [super initWithFrame:frame];
	if (self == nil) return nil;

	PrintempsLoadMediaRemote();
	_sharingEnabled = YES;

	_artworkView = [UIImageView new];
	_artworkView.contentMode = UIViewContentModeScaleAspectFill;
	_artworkView.clipsToBounds = YES;
	_artworkView.layer.cornerRadius = kArtworkCornerRadius;
	_artworkView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.2];
	_artworkView.userInteractionEnabled = YES;
	[_artworkView addGestureRecognizer:[[UILongPressGestureRecognizer alloc]
		initWithTarget:self action:@selector(handleArtworkLongPress:)]];
	[self addSubview:_artworkView];

	_titleLabel = [self makeLabelWithFont:[UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold] alpha:1.0];
	_subtitleLabel = [self makeLabelWithFont:[UIFont systemFontOfSize:13.0 weight:UIFontWeightRegular] alpha:0.65];

	_previousButton = [self makeTransportButtonWithSymbol:@"backward.fill" action:@selector(previousTrack)];
	_playPauseButton = [self makeTransportButtonWithSymbol:@"pause.fill" action:@selector(togglePlayPause)];
	_nextButton = [self makeTransportButtonWithSymbol:@"forward.fill" action:@selector(nextTrack)];

	_progressTrack = [UIView new];
	_progressTrack.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.25];
	_progressTrack.layer.cornerRadius = kProgressHeight / 2.0;
	_progressTrack.clipsToBounds = YES;
	[self addSubview:_progressTrack];

	_progressFill = [UIView new];
	_progressFill.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.9];
	[_progressTrack addSubview:_progressFill];

	_progressTouchArea = [UIView new];
	[_progressTouchArea addGestureRecognizer:[[UIPanGestureRecognizer alloc]
		initWithTarget:self action:@selector(handleScrub:)]];
	[_progressTouchArea addGestureRecognizer:[[UITapGestureRecognizer alloc]
		initWithTarget:self action:@selector(handleScrub:)]];
	[self addSubview:_progressTouchArea];

	return self;
}

- (UIView<PrintempsTextView> *)makeLabelWithFont: (UIFont *)font alpha: (CGFloat)alpha
{
	Class marqueeClass = NSClassFromString(@"MRUMarqueeLabel");
	UIView<PrintempsTextView> *label = marqueeClass == nil
		? (UIView<PrintempsTextView> *)[UILabel new]
		: [[marqueeClass alloc] initWithFrame:CGRectZero];

	label.font = font;
	label.textColor = [UIColor colorWithWhite:1.0 alpha:alpha];
	if ([label respondsToSelector:@selector(setMarqueeEnabled:)]) {
		[(MRUMarqueeLabel *)label setMarqueeEnabled:YES];
	}
	[self addSubview:label];

	return label;
}

- (UIButton *)makeTransportButtonWithSymbol: (NSString *)symbol action: (SEL)action
{
	UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
	[button setImage:[UIImage systemImageNamed:symbol] forState:UIControlStateNormal];
	button.tintColor = UIColor.whiteColor;
	[button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
	[self addSubview:button];

	return button;
}

#pragma mark - Layout

- (void)layoutSubviews
{
	[super layoutSubviews];

	CGFloat width = CGRectGetWidth(self.bounds);
	BOOL rightToLeft = [self isRightToLeft];

	self.artworkView.frame = [self flipIfNeeded:CGRectMake(0.0, 0.0, kArtworkSize, kArtworkSize)];

	// Transport controls sit against the trailing edge.
	CGFloat buttonCount = self.hidesPreviousButton ? 2.0 : 3.0;
	CGFloat transportWidth = buttonCount * kTransportButtonSize + (buttonCount - 1.0) * kTransportSpacing;
	CGFloat transportX = width - transportWidth;
	CGFloat transportY = (kArtworkSize - kTransportButtonSize) / 2.0;

	self.previousButton.hidden = self.hidesPreviousButton;
	CGFloat buttonX = transportX;
	for (UIButton *button in @[self.previousButton, self.playPauseButton, self.nextButton]) {
		if (button.hidden) continue;

		button.frame = [self flipIfNeeded:CGRectMake(buttonX, transportY, kTransportButtonSize, kTransportButtonSize)];
		buttonX += kTransportButtonSize + kTransportSpacing;
	}

	CGFloat labelX = kArtworkSize + kContentSpacing;
	CGFloat labelWidth = MAX(0.0, transportX - labelX - kContentSpacing);
	CGFloat labelY = (kArtworkSize - kTitleHeight - kSubtitleHeight) / 2.0;

	self.titleLabel.frame = [self flipIfNeeded:CGRectMake(labelX, labelY, labelWidth, kTitleHeight)];
	self.subtitleLabel.frame = [self flipIfNeeded:CGRectMake(labelX, labelY + kTitleHeight, labelWidth, kSubtitleHeight)];
	self.titleLabel.textAlignment = rightToLeft ? NSTextAlignmentRight : NSTextAlignmentLeft;
	self.subtitleLabel.textAlignment = self.titleLabel.textAlignment;

	CGFloat height = CGRectGetHeight(self.bounds);
	self.progressTrack.frame = CGRectMake(0.0, height - kProgressHeight, width, kProgressHeight);
	self.progressTouchArea.frame = CGRectMake(0.0, height - kProgressTouchHeight, width, kProgressTouchHeight);
	[self updateProgress];
}

- (CGRect)flipIfNeeded: (CGRect)frame
{
	if (![self isRightToLeft]) return frame;

	frame.origin.x = CGRectGetWidth(self.bounds) - CGRectGetMaxX(frame);
	return frame;
}

- (void)setHidesPreviousButton: (BOOL)hidesPreviousButton
{
	if (_hidesPreviousButton == hidesPreviousButton) return;

	_hidesPreviousButton = hidesPreviousButton;
	[self setNeedsLayout];
}

#pragma mark - Now playing

- (void)didMoveToWindow
{
	[super didMoveToWindow];

	if (self.window == nil) {
		[self stopObserving];
		return;
	}

	[self startObserving];
	[self refresh];
}

- (void)startObserving
{
	if (PrintempsRegisterForNotifications != NULL) PrintempsRegisterForNotifications(dispatch_get_main_queue());

	NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
	for (NSString *name in @[@"kMRMediaRemoteNowPlayingInfoDidChangeNotification",
		@"kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification"]) {
		[center addObserver:self selector:@selector(refresh) name:name object:nil];
	}

	if (self.progressTimer != nil) return;

	self.progressTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self
		selector:@selector(updateProgress) userInfo:nil repeats:YES];
}

- (void)stopObserving
{
	[NSNotificationCenter.defaultCenter removeObserver:self];
	[self.progressTimer invalidate];
	self.progressTimer = nil;
}

- (void)dealloc
{
	[self stopObserving];
}

- (void)refresh
{
	if (PrintempsGetNowPlayingInfo == NULL) return;

	PrintempsGetNowPlayingInfo(dispatch_get_main_queue(), ^(NSDictionary *information) {
		[self applyNowPlayingInfo:information];
	});
}

- (void)applyNowPlayingInfo: (NSDictionary *)information
{
	NSString *title = information[PrintempsInfoKey("kMRMediaRemoteNowPlayingInfoTitle")];
	NSString *artist = information[PrintempsInfoKey("kMRMediaRemoteNowPlayingInfoArtist")];
	NSData *artwork = information[PrintempsInfoKey("kMRMediaRemoteNowPlayingInfoArtworkData")];

	self.currentTitle = title;
	self.currentArtist = artist;
	[self setText:title onLabel:self.titleLabel];
	[self setText:artist onLabel:self.subtitleLabel];
	if (artwork != nil) self.artworkView.image = [UIImage imageWithData:artwork];

	NSNumber *elapsed = information[PrintempsInfoKey("kMRMediaRemoteNowPlayingInfoElapsedTime")];
	NSNumber *duration = information[PrintempsInfoKey("kMRMediaRemoteNowPlayingInfoDuration")];
	NSNumber *rate = information[PrintempsInfoKey("kMRMediaRemoteNowPlayingInfoPlaybackRate")];
	id timestamp = information[PrintempsInfoKey("kMRMediaRemoteNowPlayingInfoTimestamp")];

	self.elapsedTime = elapsed.doubleValue;
	self.duration = duration.doubleValue;
	self.playbackRate = rate == nil ? 1.0 : rate.doubleValue;
	self.elapsedTimestamp = [timestamp isKindOfClass:NSDate.class] ? timestamp : NSDate.date;
	self.playing = self.playbackRate > 0.0;

	BOOL hadContent = _hasContent;
	_hasContent = title.length > 0;
	if (hadContent != _hasContent) [self.superview setNeedsLayout];

	NSString *symbol = self.playing ? @"pause.fill" : @"play.fill";
	[self.playPauseButton setImage:[UIImage systemImageNamed:symbol] forState:UIControlStateNormal];

	[self updateProgress];
}

- (void)setText: (NSString *)text onLabel: (UIView<PrintempsTextView> *)label
{
	label.text = text;
	if (![label respondsToSelector:@selector(setContentSize:)]) return;

	// Ask the view that draws the text how wide it needs to be. Measuring from
	// the font here instead comes out a fraction of a point short, which is
	// enough to truncate the last character.
	MRUMarqueeLabel *marquee = (MRUMarqueeLabel *)label;
	CGSize size = [marquee.label sizeThatFits:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)];
	if (size.width <= 0.0) {
		size = [text ?: @"" sizeWithAttributes:@{NSFontAttributeName: label.font}];
		size.width = ceil(size.width) + 1.0;
	}

	marquee.contentSize = size;
}

- (void)updateProgress
{
	if (self.isScrubbing) return;

	if (self.duration <= 0.0) {
		self.progressFill.frame = CGRectZero;
		return;
	}

	double elapsed = self.elapsedTime;
	if (self.playing && self.elapsedTimestamp != nil) {
		elapsed += -self.elapsedTimestamp.timeIntervalSinceNow * self.playbackRate;
	}

	[self showProgress:elapsed / self.duration];
}

- (void)showProgress: (double)progress
{
	CGRect track = self.progressTrack.bounds;
	CGFloat filled = CGRectGetWidth(track) * MIN(1.0, MAX(0.0, progress));
	CGFloat originX = [self isRightToLeft] ? CGRectGetWidth(track) - filled : 0.0;

	self.progressFill.frame = CGRectMake(originX, 0.0, filled, CGRectGetHeight(track));
}

- (BOOL)isRightToLeft
{
	return self.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft;
}

#pragma mark - Scrubbing

- (void)handleScrub: (UIGestureRecognizer *)recognizer
{
	if (self.duration <= 0.0) return;

	CGFloat width = CGRectGetWidth(self.progressTrack.bounds);
	if (width <= 0.0) return;

	double progress = [recognizer locationInView:self.progressTrack].x / width;
	if ([self isRightToLeft]) progress = 1.0 - progress;
	progress = MIN(1.0, MAX(0.0, progress));

	BOOL finished = recognizer.state != UIGestureRecognizerStateBegan
		&& recognizer.state != UIGestureRecognizerStateChanged;

	self.scrubbing = !finished;
	[self showProgress:progress];
	if (!finished) return;

	[self seekTo:progress * self.duration];
}

- (void)seekTo: (double)time
{
	if (PrintempsSetElapsedTime == NULL) return;

	PrintempsSetElapsedTime(time);

	// Keep the bar where it was left until the player reports back.
	self.elapsedTime = time;
	self.elapsedTimestamp = NSDate.date;

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		[self refresh];
	});
}

#pragma mark - Sharing

- (void)handleArtworkLongPress: (UILongPressGestureRecognizer *)recognizer
{
	if (!self.sharingEnabled || recognizer.state != UIGestureRecognizerStateBegan) return;
	if (!self.hasContent || self.shareWindow != nil) return;

	// Everything the sheet would share is already on the lock screen, but
	// sharing it is not something somebody who picked the phone up should be
	// able to start. Face ID having matched is enough; no prompt is raised.
	if (!PrintempsDeviceIsAuthenticated()) return;

	// Presenting into SpringBoard's own cover sheet controller shows nothing and
	// takes SpringBoard down with it, so the sheet goes in a window of our own.
	// It has to belong to a window scene, or iOS never puts it on screen.
	UIWindowScene *scene = self.window.windowScene;
	if (scene == nil) return;

	NSMutableArray<NSString *> *parts = [NSMutableArray array];
	if (self.currentTitle.length > 0) [parts addObject:self.currentTitle];
	if (self.currentArtist.length > 0) [parts addObject:self.currentArtist];

	NSMutableArray *items = [NSMutableArray arrayWithObject:
		[NSString stringWithFormat:@"%@ #nowplaying", [parts componentsJoinedByString:@" - "]]];
	if (self.artworkView.image != nil) [items addObject:self.artworkView.image];

	UIWindow *window = [[UIWindow alloc] initWithWindowScene:scene];
	window.frame = scene.screen.bounds;
	window.windowLevel = kShareWindowLevel;
	window.rootViewController = [UIViewController new];
	[window makeKeyAndVisible];
	self.shareWindow = window;

	UIActivityViewController *sheet = [[UIActivityViewController alloc] initWithActivityItems:items
		applicationActivities:nil];
	sheet.popoverPresentationController.sourceView = window.rootViewController.view;
	sheet.popoverPresentationController.sourceRect = window.rootViewController.view.bounds;

	__weak __typeof(self) weakSelf = self;
	sheet.completionWithItemsHandler = ^(UIActivityType type, BOOL completed, NSArray *returned, NSError *error) {
		[weakSelf dismissShareWindow];
	};

	[window.rootViewController presentViewController:sheet animated:YES completion:nil];
}

- (void)dismissShareWindow
{
	UIWindow *window = self.shareWindow;
	if (window == nil) return;

	self.shareWindow = nil;
	[window.rootViewController dismissViewControllerAnimated:YES completion:^{
		window.hidden = YES;
		window.rootViewController = nil;
	}];
}

#pragma mark - Commands

- (void)send: (PrintempsMediaCommand)command
{
	if (PrintempsSendCommand == NULL) return;

	PrintempsSendCommand(command, nil);
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		[self refresh];
	});
}

- (void)togglePlayPause
{
	[self send:PrintempsMediaCommandTogglePlayPause];
}

- (void)nextTrack
{
	[self send:PrintempsMediaCommandNextTrack];
}

- (void)previousTrack
{
	[self send:PrintempsMediaCommandPreviousTrack];
}

@end
