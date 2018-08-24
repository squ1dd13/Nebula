#define COLORS_PLIST_PATH @"/var/mobile/Library/Preferences/com.octodev.nebulacolors.plist"
#define SETTINGS_PLIST_PATH @"/var/mobile/Library/Preferences/com.octodev.nebula.plist"
#define STYLESHEET_PATH @"/Library/Application Support/7361666172696461726b/7374796c65.st"
#define BACKUP_STYLESHEET_PATH @"/Library/Application Support/7361666172696461726b/7374796c66.st"
#define stylesPath @"/Library/Application Support/7361666172696461726b/Themes"
#define safariDarkmode PreferencesBool(@"safariDarkmode", YES)

#include "libcolorpicker.h"
#include "nebula.h"

@import WebKit;
@import AudioToolbox;
@import UIKit;

static UIBarButtonItem *nightModeButton = nil;
static NSString *stylesheetFromHex;
static NSString *backupStylesheet;
static BOOL darkMode = NO;
static NSMutableDictionary *customStyles;
static NSArray *backupStylesheetSites = @[];
static NSArray *whitelist;
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

	backupStylesheet = [NSString stringWithContentsOfFile:BACKUP_STYLESHEET_PATH encoding:NSUTF8StringEncoding error:&err];
	backupStylesheet = fromDoubleHex(backupStylesheet, @"You can go away now.\n");

	if(err) NSLog(@"ERROR: %@", err.localizedFailureReason);

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

void loadWhitelist()
{
	whitelist = preferences[@"whitelistArray"] ? preferences[@"whitelistArray"] : [NSArray new];
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
	bgColorHex = colors[@"backgroundColor"] ? [colors[@"backgroundColor"] substringWithRange:NSMakeRange(0, 7)] : @"#1D1D1D";
	textColorHex = colors[@"textColor"] ? [colors[@"textColor"] substringWithRange:NSMakeRange(0, 7)] : @"#ededed";
	darkerColorHex = makeHexColorDarker(bgColorHex, 20);
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

%ctor {
	//Load the stylesheets from files as soon as the tweak is injected and store them in static variables.
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)ColorChangedCallback, CFSTR("com.octodev.nebula-colorchanged"), NULL, CFNotificationSuspensionBehaviorCoalesce);
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)PreferencesChangedCallback, CFSTR("com.octodev.nebula-prefschanged"), NULL, CFNotificationSuspensionBehaviorCoalesce);

	NSDictionary* colors = [[NSDictionary alloc] initWithContentsOfFile:COLORS_PLIST_PATH];
	preferences = [[NSDictionary alloc] initWithContentsOfFile:SETTINGS_PLIST_PATH];
	bgColorHex = colors[@"backgroundColor"] ? [colors[@"backgroundColor"] substringWithRange:NSMakeRange(0, 7)] : @"#1D1D1D";
	textColorHex = colors[@"textColor"] ? [colors[@"textColor"] substringWithRange:NSMakeRange(0, 7)] : @"#ededed";
	darkerColorHex = makeHexColorDarker(bgColorHex, 20);
	loadStylesheetsFromFiles();
	loadWhitelist();
	changeColorsInStylesheets();
}

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
		[self setInteractionTintColor:[UIColor whiteColor]];
	}
}

-(void)setItems:(NSArray *)items animated:(BOOL)anim {
	NSLog(@"Setting toolbar items.");
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
	%orig([buttons copy], anim);
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
	[[NSNotificationCenter defaultCenter] postNotificationName:@"DarkWebToggle" object:@(button.selected) userInfo:nil];
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
	if (darkMode || (whitelist && [whitelist containsObject:[[self URL] host]] && !darkMode))
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

	BOOL whitelisted = NO;
	if(whitelist && [whitelist containsObject:[[self URL] host]] && !darkMode) {
		NSLog(@"Site is whitelisted.");
		[self goDark];
		whitelisted = YES;
	}

	if (!whitelisted)
	{
		if(darkMode) {
			[self goDark];
		} else {
			[self revertInjection];
			[[NSNotificationCenter defaultCenter] postNotificationName:@"Reset" object:nil userInfo:nil];
		}
	}

	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"DarkWebToggle" object:nil]; //clear up before we add it again
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(toggleInjection:) name:@"DarkWebToggle" object:nil];
}

%new
-(void)toggleInjection:(NSNotification *)notification {
	[[NSNotificationCenter defaultCenter] postNotificationName:(darkMode) ? @"DarkWebDark" : @"DarkWebLight" object:nil userInfo:nil];

	darkMode = [[notification object] boolValue];

	[[notification object] boolValue] ? [self goDark] : [self revertInjection];
	[%c(UIKBRenderConfig) updateAllConfigs];
}

%new
-(void)goDark {
	if(!self.hasInjected) {
		NSString *stylesheet = [NSString stringWithFormat:@"%@", stylesheetFromHex];

		NSString *host = [[self URL] host];
		if(![host containsString:@"www."]) {
			host = [@"www." stringByAppendingString:host];
		}
		NSLog(@"%@ css: %@", host, [customStyles valueForKey:host]);
		if([customStyles valueForKey:host]) {
			NSString *custom = [NSString stringWithContentsOfFile:[[stylesPath stringByAppendingString:@"/"] stringByAppendingString:[customStyles valueForKey:host]] encoding:NSUTF8StringEncoding error:nil];
			custom = [custom stringByReplacingOccurrencesOfString:@"NEBULA_DARKER" withString:darkerColorHex];
			custom = [custom stringByReplacingOccurrencesOfString:@"NEBULA_DARK" withString:bgColorHex];
			custom = [custom stringByReplacingOccurrencesOfString:@"NEBULA_TEXT" withString:textColorHex];
			stylesheet = custom;
		}
		else if ([backupStylesheetSites containsObject:host]) //see if host should use backup stylesheet
		{
			stylesheet = backupStylesheet;
		}

		NSString *head = [self getJavaScriptOutput:@"document.getElementsByTagName(\"head\")[0].innerHTML"];
		NSString *modifiedHead = [head stringByAppendingString:[NSString stringWithFormat:@"\n<style>%@</style>", stylesheet]];
		[self runJavaScript:[NSString stringWithFormat:@"document.getElementsByTagName(\"head\")[0].innerHTML = `%@`;", modifiedHead] completion:^{
			self.alpha = 1;
		}];
		self.hasInjected = YES;
	}
}

%new
-(void)revertInjection {
	self.hasInjected = NO;
	NSLog(@"Reverting changes");
	[self runJavaScript:[NSString stringWithFormat:@"document.getElementsByTagName(\"head\")[0].innerHTML = `%@`;", self.originalHead] completion:nil];
}

%new
-(void)runJavaScript:(NSString *)js completion:(void (^)())comp {
	__block BOOL finished = NO;

	[self evaluateJavaScript:js completionHandler:^(id result, NSError *error) {
		if(error) NSLog(@"JSErr: %@", error.localizedDescription);
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
		} else {
			NSLog(@"JSErr: %@", error.localizedDescription);
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
%property (nonatomic, assign) BOOL hasInjected;

-(void)webView:(id)arg1 didCommitLoadForFrame:(id)arg2
{
	%orig;
	if(whitelist && [whitelist containsObject:[[(WebFrame*)arg2 webui_URL] host]]) {
		[(WebFrame*)arg2 frameView].hidden = YES;
	}
}

-(void)webView:(id)arg1 didFinishLoadForFrame:(id)arg2
{
	%orig;
	self.hasInjected = NO;
	NSLog(@"Navigation ended.");

	if(whitelist && [whitelist containsObject:[[(WebFrame*)arg2 webui_URL] host]]) {
		NSLog(@"Site is whitelisted.");
		[self goDarkForFrame:arg2];
		[(WebFrame*)arg2 frameView].hidden = NO;
	}
}

%new
-(void)goDarkForFrame:(id)arg1 {
	if(!self.hasInjected) {
		WebFrame* webFrame = (WebFrame*)arg1;
		NSString *stylesheet = [NSString stringWithFormat:@"%@", stylesheetFromHex];

		NSString *host = [[webFrame webui_URL] host];
		if(![host containsString:@"www."]) {
			host = [@"www." stringByAppendingString:host];
		}
		NSLog(@"%@ css: %@", host, [customStyles valueForKey:host]);
		if([customStyles valueForKey:host]) {
			NSString *custom = [NSString stringWithContentsOfFile:[[stylesPath stringByAppendingString:@"/"] stringByAppendingString:[customStyles valueForKey:host]] encoding:NSUTF8StringEncoding error:nil];
			custom = [custom stringByReplacingOccurrencesOfString:@"NEBULA_DARKER" withString:darkerColorHex];
			custom = [custom stringByReplacingOccurrencesOfString:@"NEBULA_DARK" withString:bgColorHex];
			custom = [custom stringByReplacingOccurrencesOfString:@"NEBULA_TEXT" withString:textColorHex];
			stylesheet = custom;
		}
		else if ([backupStylesheetSites containsObject:host]) //see if host should use backup stylesheet
		{
			stylesheet = backupStylesheet;
		}

		NSString *head = [webFrame _stringByEvaluatingJavaScriptFromString:@"document.getElementsByTagName(\"head\")[0].innerHTML"];
		NSString *modifiedHead = [head stringByAppendingString:[NSString stringWithFormat:@"\n<style>%@</style>", stylesheet]];
		[webFrame _stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"document.getElementsByTagName(\"head\")[0].innerHTML = `%@`;", modifiedHead]];
		self.hasInjected = YES;
	}
}
%end

%hook UIDevice

-(long long)_keyboardGraphicsQuality {
	return 10;
}
%end

/* Safari darkmode */
%hook _UIBackdropView
-(void)didMoveToWindow
{
	%orig;
	if ([[self window] isMemberOfClass:%c(MobileSafariWindow)] && [self style] != 2030 && safariDarkmode)
	{
		[self transitionToPrivateStyle:1];
	}
}

-(void)setStyle:(NSInteger)arg1
{
	%orig;
	if ([[self window] isMemberOfClass:%c(MobileSafariWindow)] && [self style] != 2030 && safariDarkmode)
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
-(void)layoutSubviews
{
	%orig;
	if (safariDarkmode)
	{
		((UIView *)self).backgroundColor = LCPParseColorString(bgColorHex, @"");
	}
}
%end

%hook CompletionListTableViewController
-(void)viewDidLayoutSubviews
{
	%orig;
	if (safariDarkmode)
	{
		((UIViewController *)self).view.backgroundColor = LCPParseColorString(bgColorHex, @"");
	}
}
%end

%hook UITableViewCell
-(void)layoutSubviews
{
	%orig;
	if (safariDarkmode && [[self window] isMemberOfClass:%c(MobileSafariWindow)])
	{
		self.backgroundColor = LCPParseColorString(bgColorHex, @"");
	}
}
%end

%hook UITableViewLabel
-(void)layoutSubviews
{
	%orig;
	if (safariDarkmode && [[((UILabel *)self) window] isMemberOfClass:%c(MobileSafariWindow)])
	{
		((UILabel *)self).textColor = LCPParseColorString(textColorHex, @"");
	}
}
%end

%hook _UITableViewHeaderFooterViewLabel
-(void)layoutSubviews
{
	%orig;
	if (safariDarkmode && [[((UILabel *)self) window] isMemberOfClass:%c(MobileSafariWindow)])
	{
		((UILabel *)self).textColor = LCPParseColorString(textColorHex, @"");
	}
}
%end

//TODO: currently not working

%hook TLKVibrantLabel
-(void)layoutSubviews
{
	%orig;
	if (safariDarkmode && [[self window] isMemberOfClass:%c(MobileSafariWindow)])
	{
		self.textColor = LCPParseColorString(textColorHex, @"");
	}
}
%end
/* End safari darkmode */
