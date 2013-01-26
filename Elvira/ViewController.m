//
//  ViewController.m
//  Elvira
//
//  Created by themylogin on 30.04.12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "ViewController.h"
#import "JSONKit.h"
#import "LibraryController.h"

@interface ViewController ()

@end

@implementation ViewController

@synthesize musicManager;

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    NSDictionary* library = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"library"];
    NSMutableArray* cwd = [[NSMutableArray alloc] init];
    
    self.musicManager = [[MusicManager alloc] init];
    LibraryController* libraryController = [[LibraryController alloc] initWithNibName:@"LibraryController" bundle:nil library:library cwd:cwd musicManager:self.musicManager];
    [libraryController.navigationItem setRightBarButtonItem:[[UIBarButtonItem alloc] initWithTitle:@"Reload" style:UIBarButtonItemStylePlain target:self action:@selector(reloadLibrary)]];
    UINavigationController* libraryNavigationController = [[UINavigationController alloc] initWithRootViewController:libraryController];
    [[libraryNavigationController view] setFrame:CGRectMake(0, 0, 320, 360)];
    [self.view addSubview:[libraryNavigationController view]];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return (interfaceOrientation == UIInterfaceOrientationPortrait);
    } else {
        return YES;
    }
}

- (void)reloadLibrary
{
    NSURL* url = [NSURL URLWithString:@"http://player.thelogin.ru/index/list_directory_files_multidimensional?directory="];
    NSURLRequest* request = [NSURLRequest requestWithURL:url];
    NSError* error = nil;
    NSURLResponse* response = nil;
    NSData* data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    JSONDecoder* jsonKitDecoder = [JSONDecoder decoder];
    NSDictionary* library = [jsonKitDecoder objectWithData:data];
    [[NSUserDefaults standardUserDefaults] setObject:library forKey:@"library"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end
