#import <Foundation/Foundation.h>
#import "PrintempsRootListController.h"
#include <spawn.h>
#include <unistd.h>

@implementation PrintempsRootListController

- (NSArray *)specifiers {
	if (!_specifiers) {
		_specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
	}

	return _specifiers;
}

- (void)respring {
	// killall lives under the jailbreak prefix on rootless installs and in /usr/bin
	// on rootful ones, so take whichever of the two is actually there.
	const char *paths[] = {"/var/jb/usr/bin/killall", "/usr/bin/killall"};
	for (size_t i = 0; i < sizeof(paths) / sizeof(*paths); i++) {
		if (access(paths[i], X_OK) != 0) continue;

		pid_t pid;
		const char *argv[] = {paths[i], "-9", "SpringBoard", NULL};
		posix_spawn(&pid, paths[i], NULL, NULL, (char *const *)argv, NULL);
		return;
	}
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
