#import <Preferences/PSListController.h>

@interface UIView (Nebula)
-(id)_viewControllerForAncestor;
@end

@interface NSUserDefaults (Nebula) {
}
- (id)objectForKey:(id)key inDomain:(id)d;
- (void)setObject:(id)obj forKey:(id)key inDomain:(id)d;
@end

@interface NBLBlacklistController : PSListController

@end

@interface BlacklistTableViewCell : UITableViewCell <UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>
{
    UITableView* blacklistTable;
    NSMutableArray* blacklistArray;
}
-(id)initWithSpecifier:(id)arg1;
-(void)reloadTable;
-(void)getBlacklistArray;
-(void)setBlacklistArray;
-(CGFloat)preferredHeightForWidth:(CGFloat)arg1;
-(void)addButtonPressed;

-(long long)numberOfSectionsInTableView:(id)arg1;
-(long long)tableView:(id)arg1 numberOfRowsInSection:(long long)arg2;
-(id)tableView:(id)arg1 cellForRowAtIndexPath:(id)arg2;
-(double)tableView:(id)arg1 heightForRowAtIndexPath:(id)arg2;
-(double)tableView:(id)arg1 heightForHeaderInSection:(long long)arg2;
-(BOOL)tableView:(id)arg1 canEditRowAtIndexPath:(id)arg2;
-(void)tableView:(id)arg1 commitEditingStyle:(long long)arg2 forRowAtIndexPath:(id)arg3;

-(void)textFieldDidEndEditing:(id)arg1;
-(void)textFieldDidBeginEditing:(id)arg1;
@end

@interface BlacklistCell : UITableViewCell
@property (nonatomic, retain) UITextField* textField;
@property (nonatomic, readwrite) NSInteger index;
-(id)initWithStyle:(long long)arg1 reuseIdentifier:(id)arg2;
@end
