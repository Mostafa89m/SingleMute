@interface SBRingerControl : NSObject
- (BOOL)isRingerMuted;
@end

@interface _UIStatusBarDataQuietModeEntry : NSObject
    @property(nonatomic, copy) NSString *focusName;
@end

@interface _UIStatusBarData : NSObject
    @property(nonatomic, copy) _UIStatusBarDataQuietModeEntry *quietModeEntry;
@end

@interface _UIStatusBarItemUpdate : NSObject
    @property(nonatomic, strong) _UIStatusBarData *data;
@end

@interface UIStatusBarServer : NSObject
    + (const unsigned char *)getStatusBarData;
@end

@interface UIStatusBar_Base : UIView
    @property(nonatomic, strong) UIStatusBarServer *statusBarServer;
    - (void)reloadSingleMute;
    - (void)forceUpdateData:(BOOL)arg1;
    - (void)statusBarServer:(id)arg1 didReceiveStatusBarData:(const unsigned char *)arg2 withActions:(int)arg3;
@end

@interface UIStatusBar_Modern : UIStatusBar_Base
@end

static BOOL isRingerMuted;
static unsigned char _sharedData[5000] = {0};

%hook _UIStatusBarIndicatorQuietModeItem

- (id)systemImageNameForUpdate:(_UIStatusBarItemUpdate *)update {
    BOOL isQuietModeEnabled = ![update.data.quietModeEntry.focusName isEqualToString:@"!Mute"];
    if (isRingerMuted && !isQuietModeEnabled) {
        return @"bell.slash.fill";
    }
    return %orig;
}

%end

%hook _UIStatusBarDataQuietModeEntry

    - (id)initFromData:(unsigned char *)data type:(int)arg2 focusName:(const char *)arg3 maxFocusLength:(int)arg4 imageName:(const char*)arg5 maxImageLength:(int)arg6 boolValue:(BOOL)arg7 {
        BOOL isQuietMode = data[2];
        if (!isQuietMode) {
            _sharedData[2] = isRingerMuted;
            return %orig(_sharedData, arg2, "!Mute", arg4, arg5, arg6, arg7);
        }
        return %orig;
    }

%end

%hook SpringBoard

	-(void)_updateRingerState:(int)arg1 withVisuals:(BOOL)arg2 updatePreferenceRegister:(BOOL)arg3
	{
		%orig;
        isRingerMuted = !arg1;
		[[NSNotificationCenter defaultCenter] postNotificationName:@"updateQuiteModeItem" object:nil];
	}

%end

%hook UIStatusBar_Base

    - (instancetype)_initWithFrame:(CGRect)frame showForegroundView:(BOOL)showForegroundView wantsServer:(BOOL)wantsServer inProcessStateProvider:(id)inProcessStateProvider {
        id orig = %orig;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateQuiteModeItem) name:@"updateQuiteModeItem" object:nil];
        return orig;
    }

    %new
    - (void)updateQuiteModeItem {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            const unsigned char *data = [UIStatusBarServer getStatusBarData];
            [self statusBarServer:self.statusBarServer didReceiveStatusBarData:data withActions:0];
        });
    }

%end