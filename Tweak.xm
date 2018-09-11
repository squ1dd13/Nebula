#define COLORS_PLIST_PATH @"/var/mobile/Library/Preferences/com.octodev.nebulacolors.plist"
#define SETTINGS_PLIST_PATH @"/var/mobile/Library/Preferences/com.octodev.nebula.plist"
#define STYLESHEET_PATH @"/Library/Application Support/Nebula/7374796c65.st"
#define BACKUP_STYLESHEET_PATH @"/Library/Application Support/Nebula/7374796c66.st"
#define APPS_PLIST_PATH @"/var/mobile/Library/Preferences/com.octodev.nebula-apps.plist"
#define stylesPath @"/Library/Application Support/Nebula/Themes"
#define safariDarkmode PreferencesBool(@"safariDarkmode", YES)
#define inSafari ([[((UIView*)self) window] isMemberOfClass:%c(MobileSafariWindow)])
#define inChrome ([[((UIView*)self) window] isMemberOfClass:%c(ChromeOverlayWindow)])
#define chromeDarkmode PreferencesBool(@"chromeDarkmode", YES)
#define enabled PreferencesBool(@"enabled", YES)
#define hapticEnabled PreferencesBool(@"hapticEnabled", YES)
#define disableInSpringboard PreferencesBool(@"disableInSpringboard", YES)

#include "libcolorpicker.h"
#include "nebula.h"
#import <objc/runtime.h>

@import WebKit;
@import UIKit;

static UIBarButtonItem *nightModeButton = nil;
static NSString *stylesheetFromHex;
static NSString *backupStylesheet;
static BOOL darkMode = YES;
static NSMutableDictionary *customStyles;
static NSArray *backupStylesheetSites = @[];
static NSArray *blacklist;
static NSString* bgColorHex;
static NSString* darkerColorHex;
static NSString* textColorHex;
static NSDictionary* preferences;

static BOOL PreferencesBool(NSString* key, BOOL fallback)
{
	return preferences[key] ? [preferences[key] boolValue] : fallback;
}

void loadStylesheetsFromFiles() {
	NSError *err;
	stylesheetFromHex = [NSString stringWithContentsOfFile:STYLESHEET_PATH encoding:NSUTF8StringEncoding error:&err];
	stylesheetFromHex = fromDoubleHex(stylesheetFromHex, @"You can go away now.\n");

	if(err) NSLog(@"ERROR: %@", err.localizedFailureReason);
	err = nil; //if there is an error on this one, the next one will log an error without there being one unless we set this to nil

	backupStylesheet = [NSString stringWithContentsOfFile:BACKUP_STYLESHEET_PATH encoding:NSUTF8StringEncoding error:&err];
	backupStylesheet = fromDoubleHex(backupStylesheet, @"You can go away now.\n");

	if(err) NSLog(@"ERROR: %@", err.localizedFailureReason);
	err = nil;

	//load custom stylesheets:
	customStyles = [NSMutableDictionary dictionary];

	NSArray *possibleStyles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:stylesPath error:&err];
	NSArray *validStyles;
	if(err) {
		NSLog(@"Failed to fetch styles folder contents");
	} else {
		//we only want css files. .min.css will also load
		 validStyles = [possibleStyles filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF ENDSWITH %@", @"css"]];
		//files should have a /* <host of site> */ comment at the top
		for(NSString *file in validStyles) {
			NSString *fileContents = [NSString stringWithContentsOfFile:[[stylesPath stringByAppendingString:@"/"] stringByAppendingString:file] encoding:NSUTF8StringEncoding error:nil];

			NSString *hostLine = [fileContents componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]][0];

			if(!([hostLine hasPrefix:@"/*"] && [hostLine hasSuffix:@"*/"])) {
				continue;
			}
			NSString *host = stringBetween(hostLine, @"/*", @"*/");
			NSLog(@"%@", host);
			if([host containsString:@","]) {
				NSArray *hosts = [host componentsSeparatedByString:@","];
				for(NSString *h in hosts) {
					[customStyles setValue:file forKey:[h stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
				}
			}
			host = [host stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
			[customStyles setValue:file forKey:host]; //so we can load this stylesheet based on the host later
			NSLog(@"%@", file);
			NSLog(@"styles %@", customStyles);
		}
	}
}

void loadBlacklist()
{
	NSArray* neverLoadInto = @[@"www.apple.com", @"mobile.twitter.com"];
	blacklist = preferences[@"blacklistArray"] ? preferences[@"blacklistArray"] : [NSArray new];
	blacklist = blacklist ? [blacklist arrayByAddingObjectsFromArray:neverLoadInto] : [[NSArray alloc] initWithArray:neverLoadInto];
}

void changeColorsInStylesheets()
{
	//change colours in main stylesheet
	stylesheetFromHex = [stylesheetFromHex stringByReplacingOccurrencesOfString:@"NEBULA_DARKER" withString:darkerColorHex];
	stylesheetFromHex = [stylesheetFromHex stringByReplacingOccurrencesOfString:@"NEBULA_DARK" withString:bgColorHex];
	stylesheetFromHex = [stylesheetFromHex stringByReplacingOccurrencesOfString:@"NEBULA_TEXT" withString:textColorHex];

	//change colours in backup stylesheet
	backupStylesheet = [backupStylesheet stringByReplacingOccurrencesOfString:@"NEBULA_DARKER" withString:darkerColorHex];
	backupStylesheet = [backupStylesheet stringByReplacingOccurrencesOfString:@"NEBULA_DARK" withString:bgColorHex];
	backupStylesheet = [backupStylesheet stringByReplacingOccurrencesOfString:@"NEBULA_TEXT" withString:textColorHex];
}

static void ColorChangedCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	NSDictionary* colors;
	CFStringRef appID = CFSTR("com.octodev.nebulacolors");
    CFArrayRef keyList = CFPreferencesCopyKeyList(appID, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    if (!keyList) {
        NSLog(@"There's been an error getting the key list!");
        return;
    }
    colors = (__bridge NSDictionary *)CFPreferencesCopyMultiple(keyList, appID, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    if (!colors) {
        NSLog(@"There's been an error getting the preferences dictionary!");
    }
    CFRelease(keyList);
	bgColorHex = colors[@"backgroundColor"] ? [colors[@"backgroundColor"] substringWithRange:NSMakeRange(0, 7)] : @"#262626";
	textColorHex = colors[@"textColor"] ? [colors[@"textColor"] substringWithRange:NSMakeRange(0, 7)] : @"#ededed";
	darkerColorHex = makeHexColorDarker(bgColorHex, 15);
	changeColorsInStylesheets();
}

static void PreferencesChangedCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
	preferences = nil;
	CFStringRef appID = CFSTR("com.octodev.nebula");
	CFArrayRef keyList = CFPreferencesCopyKeyList(appID, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
	if (!keyList) {
		NSLog(@"There's been an error getting the key list!");
		return;
	}
	preferences = (__bridge NSDictionary *)CFPreferencesCopyMultiple(keyList, appID, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
	if (!preferences) {
		NSLog(@"There's been an error getting the preferences dictionary!");
	}
	CFRelease(keyList);
}

@interface NBLBroadcaster : NSObject
@property (nonatomic, readonly) BOOL darkModeEnabled;
@end

@implementation NBLBroadcaster
static NBLBroadcaster *sharedInstance;

+(void)initialize {
	if([NBLBroadcaster class] == self) {
		sharedInstance = [self new];
	}
}

+(NBLBroadcaster *)sharedBroadcaster {
	return sharedInstance;
}

+(id)allocWithZone:(struct _NSZone *)zone {
	if(sharedInstance && [NBLBroadcaster class] == self) {
		[NSException raise:NSGenericException format:@"Multiple instances of NBLBroadcaster cannot be created"];
	}
	return [super allocWithZone:zone];
}

-(BOOL)darkModeEnabled {
	return darkMode;
}

-(void)toggleDarkmode:(BOOL)takeYourPick {
	[[NSNotificationCenter defaultCenter] postNotificationName:@"NebulaToggle" object:@(takeYourPick) userInfo:nil];
}

-(void)forceToggleDarkmode:(BOOL)takeYourPick {
	darkMode = takeYourPick;
}

@end

%group Nebula
%hook UIKBRenderConfig

%new
+(void)updateAllConfigs {
	[[self darkConfig] setLightKeyboard:!darkMode];
	[[self defaultConfig] setLightKeyboard:!darkMode];
	[[self defaultEmojiConfig] setLightKeyboard:!darkMode];
	[[self lowQualityDarkConfig] setLightKeyboard:!darkMode];
}
%end

//add button to toolbar
%hook BrowserToolbar
%property (nonatomic, assign) UIButton *darkButton;

-(void)layoutSubviews
{
	%orig;
	if (safariDarkmode)
	{
		[self setInteractionTintColor:LCPParseColorString(textColorHex, @"")];
	}
}

-(void)setBarStyle:(NSInteger)arg1
{
	if (inSafari && safariDarkmode)
	{
		arg1 = UIBarStyleBlack;
	}
	%orig;
}

-(void)didMoveToWindow
{
	%orig;
	if (inSafari && safariDarkmode)
	{
		[self setBarStyle:UIBarStyleBlack];
	}
}

-(void)setItems:(NSArray *)items animated:(BOOL)anim {
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"Reset" object:nil]; //clear up before we add it again
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resetButton) name:@"Reset" object:nil];

	self.darkButton = [UIButton buttonWithType:UIButtonTypeCustom];
	[self.darkButton setFrame:CGRectMake(0, 0, 24, 24)];
	[self.darkButton addTarget:self action:@selector(nightMode:) forControlEvents:UIControlEventTouchUpInside];
	[self.darkButton setSelected:darkMode];

	//cheers pinpal
	[self.darkButton setImage:[resizeImage([UIImage imageWithContentsOfFile:@"/Applications/MobileSafari.app/Dark.png"], CGSizeMake(24, 24)) imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
	[self.darkButton setImage:[resizeImage([UIImage imageWithContentsOfFile:@"/Applications/MobileSafari.app/Light.png"], CGSizeMake(24, 24)) imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateSelected];

	nightModeButton = [[UIBarButtonItem alloc] initWithCustomView:self.darkButton];

	NSMutableArray *buttons = [items mutableCopy];
	if(!(UIInterfaceOrientationIsLandscape([[UIApplication sharedApplication] statusBarOrientation]))) {
		UIBarButtonItem *space = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
		space.width = 30;
		[buttons addObject:space];
	} else {
		for(UIBarButtonItem *item in buttons) {
			if(item.width > 10) {
				item.width = 5;
			}
		}
	}

	[buttons addObject:nightModeButton];
	items = [buttons copy];
	%orig;
}

//called when the button is pressed
%new
-(void)nightMode:(UIButton *)button {
	if (hapticEnabled) { AudioServicesPlaySystemSound(1519); }
	//fade
	[UIView transitionWithView:button
				   duration:0.1
				    options:UIViewAnimationOptionTransitionCrossDissolve
				 animations:^{ button.selected = !button.selected; }
				 completion:nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"NebulaToggle" object:@(button.selected) userInfo:nil];
}

//resets the button to its default value
%new
-(void)resetButton {
	[self.darkButton setSelected:NO];
}

%end

@interface WKWebView (Nebula)
@property (nonatomic, assign) BOOL hasInjected;
@property (nonatomic, copy) NSString *originalHead;
-(void)goDark;
-(void)reload;
-(void)runJavaScript:(NSString *)js completion:(id)comp;
-(NSString *)getJavaScriptOutput:(NSString *)js;
-(void)revertInjection;
@end

%hook WKWebView
%property (nonatomic, assign) BOOL hasInjected;
%property (nonatomic, copy) NSString *originalHead;

-(void)_didCommitLoadForMainFrame
{
	%orig;
	if (darkMode && ![blacklist containsObject:[[self URL] host]])
	{
		self.alpha = 0;
		[self superview].backgroundColor = LCPParseColorString(bgColorHex, @"");
	}
}

-(void)_didFinishLoadForMainFrame {
	%orig;
	self.hasInjected = NO;
	NSLog(@"Navigation ended.");

	//back up the original values
	self.originalHead = [self getJavaScriptOutput:@"document.getElementsByTagName(\"head\")[0].innerHTML"];

	if (darkMode && ![blacklist containsObject:[[self URL] host]]) {
		[self goDark];
	} else {
		[self revertInjection];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"Reset" object:nil userInfo:nil];
	}

	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"NebulaToggle" object:nil]; //clear up before we add it again
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(toggleInjection:) name:@"NebulaToggle" object:nil];
}

%new
-(void)toggleInjection:(NSNotification *)notification {
	[[NSNotificationCenter defaultCenter] postNotificationName:(darkMode) ? @"NebulaDark" : @"NebulaLight" object:nil userInfo:nil];

	darkMode = [[notification object] boolValue];

	[[notification object] boolValue] ? [self goDark] : [self revertInjection];
	[%c(UIKBRenderConfig) updateAllConfigs];
}

%new
-(void)goDark {
	if(!self.hasInjected && ![blacklist containsObject:[[self URL] host]]) {
		NSString *stylesheet = [NSString stringWithFormat:@"%@", stylesheetFromHex];

		NSString *host = [[self URL] host];
		NSLog(@"%@ css: %@", host, [customStyles valueForKey:host]);
		if(host && [customStyles valueForKey:host]) {
			NSString *custom = [NSString stringWithContentsOfFile:[[stylesPath stringByAppendingString:@"/"] stringByAppendingString:[customStyles valueForKey:host]] encoding:NSUTF8StringEncoding error:nil];
			custom = [custom stringByReplacingOccurrencesOfString:@"NEBULA_DARKER" withString:darkerColorHex];
			custom = [custom stringByReplacingOccurrencesOfString:@"NEBULA_DARK" withString:bgColorHex];
			custom = [custom stringByReplacingOccurrencesOfString:@"NEBULA_TEXT" withString:textColorHex];
			stylesheet = custom;
		}
		else if (host && [backupStylesheetSites containsObject:host]) //see if host should use backup stylesheet
		{
			stylesheet = backupStylesheet;
		}

		NSString *head = [self getJavaScriptOutput:@"document.getElementsByTagName(\"head\")[0].innerHTML"];
		if (head)
		{
			NSString *modifiedHead = [head stringByAppendingString:[NSString stringWithFormat:@"\n<style>%@</style>", stylesheet]];
			[self runJavaScript:[NSString stringWithFormat:@"document.getElementsByTagName(\"head\")[0].innerHTML = `%@`;", modifiedHead] completion:^{
				self.alpha = 1;
			}];
		}
		self.hasInjected = YES;
	}
}

%new
-(void)revertInjection {
	if (self.hasInjected)
	{
		self.hasInjected = NO;
		NSLog(@"Reverting changes");
		[self runJavaScript:[NSString stringWithFormat:@"document.getElementsByTagName(\"head\")[0].innerHTML = `%@`;", self.originalHead] completion:nil];
	}
}

%new
-(void)runJavaScript:(NSString *)js completion:(void (^)())comp {
	__block BOOL finished = NO;

	[self evaluateJavaScript:js completionHandler:^(id result, NSError *error) {
		finished = YES;
		[comp invoke];
	}];
	while (!finished) {
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
	}
}

%new
-(NSString *)getJavaScriptOutput:(NSString *)js {
	__block NSString *resultString = nil;
	__block BOOL finished = NO;

	[self evaluateJavaScript:js completionHandler:^(id result, NSError *error) {
		if (error == nil) {
			if (result != nil) {
				resultString = [NSString stringWithFormat:@"%@", result];
			}
		}
		finished = YES;
	}];
	while (!finished) {
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
	}
	return resultString;
}

%end

%hook BrowserController

-(void)setWebView:(id)web {
	%orig;
	if(![[self valueForKeyPath:@"wkPreferences.javaScriptEnabled"] boolValue]) {
		static dispatch_once_t onceToken;
		dispatch_once(&onceToken, ^{
			NSLog(@"Javascript is disabled.");
			//warn the user
			void (^change)(void) = ^{
				NSString *plistPath = [[[NSUserDefaults standardUserDefaults] stringForKey:@"WebDatabaseDirectory"] stringByReplacingOccurrencesOfString:@"/WebKit/WebsiteData/WebSQL" withString:@"/Preferences/com.apple.mobilesafari.plist"];
				NSMutableDictionary *prefs = [[NSDictionary dictionaryWithContentsOfURL:[NSURL URLWithString:plistPath]] mutableCopy];
				[prefs setValue:@YES forKey:@"JavaScriptEnabled"];
				[[prefs copy] writeToURL:[NSURL URLWithString:plistPath] atomically:YES];
				[self setValue:@YES forKeyPath:@"wkPreferences.javaScriptEnabled"];
				//changing the NSUserDefaults value will change the plist anyway but idc
				[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"JavaScriptEnabled"];
			};
			UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"JavaScript Disabled"
															   message:@"Dark mode requires JavaScript to be enabled in order to work correctly."
                           									 preferredStyle:UIAlertControllerStyleAlert];

			UIAlertAction *ignore = [UIAlertAction actionWithTitle:@"Ignore" style:UIAlertActionStyleDestructive
																 handler:^(UIAlertAction * action) {}];

			UIAlertAction *enable = [UIAlertAction actionWithTitle:@"Enable" style:UIAlertActionStyleDefault
														 			handler:^(UIAlertAction * action) {
																		change();
																		[web performSelector:@selector(reload)];
																		}];

			[alert addAction:ignore];
			[alert addAction:enable];
			[[[[UIApplication sharedApplication] keyWindow] rootViewController] presentViewController:alert animated:YES completion:nil];
		});
	}
}

%end

%hook UIWebView
-(void)webView:(id)arg1 didCommitLoadForFrame:(id)arg2
{
	%orig;
	if (darkMode && ![blacklist containsObject:[[(WebFrame*)arg2 webui_URL] host]])
	{
		[(WebFrame*)arg2 frameView].hidden = YES;
	}
}

-(void)webView:(id)arg1 didFinishLoadForFrame:(id)arg2
{
	%orig;
	NSLog(@"Navigation ended.");

	if (darkMode && ![blacklist containsObject:[[(WebFrame*)arg2 webui_URL] host]]) {
		[self goDarkForFrame:arg2];
		[(WebFrame*)arg2 frameView].hidden = NO;
	}
}
/*
David Attenborough: For frames, going dark is a sign of affection towards another frame.
Boy frame: I would do anything for you
Girl frame: Would you go dark for me?
Boy frame: *goes dark for girl frame*
*/
%new
-(void)goDarkForFrame:(id)arg1 {
	WebFrame* webFrame = (WebFrame*)arg1;
	NSString *stylesheet = [NSString stringWithFormat:@"%@", stylesheetFromHex];

	NSString *host = [[webFrame webui_URL] host];
	NSLog(@"%@ css: %@", host, [customStyles valueForKey:host]);
	if(host && [customStyles valueForKey:host]) {
		NSString *custom = [NSString stringWithContentsOfFile:[[stylesPath stringByAppendingString:@"/"] stringByAppendingString:[customStyles valueForKey:host]] encoding:NSUTF8StringEncoding error:nil];
		custom = [custom stringByReplacingOccurrencesOfString:@"NEBULA_DARKER" withString:darkerColorHex];
		custom = [custom stringByReplacingOccurrencesOfString:@"NEBULA_DARK" withString:bgColorHex];
		custom = [custom stringByReplacingOccurrencesOfString:@"NEBULA_TEXT" withString:textColorHex];
		stylesheet = custom;
	}
	else if (host && [backupStylesheetSites containsObject:host]) //see if host should use backup stylesheet
	{
		stylesheet = backupStylesheet;
	}

	NSString *head = [webFrame _stringByEvaluatingJavaScriptFromString:@"document.getElementsByTagName(\"head\")[0].innerHTML"];
	if (head)
	{
		NSString *modifiedHead = [head stringByAppendingString:[NSString stringWithFormat:@"\n<style>%@</style>", stylesheet]];
		[webFrame _stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"document.getElementsByTagName(\"head\")[0].innerHTML = `%@`;", modifiedHead]];
	}
}
%end


%hook SFSafariViewController
%property (nonatomic, assign) UIButton *darkButton;

-(void)viewDidLayoutSubviews {
	%orig;
	NSLog(@"Hello world!");
	[(NSObject *)self performSelector:@selector(setToolbarItems:) withObject:@[]];
}

-(void)setToolbarItems:(NSArray *)items {
	NSLog(@"Setting.");
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"Reset" object:nil]; //clear up before we add it again
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resetButton) name:@"Reset" object:nil];

	self.darkButton = [UIButton buttonWithType:UIButtonTypeCustom];
	[self.darkButton setFrame:CGRectMake(0, 0, 20, 20)];
	[self.darkButton addTarget:self action:@selector(nightMode:) forControlEvents:UIControlEventTouchUpInside];
	[self.darkButton setSelected:darkMode];

	//cheers pinpal
	[self.darkButton setImage:[resizeImage([UIImage imageWithContentsOfFile:@"/Applications/MobileSafari.app/Dark.png"], CGSizeMake(20, 20)) imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
	[self.darkButton setImage:[resizeImage([UIImage imageWithContentsOfFile:@"/Applications/MobileSafari.app/Light.png"], CGSizeMake(20, 20)) imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateSelected];

	nightModeButton = [[UIBarButtonItem alloc] initWithCustomView:self.darkButton];

	NSMutableArray *buttons = [items mutableCopy];
	if(!(UIInterfaceOrientationIsLandscape([[UIApplication sharedApplication] statusBarOrientation]))) {
		UIBarButtonItem *space = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
		space.width = 30;
		[buttons addObject:space];
	} else {
		for(UIBarButtonItem *item in buttons) {
			if(item.width > 10) {
				item.width = 5;
			}
		}
	}

	[buttons addObject:nightModeButton];
	items = [buttons copy];
	%orig;
}

//called when the button is pressed
%new
-(void)nightMode:(UIButton *)button {
	AudioServicesPlaySystemSound(1519);
	//fade
	[UIView transitionWithView:button
				   duration:0.1
				    options:UIViewAnimationOptionTransitionCrossDissolve
				 animations:^{ button.selected = !button.selected; }
				 completion:nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"NebulaToggle" object:@(button.selected) userInfo:nil];
}

//resets the button to its default value
%new
-(void)resetButton {
	[self.darkButton setSelected:NO];
}
%end

//for the respring animation
%hook UIStatusBar

-(void)layoutSubviews {
	%orig;

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(fadeOut) name:@"UIStatusBarHide" object:nil];
}

%new
-(void)fadeOut {
	[UIView animateWithDuration:0.3 animations:^() {
		((UIView *)self).alpha = 0.0; //smooth
	}];
}

%end

%hook _UIStatusBar

-(void)layoutSubviews {
	%orig;

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(fadeOut) name:@"UIStatusBarHide" object:nil];
}

%new
-(void)fadeOut {
	[UIView animateWithDuration:0.3 animations:^() {
		((UIView *)self).alpha = 0.0; //smooth
	}];
}

%end

%hook UILabel
-(void)didMoveToWindow
{
	%orig;
	if ((inSafari && safariDarkmode) || (inChrome && chromeDarkmode && ![self isMemberOfClass:%c(TitleLabel)] && ![[self _viewControllerForAncestor] isMemberOfClass:%c(GFBFeedbackViewController)] && ![[self _viewControllerForAncestor] isMemberOfClass:%c(TabGridViewController)]))
	{
		self.textColor = LCPParseColorString(textColorHex, @"");
		self.backgroundColor = [UIColor clearColor];
	}
}

-(void)layoutSubviews
{
	%orig;
	if ((inSafari && safariDarkmode) || (inChrome && chromeDarkmode && ![self isMemberOfClass:%c(TitleLabel)] && ![[self _viewControllerForAncestor] isMemberOfClass:%c(GFBFeedbackViewController)] && ![[self _viewControllerForAncestor] isMemberOfClass:%c(TabGridViewController)]))
	{
		self.textColor = LCPParseColorString(textColorHex, @"");
		self.backgroundColor = [UIColor clearColor];
	}
}

-(void)setTextColor:(id)arg1
{
	if ((inSafari && safariDarkmode) || (inChrome && chromeDarkmode && ![self isMemberOfClass:%c(TitleLabel)] && ![[self _viewControllerForAncestor] isMemberOfClass:%c(GFBFeedbackViewController)]))
	{
		arg1 = LCPParseColorString(textColorHex, @"");
	}
	%orig;
}

-(void)setBackgroundColor:(id)arg1
{
	if ((inSafari && safariDarkmode) || (inChrome && chromeDarkmode && ![self isMemberOfClass:%c(TitleLabel)] && ![[self _viewControllerForAncestor] isMemberOfClass:%c(GFBFeedbackViewController)]))
	{
		arg1 = [UIColor clearColor];
	}
	%orig;
}
%end

%hook UINavigationBar
-(void)layoutSubviews
{
    %orig;
	if ((inSafari && safariDarkmode) || (inChrome && chromeDarkmode))
	{
		[self setBarStyle:UIBarStyleBlack];
	}
}
%end

%hook UIToolbar
-(void)didMoveToWindow
{
	%orig;
	if ((inSafari && safariDarkmode) || (inChrome && chromeDarkmode))
	{
		self.barTintColor = LCPParseColorString(darkerColorHex, @"");
	}
}

-(void)setBarTintColor:(id)arg1
{
	if ((inSafari && safariDarkmode) || (inChrome && chromeDarkmode))
	{
		arg1 = LCPParseColorString(darkerColorHex, @"");
	}
	%orig;
}
%end

%hook UITableView
-(void)layoutSubviews
{
	%orig;
	if ((inSafari && safariDarkmode) || (inChrome && chromeDarkmode))
	{
		self.backgroundColor = LCPParseColorString(bgColorHex, @"");
	}
}
%end

%hook UITableViewCell
-(void)layoutSubviews
{
	%orig;
	if ((inSafari && safariDarkmode) || (inChrome && chromeDarkmode))
	{
		self.backgroundColor = LCPParseColorString(bgColorHex, @"");
		self.selectedBackgroundView.backgroundColor = LCPParseColorString(makeHexColorDarker(bgColorHex, -25), @"");
		if ([self.selectedBackgroundView respondsToSelector:@selector(selectionTintColor)])
		{
			((UITableViewCellSelectedBackground*)self.selectedBackgroundView).selectionTintColor = LCPParseColorString(makeHexColorDarker(bgColorHex, -25), @"");
		}
	}
}
%end
%end

%group SafariOnly
/* Safari darkmode */
%hook _UIBackdropView
-(void)didMoveToWindow
{
	%orig;
	if ([self style] != 2030 && safariDarkmode)
	{
		[self transitionToPrivateStyle:1];
	}
}

-(void)setStyle:(NSInteger)arg1
{
	%orig;
	if ([self style] != 2030 && safariDarkmode)
	{
		[self transitionToPrivateStyle:1];
	}
}
%end

%hook BookmarkFavoritesCollectionView
-(void)setBackgroundColor:(id)arg1
{
	if (safariDarkmode)
	{
		arg1 = LCPParseColorString(bgColorHex, @"");
	}
	%orig;
}
%end

%hook BookmarkFavoriteView
-(void)didMoveToWindow
{
	%orig;
	if (safariDarkmode)
	{
		NSString *keyPath = [[((NSObject *)self) valueForKey:@"_titleLabel"] respondsToSelector:@selector(setTextColor:)] ? @"_titleLabel.textColor" : @"_titleLabel.nonVibrantColor";
		[((NSObject *)self) setValue:LCPParseColorString(textColorHex, @"") forKeyPath:keyPath];
	}
}
%end

%hook CatalogViewController
-(void)viewDidLayoutSubviews
{
	%orig;
	if (safariDarkmode)
	{
		((UIViewController *)self).view.backgroundColor = LCPParseColorString(bgColorHex, @"");
	}
}
%end

%hook MobileSafariWindow
-(void)setBackgroundColor:(id)arg1
{
	if (safariDarkmode)
	{
		arg1 = LCPParseColorString(bgColorHex, @"");
	}
	%orig;
}
%end

%hook UISearchBar
-(void)didMoveToWindow
{
    %orig;
	if (safariDarkmode)
	{
		[self setBarStyle:UIBarStyleBlack];
		((UITextField*)[self valueForKey:@"searchField"]).textColor = LCPParseColorString(textColorHex, @"");
	}
}

-(void)setBarStyle:(NSInteger)arg1
{
	if (safariDarkmode)
	{
		arg1 = UIBarStyleBlack;
	}
	%orig;
}
%end

%hook _UITableViewHeaderFooterViewBackground
-(void)didMoveToWindow
{
	%orig;
	if (safariDarkmode)
	{
		((UIView*)self).backgroundColor = LCPParseColorString(makeHexColorDarker(bgColorHex, -25), @"");
	}
}

-(void)layoutSubviews
{
	%orig;
	if (safariDarkmode)
	{
		((UIView*)self).backgroundColor = LCPParseColorString(makeHexColorDarker(bgColorHex, -25), @"");
	}
	%orig;
}

-(void)setBackgroundColor:(id)arg1
{
	if (safariDarkmode)
	{
		arg1 = LCPParseColorString(makeHexColorDarker(bgColorHex, -25), @"");
	}
	%orig;
}
%end

%hook TabThumbnailHeaderView
-(id)backgroundView
{
	UIView* o = %orig;
	if (safariDarkmode)
	{
		o.backgroundColor = LCPParseColorString(bgColorHex, @"");
	}
	return o;
}
%end

%hook _SFQuickLookDocumentView
-(void)setBackgroundColor:(id)arg1
{
	if (safariDarkmode)
	{
		arg1 = LCPParseColorString(bgColorHex, @"");
	}
	%orig;
}
%end
/* End safari darkmode */
%end

%group ChromeOnly
/* Chrome darkmode */
%hook ToolbarConfiguration
-(NSInteger)style
{
	if (chromeDarkmode)
	{
		return 1;
	}
	return %orig;
}
%end

%hook OmniboxTextFieldIOS
-(BOOL)incognito
{
	if (chromeDarkmode)
	{
		return YES;
	}
	return %orig;
}

-(id)initWithFrame:(CGRect)arg1 font:(id)arg2 textColor:(id)arg3 tintColor:(id)arg4
{
	if (chromeDarkmode)
	{
		arg3 = LCPParseColorString(textColorHex, @"");
		arg4 = LCPParseColorString(textColorHex, @"");
	}
	return %orig;
}

-(id)selectedTextBackgroundColor
{
	if (chromeDarkmode)
	{
		return [UIColor colorWithWhite:1 alpha:0.1];
	}
	return %orig;
}

-(id)placeholderTextColor
{
	if (chromeDarkmode)
	{
		return [UIColor colorWithWhite:1 alpha:0.5];
	}
	return %orig;
}
%end

%hook UIImageView
-(void)didMoveToSuperview
{
	%orig;
	if ([[self superview] isKindOfClass:%c(MDCCollectionViewCell)])
	{
		[self removeFromSuperview];
	}
}

-(void)setImage:(id)image
{
	if (([[self superview] isKindOfClass:%c(ToolbarButton)] || [[[self superview] superview] isMemberOfClass:%c(OmniboxTextFieldIOS)] || [[self superview] isKindOfClass:%c(ToolbarCenteredButton)] || [[self superview] isKindOfClass:%c(NewTabPageBarButton)] || [[self _viewControllerForAncestor] isMemberOfClass:%c(ToolsMenuViewController)] || [[self superview] isMemberOfClass:%c(MDCButtonBarButton)]) && chromeDarkmode)
	{
		image = changeImageToColor(image, LCPParseColorString(textColorHex, @""));
	}
	%orig;
}

-(void)setTintColor:(id)arg1
{
	if (chromeDarkmode && ([[self _viewControllerForAncestor] isMemberOfClass:%c(LocationBarViewController)] || [[self _viewControllerForAncestor] isMemberOfClass:%c(OmnioboxViewController)]))
	{
		arg1 = LCPParseColorString(textColorHex, @"");
	}
	%orig;
}
%end

%hook ToolbarToolsMenuButton
-(id)normalStateTint
{
	if (chromeDarkmode)
	{
		return LCPParseColorString(textColorHex, @"");
	}
	return %orig;
}
%end

%hook BrowserViewController
-(NSInteger)preferredStatusBarStyle
{
	if (chromeDarkmode)
	{
		return 1;
	}
	return %orig;
}

-(void)viewDidLoad
{
	%orig;
	if (chromeDarkmode)
	{
		((UIViewController*)self).view.backgroundColor = LCPParseColorString(bgColorHex, @"");
		((UIViewController*)self).view.subviews[0].backgroundColor = [UIColor clearColor];
	}
}
%end

%hook UIViewController
-(NSInteger)preferredStatusBarStyle
{
	if (chromeDarkmode && ([[self.view window] isMemberOfClass:%c(ChromeOverlayWindow)]))
	{
		return 1;
	}
	return %orig;
}
%end

%hook UICollectionView
-(void)didMoveToWindow
{
	%orig;
	if (inChrome && chromeDarkmode)
	{
		self.backgroundColor = LCPParseColorString(bgColorHex, @"");
	}
}
%end

%hook ContentSuggestionsCell
-(void)layoutSubviews
{
	%orig;
	if (chromeDarkmode && ((UIView*)self).subviews.count > 1)
	{
		((UIView*)self).subviews[1].backgroundColor = LCPParseColorString(bgColorHex, @"");
	}
}
%end

%hook ContentSuggestionsFooterCell
-(void)layoutSubviews
{
	%orig;
	if (chromeDarkmode && ((UIView*)self).subviews.count > 1)
	{
		((UIView*)self).subviews[1].backgroundColor = LCPParseColorString(bgColorHex, @"");
	}
}
%end

%hook OverscrollActionsView
-(void)setBackgroundColor:(id)arg1
{
	if (chromeDarkmode)
	{
		arg1 = LCPParseColorString(bgColorHex, @"");
	}
	%orig;
}
%end

%hook NewTabPageBar
-(void)setBackgroundColor:(id)arg1
{
	if (chromeDarkmode)
	{
		arg1 = LCPParseColorString(makeHexColorDarker(bgColorHex, 15), @"");
	}
	%orig;
}
%end

%hook ConfirmInfoBarView
-(void)setBackgroundColor:(id)arg1
{
	if (chromeDarkmode)
	{
		arg1 = LCPParseColorString(makeHexColorDarker(bgColorHex, 15), @"");
	}
	%orig;
}
%end

%hook PanelBarView
-(void)setBackgroundColor:(id)arg1
{
	if (chromeDarkmode)
	{
		arg1 = LCPParseColorString(makeHexColorDarker(bgColorHex, 15), @"");
	}
	%orig;
}
%end

%hook NewTabPageHeaderView
-(void)didMoveToWindow
{
	%orig;
	if (chromeDarkmode)
	{
		((UIView*)self).subviews[1].backgroundColor = LCPParseColorString(makeHexColorDarker(bgColorHex, 15), @"");
		((UIImageView*)((UIView*)self).subviews[1].subviews[0]).image = nil;
	}
}
%end

%hook ToolsMenuViewCell
-(void)setBackgroundColor:(id)arg1
{
	if (chromeDarkmode)
	{
		arg1 = LCPParseColorString(bgColorHex, @"");
	}
	%orig;
}
%end

%hook ToolsMenuViewToolsCell
-(void)didMoveToWindow
{
	%orig;
	if (chromeDarkmode)
	{
		((UIView*)self).backgroundColor = LCPParseColorString(bgColorHex, @"");
		((UIView*)self).subviews[0].backgroundColor = LCPParseColorString(bgColorHex, @"");
		for (UIView* v in ((UIView*)self).subviews[0].subviews)
		{
			v.backgroundColor = LCPParseColorString(bgColorHex, @"");
		}
	}
}
%end

%hook CollectionViewDetailCell
-(void)didMoveToWindow
{
	%orig;
	if (chromeDarkmode)
	{
		((UIView*)self).backgroundColor = LCPParseColorString(bgColorHex, @"");
		((UIImageView*)((UIView*)self).subviews[0]).image = nil;
	}
}
%end

%hook MDCCollectionViewCell
-(void)layoutSubviews
{
	%orig;
	if (chromeDarkmode)
	{
		((UIView*)self).backgroundColor = LCPParseColorString(bgColorHex, @"");
		for (UIView* v in ((UIView*)self).subviews)
		{
			if ([v isMemberOfClass:[UIImageView class]])
			{
				((UIImageView*)v).image = nil;
			}
		}
	}
}
%end

%hook MDCFlexibleHeaderView
-(void)setBackgroundColor:(id)arg1
{
	if (chromeDarkmode)
	{
		arg1 = LCPParseColorString(makeHexColorDarker(bgColorHex, 15), @"");
	}
	%orig;
}
%end

%hook BookmarkTableCell
-(void)setBackgroundColor:(id)arg1
{
	if (chromeDarkmode)
	{
		arg1 = LCPParseColorString(bgColorHex, @"");
	}
	%orig;
}
%end

%hook SelfSizingTableView
-(void)setBackgroundColor:(id)arg1
{
	if (chromeDarkmode)
	{
		arg1 = LCPParseColorString(bgColorHex, @"");
	}
	%orig;
}
%end

%hook OmniboxPopupTruncatingLabel
-(void)layoutSubviews
{
	%orig;
	if (chromeDarkmode)
	{
		CGFloat white;
		CGFloat alpha;
		[((UILabel*)self).textColor getWhite:&white alpha:&alpha];
		if (white <= 0.2)
		{
			((UILabel*)self).textColor = LCPParseColorString(textColorHex, @"");
		}
	}
}
%end

%hook FindBarView
-(void)didMoveToWindow
{
	%orig;
	if (chromeDarkmode)
	{
		((UIView*)self).superview.backgroundColor = LCPParseColorString(bgColorHex, @"");
	}
}
%end

%hook UITextField
-(void)didMoveToWindow
{
	%orig;
	if (chromeDarkmode)
	{
		self.textColor = LCPParseColorString(textColorHex, @"");
	}
}
%end

%hook ClearBrowsingBar
-(void)setBackgroundColor:(id)arg1
{
	if (chromeDarkmode)
	{
		arg1 = LCPParseColorString(bgColorHex, @"");
	}
	%orig;
}
%end

%hook UIButton
-(void)didMoveToWindow
{
	%orig;
	if (inChrome && chromeDarkmode)
	{
		self.backgroundColor = [UIColor clearColor];
	}
}
%end

%hook MDCInkView
-(void)setBackgroundColor:(id)arg1
{
	if (chromeDarkmode)
	{
		arg1 = [UIColor clearColor];
	}
	%orig;
}
%end

%hook GridCell
-(void)didMoveToWindow
{
	%orig;
	if (chromeDarkmode)
	{
		[self topBar].backgroundColor = LCPParseColorString(bgColorHex, @"");
	}
}
%end

%hook _UIVisualEffectSubview
-(void)layoutSubviews
{
	%orig;
	if (chromeDarkmode && [[[((UIView*)self) superview] superview] isKindOfClass:[UITableViewHeaderFooterView class]])
	{
		((UIView*)self).backgroundColor = LCPParseColorString(darkerColorHex, @"");
	}
}
%end

%hook _UITableViewHeaderFooterContentView
-(void)setBackgroundColor:(id)arg1
{
	if (chromeDarkmode)
	{
		arg1 = LCPParseColorString(bgColorHex, @"");
	}
	%orig;
}
%end
/* End chrome darkmode */

#pragma mark Chrome Menu Toggle

@class ToolsMenuViewCell;
@interface ToolsMenuViewItem : NSObject
@property (nonatomic, copy, readwrite) NSString *accessibilityIdentifier;
@property (nonatomic, assign, readwrite) BOOL active;
@property (nonatomic, assign) SEL selector;
@property (nonatomic, readwrite) ToolsMenuViewCell *tableViewCell;
@property (nonatomic, assign, readwrite) NSInteger tag;
@property (nonatomic, copy, readwrite) NSString *title;
@end

@interface ToolsMenuViewCell
-(void)configureForMenuItem:(ToolsMenuViewItem *)item;
@end

%hook ToolsMenuViewController

-(void)setMenuItems:(NSArray *)items {
	//bloody hell it compiled first time
	//worked first time, too
	NSMutableArray *mutItems = [items mutableCopy];

	ToolsMenuViewItem *item = [%c(ToolsMenuViewItem) new];
	item.accessibilityIdentifier = @"kNebulaDarkModeId"; //pretty sure this doesn't matter, but it must have a use
	item.active = YES;
	item.selector = nil;
	item.tag = -69; //what's this for? lmao
	item.title = @"Toggle Dark Mode";

	ToolsMenuViewCell *cell = [%c(ToolsMenuViewCell) new];
	item.tableViewCell = cell;

	[cell configureForMenuItem:item];

	[mutItems insertObject:item atIndex:0];
	%orig([mutItems copy]);
}

-(void)collectionView:(id)arg1 didSelectItemAtIndexPath:(NSIndexPath *)arg2 {
	if(arg2.row == 1) {
		//dark mode was pressed
		[[NSNotificationCenter defaultCenter] postNotificationName:@"NebulaToggle" object:@(!darkMode) userInfo:nil];
	}
	%orig;
}

%end
#pragma mark End Chrome Menu Toggle
%end

%ctor {
	if (!enabled) { return; }
	//Load the stylesheets from files as soon as the tweak is injected and store them in static variables.
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)ColorChangedCallback, CFSTR("com.octodev.nebula-colorchanged"), NULL, CFNotificationSuspensionBehaviorCoalesce);
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)PreferencesChangedCallback, CFSTR("com.octodev.nebula-prefschanged"), NULL, CFNotificationSuspensionBehaviorCoalesce);

	NSDictionary* colors = [[NSDictionary alloc] initWithContentsOfFile:COLORS_PLIST_PATH];
	preferences = [[NSDictionary alloc] initWithContentsOfFile:SETTINGS_PLIST_PATH];

	//app darkmodes
	if ([[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.google.chrome.ios"])
	{
		%init(ChromeOnly);
	}
	else if ([[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.mobilesafari"])
	{
		%init(SafariOnly);
	}

	//blacklisted apps
	NSMutableDictionary *apps = [[NSMutableDictionary alloc] initWithContentsOfFile:APPS_PLIST_PATH];
	if (disableInSpringboard)
	{
		if (apps)
		{
			[apps setObject:@YES forKey:@"com.apple.springboard"];
		}
		else
		{
			apps = [@{@"com.apple.springboard":@YES} mutableCopy];
		}
	}
	if([[apps allKeys] containsObject:[[NSBundle mainBundle] bundleIdentifier]]) {
		//the app has at some point been disabled, and we need to check if it currently is
		if([[apps valueForKey:[[NSBundle mainBundle] bundleIdentifier]] boolValue]) {
			//app disabled, we will never init the hook group
			return;
		}
	}

	bgColorHex = colors[@"backgroundColor"] ? [colors[@"backgroundColor"] substringWithRange:NSMakeRange(0, 7)] : @"#262626";
	textColorHex = colors[@"textColor"] ? [colors[@"textColor"] substringWithRange:NSMakeRange(0, 7)] : @"#ededed";
	darkerColorHex = makeHexColorDarker(bgColorHex, 20);
	loadStylesheetsFromFiles();
	loadBlacklist();
	changeColorsInStylesheets();

	%init(Nebula);
}
