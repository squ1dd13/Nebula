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

NSString* makeHexColorDarker(NSString* hexColor, CGFloat percent)
{
	int red, green, blue;
    sscanf([hexColor UTF8String], "#%02X%02X%02X", &red, &green, &blue);
	red *= (1 - (percent / 100));
	green *= (1 - (percent / 100));
	blue *= (1 - (percent / 100));
	hexColor = [NSString stringWithFormat:@"#%02x%02x%02x", red, green, blue];
	return hexColor;
}

@interface BrowserToolbar : UIToolbar
@property (nonatomic, assign) UIButton *darkButton;
-(void)setInteractionTintColor:(id)arg1;
@end

//changes a double hex string to a plain string
NSString* fromDoubleHex(NSString* str, NSString* message)
{
	//changes a hex string to a plain string
	NSString *(^fromHex)(NSString *) = ^(NSString *str){
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

	NSString *string = str;
	string = fromHex(string);
	NSString *removedMessage = [string stringByReplacingOccurrencesOfString:message withString:@""];
	removedMessage = fromHex(removedMessage);
	return ((NSString *)removedMessage);
}

//dark keyboard
@interface UIKBRenderConfig : NSObject
-(void)setLightKeyboard:(BOOL)light;
+(void)updateAllConfigs;
+(id)darkConfig;
+(id)defaultConfig;
+(id)defaultEmojiConfig;
+(id)lowQualityDarkConfig;
@end

@interface BrowserController : NSObject
@end

@interface WebFrame : NSObject
-(NSURL*)webui_URL;
-(id)_stringByEvaluatingJavaScriptFromString:(id)arg1;
-(UIView*)frameView;
@end

@interface UIWebView (Nebula)
@property (nonatomic, assign) BOOL hasInjected;
-(void)goDarkForFrame:(id)arg1;
@end

@interface _UIBackdropView : UIView
-(void)transitionToPrivateStyle:(NSInteger)arg1;
-(NSInteger)style;
@end

@interface TLKVibrantLabel : UILabel
@end
