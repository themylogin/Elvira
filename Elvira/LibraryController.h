//
//  LibraryController.h
//  Elvira
//
//  Created by themylogin on 30.04.12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MusicManager.h"

@interface LibraryController : UITableViewController

@property (nonatomic, retain) NSDictionary* library;
@property (nonatomic, retain) NSMutableArray* cwd;
@property (nonatomic, retain) MusicManager* mm;
@property (nonatomic, retain) NSMutableArray* directories;
@property (nonatomic, retain) NSMutableArray* files;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil library:(NSDictionary *)library cwd:(NSMutableArray *)cwd musicManager:(MusicManager *)mm;

@end
