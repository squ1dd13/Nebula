#include "NBLRootListController.h"
#include "NBLWhitelistController.h"
#import <objc/runtime.h>

#define kWidth [[UIApplication sharedApplication] keyWindow].frame.size.width

@protocol PreferencesTableCustomView
- (id)initWithSpecifier:(id)arg1;

@optional
- (CGFloat)preferredHeightForWidth:(CGFloat)arg1;
- (CGFloat)preferredHeightForWidth:(CGFloat)arg1 inTableView:(id)arg2;
@end

@interface SQDPrefBannerView : UITableViewCell <PreferencesTableCustomView> {
    UILabel *label;
}

@end
//banner
@implementation SQDPrefBannerView

- (id)initWithSpecifier:(PSSpecifier *)specifier {
    self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Cell"];
    if (self) {

        CGRect labelFrame = CGRectMake(0, -15, kWidth, 70);

        label = [[UILabel alloc] initWithFrame:labelFrame];

        [label.layer setMasksToBounds:YES];
        [label setNumberOfLines:1];
        label.font = [UIFont fontWithName:@"HelveticaNeue-Bold" size:40];

        label.textColor = [UIColor whiteColor];
        label.textAlignment = NSTextAlignmentCenter;
        label.text = @"Nebula";
        //label.alpha = 0.0;
        [self addSubview:label];

        //fade in
        //[UIView animateWithDuration:1.3 animations:^() {
          //  label.alpha = 1.0;
        //}];

    }
    return self;
}
- (CGFloat)preferredHeightForWidth:(CGFloat)arg1 {
    return 70.0f;
}
@end

@interface PSTableCell : UITableViewCell
@end

@implementation PSTableCell (Nebula)

+ (void)load {
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		Class class = [self class];

		SEL originalSelector = @selector(layoutSubviews);
		SEL swizzledSelector = @selector(nebulaLayoutSubviews);

		Method originalMethod = class_getInstanceMethod(class, originalSelector);
		Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);

		BOOL didAddMethod =
		class_addMethod(class, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod));
		if (didAddMethod) {
			class_replaceMethod(class, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
		} else {
			method_exchangeImplementations(originalMethod, swizzledMethod);
		}
	});
}

- (void)nebulaLayoutSubviews {
	[self nebulaLayoutSubviews];
	@try {
	if([NSStringFromClass((Class)[self valueForKeyPath:@"superview.delegate.delegate.class"]) isEqualToString:@"NBLRootListController"]) {
		self.textLabel.textColor = [UIColor whiteColor];
		if(self.accessoryView) {
			self.accessoryView.layer.borderWidth = 0;
		}
		if(self.detailTextLabel && self.accessoryView) {
			self.detailTextLabel.textColor = self.accessoryView.backgroundColor;
		}
	}
} @catch(NSException *e) {
	if([NSStringFromClass((Class)[self valueForKeyPath:@"superview.delegate.class"]) isEqualToString:@"NBLRootListController"]) {
		self.textLabel.textColor = [UIColor whiteColor];
	}
	if(self.accessoryView) {
		self.accessoryView.layer.borderWidth = 0;
	}
	if(self.detailTextLabel && self.accessoryView) {
		self.detailTextLabel.textColor = self.accessoryView.backgroundColor;
	}
}

}

@end


@implementation NBLRootListController

- (NSArray *)specifiers {
	if (!_specifiers) {
		_specifiers = [[self loadSpecifiersFromPlistName:@"Root" target:self] retain];
	}

	return _specifiers;
}

-(void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	self.navigationController.navigationController.navigationBar.tintColor = [UIColor whiteColor];
	[self.navigationController.navigationController.navigationBar setValue:@YES forKeyPath:@"_barBackgroundView.hidden"];
	[[[self.navigationController.navigationController.navigationBar valueForKey:@"_titleView"] valueForKey:@"_label"] setValue:@YES forKey:@"_textColorFollowsTintColor"];

	self.navigationController.navigationController.navigationBar.barTintColor = [UIColor blackColor];
	[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent];

	[[UITableView appearanceWhenContainedInInstancesOfClasses:@[self.class]] setBackgroundColor:[UIColor colorWithRed:(35/255.0) green:(35/255.0) blue:(35/255.0) alpha:1.0]];
	[[UITableView appearanceWhenContainedInInstancesOfClasses:@[self.class]] setSeparatorColor:[UIColor clearColor]];

	[UISwitch appearanceWhenContainedIn:self.class, nil].onTintColor = [UIColor blackColor];
	[[NSClassFromString(@"PSTableCell") appearanceWhenContainedInInstancesOfClasses:@[self.class]] setBackgroundColor:[UIColor colorWithRed:(35/255.0) green:(35/255.0) blue:(35/255.0) alpha:1.0]];
}

- (void)viewWillDisappear:(BOOL)animated {
	self.navigationController.navigationController.navigationBar.tintColor = nil;
	self.navigationController.navigationController.navigationBar.barTintColor = nil;
	[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault];

	[super viewWillDisappear:animated];
}

@end
