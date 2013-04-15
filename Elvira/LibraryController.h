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

@property (nonatomic, retain) UIBarButtonItem* reloadButton;
@property (nonatomic, retain) MusicManager* musicManager;

@property (nonatomic, retain) NSDictionary* library;
@property (nonatomic, retain) NSMutableArray* cwd;

@property (nonatomic, retain) NSMutableArray* directories;
@property (nonatomic, retain) NSMutableArray* files;

- (id)initWithNibName:(NSString*)nibNameOrNil bundle:(NSBundle*)nibBundleOrNil reloadButton:(UIBarButtonItem*)reloadButton musicManager:(MusicManager*)musicManager;

- (BOOL)setLibrary:(NSDictionary*)library cwd:(NSMutableArray*)cwd;

@end
