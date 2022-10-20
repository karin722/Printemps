#import "Tweak.h"

//Global
static double mediaPlayerHeight;
static double orgPlayerWidth;

//Controls
static double mediaControlsOriginY = 21; //N21 Debug 60
static double mediaControlsHeight = 25; //N25

//Settings
NSUserDefaults *settings = [[NSUserDefaults alloc] initWithSuiteName:@"com.tako3s.PrintempsPrefs"];

//Player Height
%hook CSMediaControlsViewController

	- (CGRect)_suggestedFrameForMediaControls
	{
		CGRect frame = %orig;
		if ([settings boolForKey:@"showKnob"]) {
			mediaPlayerHeight = 117;
		} else {
			mediaPlayerHeight = 118; //N119 Debug 150
		}
		frame.size.height = mediaPlayerHeight;
		orgPlayerWidth = frame.size.width;

		return frame;
	}

%end

//Header Labels
%hook MRUNowPlayingLabelView

	- (void)setFrame: (CGRect)frame
	{
		//Only make changes for the lockscreen player by checking for parent view controller
		//Thanks to https://github.com/MrGcGamer/Loli/blob/9379ff30f985f8faae277269414a48357a32c544/Sources/Layout.x
		if(self.context == 2) {
			frame.origin.y = mediaControlsOriginY - 13;
			if ([settings boolForKey:@"hidePrevious"]) {
				if (self.tp_userInterfaceLayoutDirection == 1) {
					frame.origin.x = 58;
					frame.size.width = orgPlayerWidth - 170;
				} else {
					frame.origin.x = 80;
					frame.size.width = orgPlayerWidth - 170;
				}
			} else {
				if (self.tp_userInterfaceLayoutDirection == 1) {
					frame.origin.x = 90;
					frame.size.width = orgPlayerWidth - 200;
				} else {
					frame.origin.x = 80;
					frame.size.width = orgPlayerWidth - 200;
				}
			}
		}
		%orig;
	}

%end

//Media Controls
%hook MRUNowPlayingTransportControlsView

	- (void)setFrame: (CGRect)frame
	{
		// 4 -> LS
		// 0 -> CC
		if(self.layout == 4)
		{
			if ([settings boolForKey:@"hidePrevious"]) {
				[self.leftButton removeFromSuperview];
			}

			//Remove all the constraints our object holds
			self.translatesAutoresizingMaskIntoConstraints = NO;

			if (self.tp_userInterfaceLayoutDirection == 1) {
				if ([settings boolForKey:@"hidePrevious"]) {
					frame.origin.x = -42;
				} else {
					frame.origin.x = -6.5;
				}
			} else {
				frame.origin.x = orgPlayerWidth - 125.5;
			}
			frame.origin.y = mediaControlsOriginY;
			frame.size.width = 100;
			frame.size.height = mediaControlsHeight;
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
			frame.size.width = 70;
			frame.size.height = 70;
			if (self.tp_userInterfaceLayoutDirection == 1) {
				frame.origin.x = orgPlayerWidth - 102;
			}
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
			[self.volumeControlsView removeFromSuperview];
		%orig;
	}
%end

//Airplay Icon
%hook MRUNowPlayingHeaderView

	-(void)setShowRoutingButton:(BOOL)arg1{
		//Only make changes for the lockscreen player by checking for parent view controller
		//Thanks to https://github.com/MrGcGamer/Loli/blob/9379ff30f985f8faae277269414a48357a32c544/Sources/Layout.x
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
		//Only make changes for the lockscreen player by checking for parent view controller
		//Thanks to https://github.com/MrGcGamer/Loli/blob/9379ff30f985f8faae277269414a48357a32c544/Sources/Layout.x
		if(self.context == 2){
			frame.origin.y = 60;
		}
		%orig;
	}

	-(void)updateVisibility
	{
		//Only make changes for the lockscreen player by checking for parent view controller
		//Thanks to https://github.com/MrGcGamer/Loli/blob/9379ff30f985f8faae277269414a48357a32c544/Sources/Layout.x
		if(self.context == 2){
			[self.elapsedTimeLabel removeFromSuperview];
			[self.remainingTimeLabel removeFromSuperview];
			
			if ([settings boolForKey:@"showKnob"]) {
				[self.knobView removeFromSuperview];
			}
		}
		%orig;
	}
%end
