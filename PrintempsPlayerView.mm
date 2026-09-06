#import "PrintempsPlayerView.h"
#import <dlfcn.h>

#pragma mark - MediaRemote

// MediaRemote is already loaded into SpringBoard, and looking its symbols up at
// runtime keeps the build from depending on which private framework stubs the
// SDK happens to ship.
typedef void (*MRGetNowPlayingInfoFunction)(dispatch_queue_t queue, void (^handler)(NSDictionary *information));
typedef void (*MRRegisterForNotificationsFunction)(dispatch_queue_t queue);
typedef void (*MRSendCommandFunction)(int command, NSDictionary *userInfo);

typedef NS_ENUM(int, PrintempsMediaCommand) {
	PrintempsMediaCommandTogglePlayPause = 2,
	PrintempsMediaCommandNextTrack = 4,
	PrintempsMediaCommandPreviousTrack = 5,
};

static MRGetNowPlayingInfoFunction PrintempsGetNowPlayingInfo;
static MRRegisterForNotificationsFunction PrintempsRegisterForNotifications;
static MRSendCommandFunction PrintempsSendCommand;

static void PrintempsLoadMediaRemote(void)
{
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		PrintempsGetNowPlayingInfo = (MRGetNowPlayingInfoFunction)dlsym(RTLD_DEFAULT, "MRMediaRemoteGetNowPlayingInfo");
		PrintempsRegisterForNotifications = (MRRegisterForNotificationsFunction)dlsym(RTLD_DEFAULT, "MRMediaRemoteRegisterForNowPlayingNotifications");
		PrintempsSendCommand = (MRSendCommandFunction)dlsym(RTLD_DEFAULT, "MRMediaRemoteSendCommand");
	});
}

// The info dictionary is keyed by exported string constants whose values happen
// to be their own symbol names, so the literal is a safe fallback.
static NSString *PrintempsInfoKey(const char *symbol)
{
	NSString **value = (NSString **)dlsym(RTLD_DEFAULT, symbol);
	return value == NULL ? @(symbol) : *value;
}

#pragma mark - Metrics

static const CGFloat kPlayerHeight = 90.0;
static const CGFloat kArtworkSize = 70.0;
static const CGFloat kArtworkCornerRadius = 4.0;
static const CGFloat kContentSpacing = 12.0;
static const CGFloat kTransportButtonSize = 28.0;
static const CGFloat kTransportSpacing = 8.0;
static const CGFloat kTitleHeight = 20.0;
static const CGFloat kSubtitleHeight = 18.0;
static const CGFloat kProgressHeight = 3.0;
static const CGFloat kProgressBottomInset = 8.0;

@interface PrintempsPlayerView ()

@property (nonatomic, retain) UIImageView *artworkView;
@property (nonatomic, retain) UILabel *titleLabel;
@property (nonatomic, retain) UILabel *subtitleLabel;
@property (nonatomic, retain) UIButton *previousButton;
@property (nonatomic, retain) UIButton *playPauseButton;
@property (nonatomic, retain) UIButton *nextButton;
@property (nonatomic, retain) UIView *progressTrack;
@property (nonatomic, retain) UIView *progressFill;
@property (nonatomic, retain) NSTimer *progressTimer;

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

	_artworkView = [UIImageView new];
	_artworkView.contentMode = UIViewContentModeScaleAspectFill;
	_artworkView.clipsToBounds = YES;
	_artworkView.layer.cornerRadius = kArtworkCornerRadius;
	_artworkView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.2];
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

	return self;
}

- (UILabel *)makeLabelWithFont: (UIFont *)font alpha: (CGFloat)alpha
{
	UILabel *label = [UILabel new];
	label.font = font;
	label.textColor = [UIColor colorWithWhite:1.0 alpha:alpha];
	label.lineBreakMode = NSLineBreakByTruncatingTail;
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
	BOOL rightToLeft = self.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft;

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

	CGFloat progressY = CGRectGetHeight(self.bounds) - kProgressHeight - kProgressBottomInset;
	self.progressTrack.frame = CGRectMake(0.0, progressY, width, kProgressHeight);
	[self updateProgress];
}

- (CGRect)flipIfNeeded: (CGRect)frame
{
	if (self.effectiveUserInterfaceLayoutDirection != UIUserInterfaceLayoutDirectionRightToLeft) return frame;

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

	self.titleLabel.text = title;
	self.subtitleLabel.text = artist;
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

	_hasContent = title.length > 0;

	NSString *symbol = self.playing ? @"pause.fill" : @"play.fill";
	[self.playPauseButton setImage:[UIImage systemImageNamed:symbol] forState:UIControlStateNormal];

	[self updateProgress];
}

- (void)updateProgress
{
	if (self.duration <= 0.0) {
		self.progressFill.frame = CGRectZero;
		return;
	}

	double elapsed = self.elapsedTime;
	if (self.playing && self.elapsedTimestamp != nil) {
		elapsed += -self.elapsedTimestamp.timeIntervalSinceNow * self.playbackRate;
	}

	double progress = MIN(1.0, MAX(0.0, elapsed / self.duration));
	CGRect track = self.progressTrack.bounds;
	self.progressFill.frame = CGRectMake(0.0, 0.0, CGRectGetWidth(track) * progress, CGRectGetHeight(track));
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
