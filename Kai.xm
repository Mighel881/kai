#import "Kai.h"

CSAdjunctListView *list;
Class mediaClass;

%group main

%hook Media

- (void)removeFromSuperview {
	%orig;
	if(removeForMedia) {
		shouldBeAdded = YES;
		Class cls = kCFCoreFoundationVersionNumber > 1600 ? ([objc_getClass("CSAdjunctListView") class]) : ([objc_getClass("SBDashBoardAdjunctListView") class]);

		[[[cls sharedListViewForKai] stackView] addSubview:[KAIBatteryPlatter sharedInstance]];
		[[[cls sharedListViewForKai] stackView] insertArrangedSubview:[KAIBatteryPlatter sharedInstance] atIndex:([[[cls sharedListViewForKai] stackView].subviews count] -1)];
	}
}

%end

%hook KAITarget //This class is defined in %ctor, KAITarget is not a class name.

%property (nonatomic, assign) BOOL hasKai;

- (void)_layoutStackView { //this is completely fucking shit and I know it
			   //old code im too lazy to fix, if someone else
			   //wants to, pls fix for me because this is 
			   //disgusting
	%orig;

	BOOL found = NO;

	for(UIView *view in [self stackView].subviews) { //i want to die
		if([view isMemberOfClass:mediaClass] && removeForMedia) {
			found = YES;
			NSLog(@"Found media for kai");
			if([[self stackView].subviews containsObject:[KAIBatteryPlatter sharedInstance]]) {
				[[self stackView] removeArrangedSubview:[KAIBatteryPlatter sharedInstance]];
				[[KAIBatteryPlatter sharedInstance] removeFromSuperview];
				[self setNeedsLayout];
				shouldBeAdded = NO;
				NSLog(@"Removing kai for media");
			}
		}
	}

	if(!found || !removeForMedia || shouldBeAdded) {

		NSLog(@"Adjusting kai");
		if(![[self stackView].subviews containsObject:[KAIBatteryPlatter sharedInstance]]) {
			[[self stackView] addSubview:[KAIBatteryPlatter sharedInstance]];
		}

		//this code is used to determine if kai is at the bottom of the stack view
		@try {
			if([[self stackView].subviews objectAtIndex:([[self stackView].subviews count] -1)] != [KAIBatteryPlatter sharedInstance] && belowMusic) {
				//if it is not, but the option to have kai below music is on, i simply remove from it's current pos. 
				//and insert into last slot.
				[[self stackView] removeArrangedSubview:[KAIBatteryPlatter sharedInstance]];
				[[self stackView] insertArrangedSubview:[KAIBatteryPlatter sharedInstance] atIndex:([[self stackView].subviews count] -1)];
			} else if(!belowMusic && [[self stackView].subviews objectAtIndex:0]!=[KAIBatteryPlatter sharedInstance]) {
				APEPlatter *platter = [%c(APEPlatter) sharedInstance];
				if([[NSFileManager defaultManager] fileExistsAtPath:@"/var/lib/dpkg/info/com.burritoz.aperio.list"] && platter) {
					if(!platter.removed) {
						[[self stackView] removeArrangedSubview:[KAIBatteryPlatter sharedInstance]];
						[[self stackView] insertArrangedSubview:[KAIBatteryPlatter sharedInstance] atIndex:2];
					} else {
						[[self stackView] removeArrangedSubview:[KAIBatteryPlatter sharedInstance]];
						[[self stackView] insertArrangedSubview:[KAIBatteryPlatter sharedInstance] atIndex:0];
					}
				} else {
					[[self stackView] removeArrangedSubview:[KAIBatteryPlatter sharedInstance]];
					[[self stackView] insertArrangedSubview:[KAIBatteryPlatter sharedInstance] atIndex:0];
				}
			}

		} @catch (NSException *exc) {}

		[[KAIBatteryPlatter sharedInstance] calculateHeight];

	}

	if([KAISelf.superview respondsToSelector:@selector(fixComplicationsViewFrame)]) {
		[(NCNotificationListView *)(KAISelf.superview) fixComplicationsViewFrame];
	} //damn complications

}

- (void)setClipsToBounds:(BOOL)arg1 {
    %orig(YES);
}

- (void)setStackView:(UIStackView *)arg1 {
	KAISelf.clipsToBounds = YES;

	if(!KAISelf.hasKai) {

		list = self;

		KAIBatteryPlatter *battery = [[KAIBatteryPlatter alloc] initWithFrame:[self stackView].frame];

		//Add noti observer
		[[NSNotificationCenter defaultCenter] addObserver:self
			selector:@selector(KaiInfo)
			name:@"KaiInfoChanged"
			object:nil];
		KAISelf.hasKai = YES;

	if(![arg1.subviews containsObject:battery]) { //if not added
		//add kai to the stack view
		[arg1 addArrangedSubview:battery];
	}
	[battery updateBattery];

	//send the adjusted stackview as arg1 
	%orig(arg1);

	}
}

%new
- (void)KaiInfo {

	if(!isUpdating) {

		isUpdating = YES;

		//NSLog(@"kai: kai info will update");
		dispatch_async(dispatch_get_main_queue(), ^{

		[[KAIBatteryPlatter sharedInstance] updateBattery];
		if([KAIBatteryPlatter sharedInstance].number == 0) {
			[[KAIBatteryPlatter sharedInstance] removeFromSuperview];
			[[self stackView] removeArrangedSubview:[KAIBatteryPlatter sharedInstance]];
		} else if(![[self stackView].subviews containsObject:[KAIBatteryPlatter sharedInstance]] && shouldBeAdded) {
			[[self stackView] addSubview:[KAIBatteryPlatter sharedInstance]];
			[[self stackView] addArrangedSubview:[KAIBatteryPlatter sharedInstance]];
		}
		if([KAISelf.superview respondsToSelector:@selector(fixComplicationsViewFrame)]) {
		[KAISelf.superview performSelector:@selector(fixComplicationsViewFrame) withObject:KAISelf.superview afterDelay:0.35];
		}

		isUpdating = NO;
		});

	}

}

%new
+ (id)sharedListViewForKai {
	return list;
}

%end

%hook SBCoverSheetPrimarySlidingViewController

- (void)viewDidDisappear:(BOOL)animated {
	if(reAlignSelf)
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KaiResetOffset" object:nil userInfo:nil];
	%orig;
}

- (void)viewDidAppear:(BOOL)animated {
	if(reAlignSelf)
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KaiResetOffset" object:nil userInfo:nil];
	%orig;
}

%end

%hook BCBatteryDevice
%property (nonatomic, strong) KAIBatteryCell *kaiCell;

- (void)setCharging:(BOOL)arg1 {
	//sends the noti to update battery info
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KaiInfoChanged" object:nil userInfo:nil];
	%orig;
}

- (void)setBatterySaverModeActive:(BOOL)arg1 {
	//sends the noti to update battery info
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KaiInfoChanged" object:nil userInfo:nil];
	%orig;
}

- (void)setPercentCharge:(NSInteger)arg1 {
	//sends the noti to update battery info
	if(arg1!=0) {
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KaiInfoChanged" object:nil userInfo:nil];
	}
	%orig;
}

- (void)dealloc {
	%orig;
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KaiInfoChanged" object:nil userInfo:nil];
}

%new
- (id)kaiCellForDevice {
	if(self && self.kaiCell == nil) {
		self.kaiCell = [[KAIBatteryCell alloc] initWithFrame:CGRectMake(0,0,[KAIBatteryPlatter sharedInstance].frame.size.width,0) device:self]; }
		((KAIBatteryCell *)self.kaiCell).translatesAutoresizingMaskIntoConstraints = NO;
		[(KAIBatteryCell *)self.kaiCell updateInfo];

	return self.kaiCell;
}

%new
- (void)resetKaiCellForNewPrefs {
	self.kaiCell = [[KAIBatteryCell alloc] initWithFrame:CGRectMake(0,0,[KAIBatteryPlatter sharedInstance].frame.size.width,0) device:self]; 
		((KAIBatteryCell *)self.kaiCell).translatesAutoresizingMaskIntoConstraints = NO;
		[(KAIBatteryCell *)self.kaiCell updateInfo];
}
%end

%hook KAICSTarget //Again, not a class

- (void)_transitionChargingViewToVisible:(BOOL)arg1 showBattery:(BOOL)arg2 animated:(BOOL)arg3 {
	if(hideChargingAnimation) {
		//Yeah bro this just makes the method never call to show the charging thing
		%orig(NO,NO,NO);
	}
}

- (void)_transitionChargingViewToVisible:(BOOL)arg1 showBattery:(BOOL)arg2 animated:(BOOL)arg3 force:(BOOL)arg4 { //might just be ios12
	if(hideChargingAnimation) {
		//Same idea
		%orig(NO,NO,NO,NO);
	}
}

%end

%end

%ctor {
	preferencesChanged();
	CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        &observer,
        (CFNotificationCallback)applyPrefs,
        kSettingsChangedNotification,
        NULL,
        CFNotificationSuspensionBehaviorDeliverImmediately
    );

	//Bro Muirey helped me figure out a logical way to do this because iOS 12-13 classes have changed

	mediaClass = kCFCoreFoundationVersionNumber > 1600 ? ([objc_getClass("CSAdjunctItemView") class]) : ([objc_getClass("SBDashBoardAdjunctItemView") class]);

	Class cls = kCFCoreFoundationVersionNumber > 1600 ? ([objc_getClass("CSAdjunctListView") class]) : ([objc_getClass("SBDashBoardAdjunctListView") class]);

	Class CSCls = kCFCoreFoundationVersionNumber > 1600 ? ([objc_getClass("CSCoverSheetViewController") class]) : ([objc_getClass("SBDashBoardViewController") class]);

	if(enabled) {
		%init(main, Media = mediaClass, KAITarget = cls, KAICSTarget = CSCls); //BIG BRAIN BRO!!
	}

	NSLog(@"[kai]: loaded into %@", [NSBundle mainBundle].bundleIdentifier);
}
