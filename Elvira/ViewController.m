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
    
    self.musicManager = [[MusicManager alloc] init];
    
    self.reloadButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(loadLibrary)];
    
    self.libraryController = [[LibraryController alloc] initWithNibName:@"LibraryController" bundle:nil reloadButton:self.reloadButton musicManager:self.musicManager];
    [self.libraryController setLibrary:[[NSUserDefaults standardUserDefaults] dictionaryForKey:@"library"] cwd:[[NSMutableArray alloc] init]];
    [self.libraryController.navigationItem setRightBarButtonItem:self.reloadButton];
    
    self.libraryNavigationController = [[UINavigationController alloc] initWithRootViewController:self.libraryController];
    [self.libraryNavigationController.view setFrame:self.subView.frame];
    [self.subView addSubview:self.libraryNavigationController.view];
    
    [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(updateTimer) userInfo:nil repeats:YES];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)loadLibrary
{
    [self.reloadButton setEnabled:false];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        NSURL* url = [NSURL URLWithString:@"http://player.thelogin.ru/index/list_directory_files_multidimensional?directory="];
        NSURLRequest* request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:120.0];
        
        NSError* error = nil;
        NSURLResponse* response = nil;
        NSData* data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        
        JSONDecoder* jsonKitDecoder = [JSONDecoder decoder];
        NSDictionary* library = [jsonKitDecoder objectWithData:data];
        [[NSUserDefaults standardUserDefaults] setObject:library forKey:@"library"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.reloadButton setEnabled:true];
            
            // Update libraries and chdir .. if current folder does not exist
            LibraryController* lastOkController = self.libraryController;
            for (LibraryController* c in [self.libraryNavigationController viewControllers])
            {
                if ([c setLibrary:library cwd:c.cwd])
                {
                    lastOkController = c;
                }
                else
                {
                    [self.libraryNavigationController popToViewController:lastOkController animated:true];
                }
            }
        });
    });
}

- (void) updateTimer
{
    self.elapsed.text = [NSString stringWithFormat:@"%02d:%02d", (int)self.musicManager.elapsed / 60, (int)self.musicManager.elapsed % 60];
    self.total.text = [NSString stringWithFormat:@"%02d:%02d", (int)self.musicManager.total / 60, (int)self.musicManager.total % 60];
    
    self.position.maximumValue = self.musicManager.total;
    self.position.value = self.musicManager.elapsed;
}

- (IBAction) positionChanged:(UISlider*)sender
{
    [self.musicManager setPosition:sender.value];
}

@end
