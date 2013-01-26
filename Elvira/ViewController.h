//
//  ViewController.h
//  Elvira
//
//  Created by themylogin on 30.04.12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#include "MusicManager.h"

@interface ViewController : UIViewController

@property (nonatomic, retain) MusicManager* musicManager;

- (void)reloadLibrary;

@end
