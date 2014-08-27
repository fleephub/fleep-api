//
//  FLCommandLineClient.m
//  FleepClient
//
//  Created by Erik Laansoo on 29.10.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

#import "FLCommandLineClient.h"
#import "FLApi.h"
#import "FLApiInternal.h"

@interface FLCommand : NSObject
@property (nonatomic, readonly) NSString* command;
@property (nonatomic, readonly) NSArray* requiredArgs;
@property (nonatomic, readonly) NSArray* optionalArgs;
@property (nonatomic, readonly) FLCommandLineCommand body;
- (NSString*)usageStr;
@end

@implementation FLCommand
{
    NSString* _command;
    NSArray* _requiredArgs;
    NSArray* _optionalArgs;
    FLCommandLineCommand _body;
}

@synthesize command = _command;
@synthesize requiredArgs = _requiredArgs;
@synthesize optionalArgs = _optionalArgs;
@synthesize body = _body;

- (id)initWithCommand:(NSString*)command requiredArgs:(NSArray*)requiredArgs
    optionalArgs:(NSArray*)optionalArgs body:(FLCommandLineCommand)body
{
    if (self = [super init]) {
        _command = command;
        _requiredArgs = requiredArgs;
        _optionalArgs = optionalArgs;
        _body = body;
    }
    return self;
}

- (NSString*)usageStr
{
    NSMutableString* s = [_command mutableCopy];
    if (_requiredArgs != nil) {
        for (NSString* a in _requiredArgs) {
            [s appendFormat:@" %@", a];
        }
    }

    if (_optionalArgs != nil) {
        for (NSString* a in _optionalArgs) {
            [s appendFormat:@" [%@]", a];
        }
    }
    
    return s;
}

@end


@implementation FLCommandLineClient
{
    NSMutableArray* _commands;
    FLCommandLineCommand _body;
    NSMutableArray* _args;
    NSString* _executableName;
    NSString* _command;
}

- (id)initWithArgc:(int)argc argv:(const char *[])argv;
{
    if (self = [super init]) {
        _commands = [[NSMutableArray alloc] init];
        _args = [[NSMutableArray alloc] init];
        NSString* pathName = [NSString stringWithUTF8String:argv[0]];
        _executableName = pathName.pathComponents.lastObject;
        if (argc > 1) {
            _command = [NSString stringWithUTF8String:argv[1]];
            for (int i = 2; i < argc; i++) {
                [_args addObject:[NSString stringWithUTF8String:argv[i]]];
            }
        }
        [self addCommand:@"login" requiredArgs:@[@"username", @"password"] optionalArgs:nil body:nil];
        [self addCommand:@"logout" requiredArgs:nil optionalArgs:nil body:nil];
    }
    return self;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    FLApi* api = [FLApi api];

    if ([keyPath isEqualToString:@"loginStatus"]) {
        FLApiLoginStatus status = api.loginStatus;
        switch (status) {
            case FLApiLoginStatusLoggedIn: {
                if (api.eventHorizon > 0) {
                    printf("Login and synchronization completed\n");
                    [self performSelector:@selector(endProcess) withObject:nil afterDelay:0.1f];
                } else {
                    printf("Login successful, waiting for sync...\n");
                    [api addObserver:self forKeyPath:@"eventHorizon" options:0 context:nil];
                }
            }
            break;
            case FLApiLoginStatusLoggingIn: {
                printf("Login status: Logging in...\n");
            }
            break;
            case FLApiLoginStatusNotLoggedIn: {
                printf("Login status: Logged Out\n");
                if ([FLApi api].loginError != nil) {
                    printf("Error: %s\n", [[FLApi api].loginError.description cStringUsingEncoding:NSUTF8StringEncoding]);
                }
                [self handleLogout];
            }
            break;
        }
    }

    if ([keyPath isEqualToString:@"eventHorizon"]) {
        printf("Synchronization progress: %ld%%\n", (long)(api.syncProgress * 100.0f));
        if (api.eventHorizon > 0) {
            printf("Synchronization complete.\n");
            [[FLApi api]removeObserver:self forKeyPath:@"eventHorizon"];
            [self performSelector:@selector(endProcess) withObject:nil afterDelay:0.1f];
        }
    }
}

- (void)endProcess
{
    [[NSUserDefaults standardUserDefaults] synchronize];
    exit(0);
}

- (void)handleLogout
{
    [self performSelector:@selector(endProcess) withObject:nil afterDelay:0.1f];
}

- (void)addCommand:(NSString*)cmd requiredArgs:(NSArray*)requiredArgs
    optionalArgs:(NSArray*)optionalArgs body:(FLCommandLineCommand)body
{
    FLCommand* c = [[FLCommand alloc]
        initWithCommand:cmd requiredArgs:requiredArgs optionalArgs:optionalArgs body:body];
    [_commands addObject:c];
}

- (void)printUsage
{
    printf("Usage: %s command [args]\n", _executableName.UTF8String);
    printf("\n");
    printf("Commands:\n");
    printf("\n");
    for (FLCommand* c in _commands) {
        printf("    %s\n", c.usageStr.UTF8String);
    }
}

- (void)doDefault:(NSArray*)args
{
    if (_body != nil) {
        _body(args);
    } else {
        [self printUsage];
        exit(1);
    }
}

- (void)exitWithMessage:(NSString*)message
{
    if (message != nil) {
        printf("%s\n", message.UTF8String);
    }
    exit(1);
}

- (void)doLogin:(NSArray*)args
{
    if ([FLApi api].loginStatus != FLApiLoginStatusNotLoggedIn) {
        [self exitWithMessage:[NSString stringWithFormat:@"Already logged in as %@\n", [FLApi api].credentials.email]];
    }

    [[FLApi api] loginWithEmail:args[0] password:args[1]];
}

- (void)doLogout:(NSArray*)args
{
    [[FLApi api]logoutOnError:^(NSError *error) {
        printf("Logout failed: %s\n", error.localizedDescription.UTF8String);
    }];
    [[FLApi api].credentials erase];
}

- (void)setDefaultBody:(FLCommandLineCommand)body
{
    _body = body;
}

- (void)handleApiError:(NSError *)error
{
    printf("Error: %s", error.description.UTF8String);
    exit(1);
}

- (void)run
{
    if (![_command isEqualToString:@"login"]) {
        if ([FLApi api].loginStatus != FLApiLoginStatusLoggedIn) {
            [self exitWithMessage:[NSString stringWithFormat:@"Not logged in, use \"%@ login\" to create credentials", _executableName]];
        } else {
            if ([FLApi api].eventHorizon <= 0 && ![_command isEqualToString:@"logout"]) {
                [self exitWithMessage:@"Synchronization incomplete, please relogin.\n"];
            }
        }
    }

    if (_command == nil) {
        [self doDefault: nil];
    } else {
        FLCommand* c = nil;
        for (FLCommand* cc in _commands) {
            if ([_command isEqualToString:cc.command]) {
                c = cc;
                break;
            }
        }

        if (c == nil) {
            [self printUsage];
            exit(1);
        }

        [[FLApi api]addObserver:self forKeyPath:@"loginStatus" options:0 context:nil];
        [FLApi api].defaultErrorHandler = ^(NSError* error) {
            [self handleApiError:error];
        };

        NSInteger expectedArgs = (c.requiredArgs != nil) ? c.requiredArgs.count : 0;
        NSInteger maxArgs = expectedArgs + ((c.optionalArgs != nil) ? c.optionalArgs.count : 0);

        if ((_args.count < expectedArgs) || (_args.count > maxArgs)) {
            [self exitWithMessage:[NSString stringWithFormat: @"Usage: %@ %@", _executableName, c.usageStr]];
        }

        if (c.body != nil) {
            c.body(_args);
        } else {
            SEL s = NSSelectorFromString([NSString stringWithFormat:@"do%@:", [c.command capitalizedString]]);
            if ([self respondsToSelector:s]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                [self performSelector:s withObject: _args];
#pragma clang diagnostic pop
            } else {
                [self exitWithMessage: [NSString stringWithFormat: @"Error: no implementation for \"%@\"", _command]];
            }
        }
    }

    [[NSRunLoop mainRunLoop] run];
}

- (NSString*)readStandardInput
{
    return [NSString stringWithContentsOfFile:@"/dev/stdin"  encoding:NSUTF8StringEncoding error:nil];
}

@end
