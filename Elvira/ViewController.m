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
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(update) name:@"change" object:self.musicManager];
    [self update];
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
        NSURL* url = [NSURL URLWithString:[[[NSUserDefaults standardUserDefaults] stringForKey:@"player_url"] stringByAppendingString:@"/index/list_directory_files_multidimensional?directory="]];
        NSURLRequest* request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:120.0];
        
        NSError* error = nil;
        NSURLResponse* response = nil;
        NSData* data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        
        if (error || [(NSHTTPURLResponse*)response statusCode] != 200)
        {
            NSString* errorDescription;
            if (error)
            {
                errorDescription = [error localizedDescription];
            }
            else
            {
                errorDescription = [[NSString alloc] initWithFormat:@"HTTP %d", [(NSHTTPURLResponse*)response statusCode], nil];
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{                
                UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"Ошибка обновления библиотеки"
                                                                message:errorDescription
                                                               delegate:nil
                                                      cancelButtonTitle:@"ОК"
                                                      otherButtonTitles:nil];
                [alert show];
                
                [self.reloadButton setEnabled:true];
            });
            return;
        }
        
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

- (void) update
{
    self.elapsed.text = [NSString stringWithFormat:@"%02d:%02d", (int)self.musicManager.nowPlayingElapsed / 60, (int)self.musicManager.nowPlayingElapsed % 60];
    self.total.text = [NSString stringWithFormat:@"%02d:%02d", (int)self.musicManager.nowPlayingTotal / 60, (int)self.musicManager.nowPlayingTotal % 60];
    
    self.position.maximumValue = self.musicManager.nowPlayingTotal;
    self.position.value = self.musicManager.nowPlayingElapsed;
}

- (IBAction) togglePause:(UIButton*)sender
{
    [self.musicManager togglePause];
}

- (IBAction) positionChanged:(UISlider*)sender
{
    [self.musicManager seekTo:sender.value];
}

@end
