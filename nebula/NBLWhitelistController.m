#include "NBLWhitelistController.h"

@implementation NBLWhitelistController

- (NSArray *)specifiers {
	if (!_specifiers) {
		_specifiers = [self loadSpecifiersFromPlistName:@"Whitelist" target:self];
	}

	return _specifiers;
}

@end
