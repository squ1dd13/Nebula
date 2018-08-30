#include <notify.h>
#include "NBLBlacklistController.h"

#define kWidth [[UIApplication sharedApplication] keyWindow].frame.size.width
#define kHeight [[UIApplication sharedApplication] keyWindow].frame.size.height
#define iOS11 [[[[UIDevice currentDevice] systemVersion] componentsSeparatedByString:@"."][0] isEqualToString:@"11"]

@implementation NBLBlacklistController

- (NSArray *)specifiers {
	if (!_specifiers) {
		_specifiers = [self loadSpecifiersFromPlistName:@"Blacklist" target:self];
	}

	return _specifiers;
}

-(void)viewWillDisappear:(BOOL)a {
	[self.view endEditing:YES]; //this one actually works
	[super viewWillDisappear:a];
}

@end

@implementation BlacklistTableViewCell
- (id)initWithSpecifier:(PSSpecifier *)specifier
{
	self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Cell"];
	if (self)
	{
		//populate blacklist array
		[self getBlacklistArray];

		blacklistTable = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, kWidth, blacklistArray.count * 45) style:UITableViewStylePlain];
		blacklistTable.editing = YES;
		blacklistTable.scrollEnabled = NO;

		blacklistTable.delegate = self;
		blacklistTable.dataSource = self;

		[self addSubview:blacklistTable];
	}
	return self;
}

-(void)reloadTable
{
	NSString *keyPath = [[self valueForKey:@"superview"] respondsToSelector:@selector(reloadData)] ? @"superview" : @"superview.superview";
	[(UITableView*)[self valueForKeyPath:keyPath] reloadData];
	[blacklistTable reloadData];
	blacklistTable.frame = CGRectMake(0, 0, kWidth, blacklistArray.count * 45);
}

-(void)getBlacklistArray
{
	blacklistArray = [[[NSUserDefaults standardUserDefaults] objectForKey:@"blacklistArray" inDomain:@"com.octodev.nebula"] mutableCopy];
	if (!blacklistArray) { blacklistArray = [NSMutableArray new]; }
}

-(void)setBlacklistArray
{
	[[NSUserDefaults standardUserDefaults] setObject:[blacklistArray copy] forKey:@"blacklistArray" inDomain:@"com.octodev.nebula"];
	notify_post([@"com.octodev.nebula-prefschanged" UTF8String]);
}

-(void)didMoveToWindow
{
	[super didMoveToWindow];
	UIBarButtonItem *addButton = [[UIBarButtonItem alloc]  initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addButtonPressed)];
	NSString *keyPath = (iOS11) ? @"superview.superview" : @"superview.superview.superview";
	[((NBLBlacklistController *)[[self valueForKeyPath:keyPath] _viewControllerForAncestor]).navigationItem setRightBarButtonItem:addButton];
}

-(void)addButtonPressed
{
	[blacklistArray addObject:@""];
	[self setBlacklistArray];
	[self reloadTable];
}

-(CGFloat)preferredHeightForWidth:(CGFloat)arg1
{
	return blacklistArray.count * 45;
}

-(long long)numberOfSectionsInTableView:(id)arg1
{
	return 1;
}

-(long long)tableView:(id)arg1 numberOfRowsInSection:(long long)arg2
{
	return blacklistArray.count;
}

-(id)tableView:(id)arg1 cellForRowAtIndexPath:(NSIndexPath*)arg2
{
	BlacklistCell* cell = [[BlacklistCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier: @"myID"];
	cell.index = arg2.row;
	cell.textField.text = blacklistArray[arg2.row];

	return cell;
}

//each cell will be 45 high
-(double)tableView:(id)arg1 heightForRowAtIndexPath:(id)arg2
{
	return 45;
}

-(double)tableView:(id)arg1 heightForHeaderInSection:(long long)arg2
{
	return 0;
}

//allow editing of every cell
-(BOOL)tableView:(id)arg1 canEditRowAtIndexPath:(id)arg2
{
	return YES;
}

//handle the deletion of cells
-(void)tableView:(id)arg1 commitEditingStyle:(long long)arg2 forRowAtIndexPath:(NSIndexPath*)arg3
{
	[blacklistArray removeObjectAtIndex:arg3.row];
	[self setBlacklistArray];
	[self reloadTable];
}

-(void)textFieldDidEndEditing:(UITextField*)arg1
{
	NSInteger index = ((BlacklistCell*)[arg1 superview]).index;
	NSString* text = arg1.text;
	blacklistArray[index] = text;
	[self setBlacklistArray];

	UIBarButtonItem *addButton = [[UIBarButtonItem alloc]  initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addButtonPressed)];
	NSString *keyPath = (iOS11) ? @"superview.superview" : @"superview.superview.superview";
	[((NBLBlacklistController *)[[self valueForKeyPath:keyPath] _viewControllerForAncestor]).navigationItem setRightBarButtonItem:addButton];
	[self reloadTable];
}

-(void)textFieldDidBeginEditing:(UITextField*)arg1
{
	UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithTitle:@"Done" style:UIBarButtonItemStylePlain target:arg1 action:@selector(resignFirstResponder)];
	NSString *keyPath = (iOS11) ? @"superview.superview" : @"superview.superview.superview";
	[((NBLBlacklistController *)[[self valueForKeyPath:keyPath] _viewControllerForAncestor]).navigationItem setRightBarButtonItem:addButton];
}
@end

@implementation BlacklistCell
-(id)initWithStyle:(long long)arg1 reuseIdentifier:(id)arg2
{
	self = [super initWithStyle:arg1 reuseIdentifier:arg2];
	if (self)
	{
		_textField = [[UITextField alloc] initWithFrame:CGRectMake(50, 0, kWidth - 50, 45)];

		[self addSubview:_textField];
	}
	return self;
}

-(void)didMoveToSuperview
{
	[super didMoveToSuperview];
	NSString *keyPath = (iOS11) ? @"superview.superview" : @"superview.superview.superview";
	_textField.delegate = (BlacklistTableViewCell*)[self valueForKeyPath:keyPath];
}
@end
