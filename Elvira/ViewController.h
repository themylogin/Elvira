//
//  ViewController.h
//  Elvira
//
//  Created by themylogin on 30.04.12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#include "LibraryController.h"
#include "MusicManager.h"

@interface ViewController : UIViewController

@property (nonatomic, retain) MusicManager* musicManager;

@property (nonatomic, retain) UIBarButtonItem* reloadButton;
@property (nonatomic, retain) LibraryController* libraryController;
@property (nonatomic, retain) UINavigationController* libraryNavigationController;

@property (nonatomic, retain) IBOutlet UILabel* elapsed;
@property (nonatomic, retain) IBOutlet UILabel* total;
@property (nonatomic, retain) IBOutlet UISlider* position;

- (void)loadLibrary;
- (void)updateTimer;

- (IBAction) positionChanged:(UISlider*)sender;

@end
