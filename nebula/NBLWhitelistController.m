#include "NBLWhitelistController.h"

@implementation NBLWhitelistController

- (NSArray *)specifiers {
	if (!_specifiers) {
		_specifiers = [[self loadSpecifiersFromPlistName:@"Whitelist" target:self] retain];
	}

	return _specifiers;
}

@end
