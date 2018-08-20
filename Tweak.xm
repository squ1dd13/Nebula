@import WebKit;
@import AudioToolbox;
@import UIKit;

@interface UIImage (Change)
+ (UIImage*)changeImage:(UIImage *)image toColor:(UIColor *)color;
@end

%hook UIImage

%new
+ (UIImage*)changeImage:(UIImage *)image toColor:(UIColor *)color {
	UIGraphicsBeginImageContextWithOptions(image.size, NO, image.scale);
	CGRect imageRect = CGRectMake(0.0f, 0.0f, image.size.width, image.size.height);

	CGContextRef ctx = UIGraphicsGetCurrentContext();

	// Draw a white background (for white mask)
	CGFloat r, g, b, a;
	[color getRed:&r green:&g blue:&b alpha:&a];
	CGContextSetRGBFillColor(ctx, r, g, b, a);
	CGContextFillRect(ctx, imageRect);

	// Apply the source image's alpha
	[image drawInRect:imageRect blendMode:kCGBlendModeDestinationIn alpha:1.0f];

	UIImage* outImage = UIGraphicsGetImageFromCurrentImageContext();

	UIGraphicsEndImageContext();

	return outImage;
}
%end

NSInteger colorProfile;

struct pixel {
	unsigned char r, g, b, a;
};

CGFloat alpha = 1.0;
static UIColor *dominantColorFromImage(UIImage *image) {
    CGImageRef iconCGImage = image.CGImage;
    NSUInteger red = 0, green = 0, blue = 0;
    size_t width = CGImageGetWidth(iconCGImage);
    size_t height = CGImageGetHeight(iconCGImage);
    size_t bitmapBytesPerRow = width * 4;
    size_t bitmapByteCount = bitmapBytesPerRow * height;
    struct pixel *pixels = (struct pixel *)malloc(bitmapByteCount);
    if (pixels) {
        CGContextRef context = CGBitmapContextCreate((void *)pixels, width, height, 8, bitmapBytesPerRow, CGImageGetColorSpace(iconCGImage), kCGImageAlphaPremultipliedLast);
        if (context) {
            CGContextDrawImage(context, CGRectMake(0.0, 0.0, width, height), iconCGImage);
            NSUInteger numberOfPixels = width * height;
            for (size_t i = 0; i < numberOfPixels; i++) {
                red += pixels[i].r;
                green += pixels[i].g;
                blue += pixels[i].b;
            }
            red /= numberOfPixels;
            green /= numberOfPixels;
            blue /= numberOfPixels;
            CGContextRelease(context);
        }
        free(pixels);
    }
    return [UIColor colorWithRed:red/255.0 green:green/255.0 blue:blue/255.0 alpha:alpha];
}

UIColor *avgColor(UIImage *image) {
    UIColor *color = dominantColorFromImage(image);
    return color;
}

NSString *replaceStr(NSString *mainString, NSString *toReplace, NSString *with) {
    return [mainString stringByReplacingOccurrencesOfString:toReplace withString:with];
}

NSString *stringBetween(NSString *main, NSString *first, NSString *last) {
	NSString *string = main;
	NSString *result = nil;

	// Determine "<div>" location
	NSRange divRange = [string rangeOfString:first options:NSCaseInsensitiveSearch];
	if (divRange.location != NSNotFound)
	{
		// Determine "</div>" location according to "<div>" location
		NSRange endDivRange;

		endDivRange.location = divRange.length + divRange.location;
		endDivRange.length   = [string length] - endDivRange.location;
		endDivRange = [string rangeOfString:last options:NSCaseInsensitiveSearch range:endDivRange];

		if (endDivRange.location != NSNotFound)
		{
			// Tags found: retrieve string between them
			divRange.location += divRange.length;
			divRange.length = endDivRange.location - divRange.location;

			result = [string substringWithRange:divRange];
			return result;
		}
	}
	return @"";
}

UIImage *resizeImage(UIImage *image, CGSize size) {
	CGFloat scale = MAX(size.width/image.size.width, size.height/image.size.height);
	CGFloat width = image.size.width * scale;
	CGFloat height = image.size.height * scale;
	CGRect imageRect = CGRectMake((size.width - width)/2.0f,
	(size.height - height)/2.0f, width, height);

	UIGraphicsBeginImageContextWithOptions(size, NO, 0);
	[image drawInRect:imageRect];
	UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return newImage;
}

@interface BrowserToolbar : UIToolbar
@property (nonatomic, assign) UIButton *darkButton;
@property (nonatomic, assign) BOOL darkMode;
@end

static UIBarButtonItem *nightModeButton = nil;
static NSString *stylesheetFromHex;
static NSString *backupStylesheet;

void loadStylesheetsFromFiles() {
	#pragma mark Blocks
	//changes a hex string to a plain string
	NSString* (^fromHex)(NSString *) = ^(NSString *str){
		NSMutableString *newString = [[NSMutableString alloc] init];
		int i = 0;
		while (i < [str length]) {
			NSString *hexChar = [str substringWithRange: NSMakeRange(i, 2)];
			int value = 0;
			sscanf([hexChar cStringUsingEncoding:NSASCIIStringEncoding], "%x", &value);
			[newString appendFormat:@"%c", (char)value];
			i+=2;
		}
		return ((NSString *)[newString copy]);
	};

	//changes a double hex string to a plain string
	NSString* (^fromDoubleHex)(NSString *, NSString *) = ^(NSString *str, NSString *message) {
		NSString *string = str;
		string = fromHex(string);
		NSString *removedMessage = [string stringByReplacingOccurrencesOfString:message withString:@""];
		removedMessage = fromHex(removedMessage);
		return ((NSString *)removedMessage);
	};
	#pragma mark End blocks

	//loading in the stylesheet and decoding it
	//also TODO: use newer, non-deprecated methods
	NSError *err;
	stylesheetFromHex = [NSString stringWithContentsOfFile:@"/var/mobile/Library/Safari/7374796c65.st" encoding:NSUTF8StringEncoding error:&err];
	stylesheetFromHex = fromDoubleHex(stylesheetFromHex, @"You can go away now.\n");

	if(err) NSLog(@"ERROR: %@", err.localizedFailureReason);

	backupStylesheet = [NSString stringWithContentsOfFile:@"/var/mobile/Library/Safari/7374796c66.st" encoding:NSUTF8StringEncoding error:&err];
	backupStylesheet = fromDoubleHex(backupStylesheet, @"You can go away now.\n");

	if(err) NSLog(@"ERROR: %@", err.localizedFailureReason);
}

%ctor {
	//load the stylesheets from files as soon as the tweak is loaded and store them in static variables. This way, we aren't loading them from the files every time and we don't need to worry about sandboxing as this is called from %ctor which is unsandboxed.
	loadStylesheetsFromFiles();
}

//add button to toolbar
%hook BrowserToolbar
%property (nonatomic, assign) UIButton *darkButton;
%property (nonatomic, assign) BOOL darkMode;

-(void)setItems:(NSArray *)items animated:(BOOL)anim {
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"Reset" object:nil]; //clear up before we add it again
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resetButton) name:@"Reset" object:nil];
	//cheers pinpal

	self.darkButton = [UIButton buttonWithType:UIButtonTypeCustom];
	[self.darkButton setFrame:CGRectMake(0, 0, 20, 20)];
	[self.darkButton addTarget:self action:@selector(nightMode:) forControlEvents:UIControlEventTouchUpInside];

	[self.darkButton setImage:[UIImage changeImage:resizeImage([UIImage imageWithContentsOfFile:@"/Applications/MobileSafari.app/Dark.png"], CGSizeMake(20, 20)) toColor:self.tintColor] forState:UIControlStateNormal];
	[self.darkButton setImage:[UIImage changeImage:resizeImage([UIImage imageWithContentsOfFile:@"/Applications/MobileSafari.app/Light.png"], CGSizeMake(20, 20)) toColor:self.tintColor] forState:UIControlStateSelected];

	nightModeButton = [[UIBarButtonItem alloc] initWithCustomView:self.darkButton];
	self.darkMode = NO;

	NSMutableArray *buttons = [items mutableCopy];
	UIBarButtonItem *space = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
	space.width = 30;
	[buttons addObject:space];
	[buttons addObject:nightModeButton];
	%orig([buttons copy], anim);
}

//called when the button is pressed
%new
-(void)nightMode:(UIButton *)button {
	AudioServicesPlaySystemSound(1519);
	button.selected = !button.selected;
	[[NSNotificationCenter defaultCenter] postNotificationName:@"DarkWebToggle" object:@(button.selected) userInfo:nil];
}

//resets the button to its defaulkt value
%new
-(void)resetButton {
	self.darkButton.selected = NO;
}

%end

//TODO: change the colours in the CSS to darker or lighter by converting to rgb, making lighter/darker, then converting back to hex.

static BOOL darkMode = NO;
static NSCache *pageCache = [NSCache new];

@interface TabDocument : NSObject
@property (nonatomic, assign) BOOL hasInjected;
@property (nonatomic, assign) BOOL shouldInject;
@property (nonatomic, assign) BOOL injectedForThisPage;
@property (nonatomic, copy) NSString *originalHead;
@property (nonatomic, copy) NSString *originalBody;
@property (nonatomic, copy) NSString *lastHost;
@property (nonatomic, copy) NSString *lastFullURL;
-(void)inject;
-(void)injectIntoURL:(NSURL *)URL;
-(void)reload;
-(void)runJavaScript:(NSString *)js;
-(NSString *)getJavaScriptOutput:(NSString *)js;
-(void)revertInjection;
@end



%hook TabDocument
%property (nonatomic, assign) BOOL hasInjected;
%property (nonatomic, assign) BOOL shouldInject;
%property (nonatomic, assign) BOOL injectedForThisPage;
%property (nonatomic, copy) NSString *originalHead;
%property (nonatomic, copy) NSString *originalBody;
%property (nonatomic, copy) NSString *lastHost;
%property (nonatomic, copy) NSString *lastFullURL;

-(void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
	%orig;
	NSLog(@"Navigation ended.");

	self.originalHead = [self getJavaScriptOutput:@"document.getElementsByTagName(\"head\")[0].innerHTML"];
	self.originalBody = [self getJavaScriptOutput:@"document.getElementsByTagName(\"body\")[0].innerHTML"];

	if([pageCache objectForKey:webView.URL.absoluteString] && !darkMode) {
		NSLog(@"Reverting from cache");
		[self runJavaScript:[NSString stringWithFormat:@"document.getElementsByTagName(\"head\")[0].innerHTML = `%@`;", [pageCache objectForKey:webView.URL.absoluteString]]];
		[pageCache removeObjectForKey:webView.URL.absoluteString];
	} else {
		[pageCache setObject:self.originalHead forKey:webView.URL.absoluteString];
	}


	if(darkMode) {
		[self injectIntoURL:[webView URL]];
	} else {
		self.shouldInject = NO;
		[self revertInjection];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"Reset" object:nil userInfo:nil];
	}


	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"DarkWebToggle" object:nil]; //clear up before we add it again
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(toggleInjection:) name:@"DarkWebToggle" object:nil];

	[self inject]; //this doesn't necessarily mean we will inject, because that is decided later
}

%new
-(void)toggleInjection:(NSNotification *)notification {
	[[NSNotificationCenter defaultCenter] postNotificationName:(self.shouldInject) ? @"DarkWebDark" : @"DarkWebLight" object:nil userInfo:nil];
	self.shouldInject = !self.shouldInject; //invert it, because we have now switched

	if([[notification object] boolValue]) {
		self.hasInjected = NO;
		[self inject];
		darkMode = YES;
	} else {
		[self revertInjection];
		darkMode = NO;
	}
}

-(void)reload {
	%orig;
	self.hasInjected = NO;
	[self inject];
}

%new
-(void)inject {
	if(!self.hasInjected) {
		[self injectIntoURL:[((WKWebView *)[self valueForKey:@"webView"]) URL]];
	}
}

%new
-(void)injectIntoURL:(NSURL *)URL {
	if(URL && self.shouldInject) {
		//take the first image so we can compare later
		UIView *viewForDrawing = ((WKWebView *)[self valueForKey:@"webView"]);
		CGSize viewSize = viewForDrawing.bounds.size;
		UIGraphicsBeginImageContextWithOptions(viewSize, NO, 0.0);
		[viewForDrawing drawViewHierarchyInRect:CGRectMake(0, 0, viewSize.width, viewSize.height) afterScreenUpdates:YES];
		UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
		UIGraphicsEndImageContext();

		//calculate the average colour of that image to see if the injection worked
		CGFloat white, alpha;
		UIColor *averageColor = avgColor(image);
		[averageColor getWhite:&white alpha:&alpha];


		NSString *HTML = [self getJavaScriptOutput:@"document.documentElement.outerHTML"];

		NSString *head = stringBetween(HTML, @"<head>", @"</head>");

		NSString *modifiedHead = @"";

		modifiedHead = [head copy];
		modifiedHead = [modifiedHead stringByAppendingString:[NSString stringWithFormat:@"\n<style>%@</style>", stylesheetFromHex]];
		modifiedHead = ([[URL absoluteString] containsString:@"github.com"]) ? [modifiedHead stringByAppendingString:@"\n<link rel=\"stylesheet\" href=\"http://squ1dd13.tk/gh.css\" type=\"text/css\">"] : modifiedHead;

		[self runJavaScript:[NSString stringWithFormat:@"document.getElementsByTagName(\"head\")[0].innerHTML = `%@`;", modifiedHead]];

		//now we get our second image to compare to the first
		UIView *viewInjected = ((WKWebView *)[self valueForKey:@"webView"]);
		CGSize newViewSize = viewInjected.bounds.size;
		UIGraphicsBeginImageContextWithOptions(newViewSize, NO, 0.0);
		[viewInjected drawViewHierarchyInRect:CGRectMake(0, 0, newViewSize.width, newViewSize.height) afterScreenUpdates:YES];
		UIImage *injectedImage = UIGraphicsGetImageFromCurrentImageContext();
		UIGraphicsEndImageContext();

		//calculate the average colour of that image to see if the injection worked
		CGFloat newWhite, newAlpha;
		UIColor *newAverageColor = avgColor(injectedImage);
		[newAverageColor getWhite:&newWhite alpha:&newAlpha];


		CGFloat nWhite, nAlpha;
		if(newWhite > white) {
			NSLog(@"Page is darker.");
		} else {

			//this time we directly inject the CSS in a <style> tag
			NSString *newStyleTag = [NSString stringWithFormat:@"\n<style>%@</style>", backupStylesheet];
			NSString *reInjectHead = stringBetween(HTML, @"<head>", @"</head>");
			modifiedHead = [reInjectHead copy];
			modifiedHead = [modifiedHead stringByAppendingString:newStyleTag];
			HTML = replaceStr(HTML, reInjectHead, modifiedHead);

			//i'm high on js
			[self runJavaScript:[NSString stringWithFormat:@"document.getElementsByTagName(\"head\")[0].innerHTML = `%@`;", modifiedHead]];

			//take another image so we can see if it worked this time
			UIGraphicsBeginImageContextWithOptions(newViewSize, NO, 0.0);
			[viewInjected drawViewHierarchyInRect:CGRectMake(0, 0, newViewSize.width, newViewSize.height) afterScreenUpdates:YES];
			injectedImage = UIGraphicsGetImageFromCurrentImageContext();
			UIGraphicsEndImageContext();

			newAverageColor = avgColor(injectedImage);
			[newAverageColor getWhite:&nWhite alpha:&nAlpha];
		}

		if(!(nWhite > newWhite) && (nWhite != newWhite)) { //i cba to put it in one so i'll just do two conditions
			//there needs to be more than this
			[self runJavaScript:@"document.getElementsByTagName(\"body\")[0].style.backgroundColor = \"#000\";"];
		}

		self.hasInjected = YES;

	}
}

%new
-(void)revertInjection {
	NSLog(@"Reverting changes");
	[self runJavaScript:[NSString stringWithFormat:@"document.getElementsByTagName(\"head\")[0].innerHTML = `%@`;", self.originalHead]];
	[self runJavaScript:[NSString stringWithFormat:@"document.getElementsByTagName(\"body\")[0].innerHTML = `%@`;", self.originalBody]];
}

%new
-(void)runJavaScript:(NSString *)js {
	__block BOOL finished = NO;

	[((WKWebView *)[self valueForKey:@"webView"]) evaluateJavaScript:js completionHandler:^(id result, NSError *error) {
		if(error) NSLog(@"JSErr: %@", error.localizedDescription);
		finished = YES;
	}];
	while (!finished) {
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
	}
}

%new
-(NSString *)getJavaScriptOutput:(NSString *)js {
	__block NSString *resultString = nil;
	__block BOOL finished = NO;

	[((WKWebView *)[self valueForKey:@"webView"]) evaluateJavaScript:js completionHandler:^(id result, NSError *error) {
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

@interface BrowserController : NSObject
@property (nonatomic, copy) NSArray *whitelist;
@end

%hook BrowserController
%property (nonatomic, copy) NSArray *whitelist;

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

//dark keyboard
%hook UIKBRenderConfig
- (void)setLightKeyboard:(BOOL)light {
	%orig(NO);
}
%end

%hook UIDevice
- (long long)_keyboardGraphicsQuality {
	return 10;
}
%end
