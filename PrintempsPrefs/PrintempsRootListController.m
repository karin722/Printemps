#import <Foundation/Foundation.h>
#import "PrintempsRootListController.h"
#include <spawn.h>

@implementation PrintempsRootListController

- (NSArray *)specifiers {
	if (!_specifiers) {
		_specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
	}

	return _specifiers;
}

- (void)respring {
	pid_t pid;
	const char *cmd[] = {"/usr/bin/killall", "-9", "SpringBoard", NULL};
	posix_spawn(&pid, "/usr/bin/killall", NULL, NULL, (char* const*)cmd, NULL);
}

- (void)github {
	[[UIApplication sharedApplication]
	openURL:[NSURL URLWithString:@"https://github.com/karin722/Printemps"]
	options:@{}
	completionHandler:nil];
}

- (void)twitter {
	[[UIApplication sharedApplication]
	openURL:[NSURL URLWithString:@"https://twitter.com/tako3s"]
	options:@{}
	completionHandler:nil];
}

@end
