//
//  LibraryController.m
//  Elvira
//
//  Created by themylogin on 30.04.12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "LibraryController.h"
#import "QuartzCore/QuartzCore.h"

#include "MusicFile.h"

@implementation LibraryController

@synthesize reloadButton;
@synthesize musicManager;
@synthesize library;
@synthesize cwd;
@synthesize directories;
@synthesize files;

- (id)initWithNibName:(NSString*)nibNameOrNil bundle:(NSBundle*)nibBundleOrNil reloadButton:(UIBarButtonItem*)_reloadButton musicManager:(MusicManager*)_musicManager
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
    {
        self.reloadButton = _reloadButton;
        self.musicManager = _musicManager;
        
        // subscribe to mm events
        [[NSNotificationCenter defaultCenter] addObserver:self.tableView selector:@selector(reloadData) name:@"musicManagerStateChange" object:self.musicManager];
    }
    return self;
}

- (BOOL)setLibrary:(NSDictionary *)_library cwd:(NSMutableArray *)_cwd
{
    self.library = _library;
    self.cwd = _cwd;
    
    // chdir to cwd
    NSDictionary* cwdDictionary = self.library;
    for (NSString* element in self.cwd)
    {
        id object = [cwdDictionary objectForKey:element];
        if ([object isKindOfClass:[NSDictionary class]])
        {
            cwdDictionary = object;
        }
        else
        {
            return false;
        }
    }
    
    // fill directories and files
    self.directories = [[NSMutableArray alloc] initWithCapacity:[cwdDictionary count]];
    self.files = [[NSMutableArray alloc] initWithCapacity:[cwdDictionary count]];
    for (NSString* key in cwdDictionary)
    {
        if ([[cwdDictionary objectForKey:key] isKindOfClass:[NSDictionary class]])
        {
            [self.directories addObject:key];
        }
        else
        {
            [self.files addObject:key];
        }
    }
    [self.directories sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    [self.files sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    
    // set title
    if (self.cwd.count)
    {
        self.navigationItem.title = [cwd lastObject];
    }
    
    // update table
    [self.tableView reloadData];
    
    return true;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self.navigationItem setRightBarButtonItem:self.reloadButton];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section
{
    return [directories count] + [files count];
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString* cellIdentifier = @"Cell";
    
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil)
    {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier] autorelease];
        cell.textLabel.adjustsFontSizeToFitWidth = true;
        cell.textLabel.minimumFontSize = 8;
    }
    
    if (indexPath.row < directories.count)
    {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.textLabel.text = [directories objectAtIndex:indexPath.row];
    }
    else
    {
        NSString* filename = [files objectAtIndex:indexPath.row - directories.count];
        NSString* filenameWithoutExtension = [[NSRegularExpression regularExpressionWithPattern:@"\\.[^.]+$" options:0 error:nil] stringByReplacingMatchesInString:filename options:0 range:NSMakeRange(0, [filename length]) withTemplate:@""];
        
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.textLabel.text = filenameWithoutExtension;
    }
    
    return cell;
}

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row < self.directories.count)
    {
        NSMutableArray* newCwd = [[NSMutableArray alloc] initWithArray:self.cwd copyItems:YES];
        [newCwd addObject:[self.directories objectAtIndex:indexPath.row]];
        
        LibraryController* libraryController = [[LibraryController alloc] initWithNibName:@"LibraryController" bundle:nil reloadButton:self.reloadButton musicManager:self.musicManager];
        [libraryController setLibrary:self.library cwd:newCwd];
        [self.navigationController pushViewController:libraryController animated:YES];
    }
    else
    {
        [musicManager wantFile:[[MusicFile alloc] initWithFilename:[files objectAtIndex:indexPath.row - directories.count] locatedIn:cwd]];
        musicManager.playlist = files;
    }
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    cell.backgroundColor = [UIColor clearColor];
    cell.backgroundView = nil;
    cell.textLabel.textColor = [UIColor blackColor];
    
    if (indexPath.row < directories.count)
    {
        // ...
    }
    else
    {
        MusicFile* file = [[MusicFile alloc] initWithFilename:[files objectAtIndex:indexPath.row - directories.count] locatedIn:cwd];
        MusicState state = [musicManager getStateOfFile:file];
        if (state == NotBuffered)
        {
            cell.backgroundColor = [UIColor colorWithRed:0.95 green:0.95 blue:0.95 alpha:1.0];
        }
        if (state == Buffering)
        {
            float progress = [musicManager getFileBufferingProgress:file];
            UIView* view = [[UIView alloc] initWithFrame:cell.contentView.bounds];
            CAGradientLayer* gradient = [CAGradientLayer layer];
            gradient.frame = view.bounds;
            gradient.colors = [NSArray arrayWithObjects:(id)[[UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:1.0] CGColor], [[UIColor colorWithRed:0.95 green:0.95 blue:0.95 alpha:1.0] CGColor], nil];
            gradient.locations = [NSArray arrayWithObjects:[NSNumber numberWithFloat:progress], (id)[NSNumber numberWithFloat:progress], nil];
            gradient.startPoint = CGPointMake(0.0, 0.5);
            gradient.endPoint = CGPointMake(1.0, 0.5);
            [view.layer insertSublayer:gradient atIndex:0];
            cell.backgroundView = view;   
        }
        if (state == Buffered)
        {
            cell.backgroundColor = [UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:1.0];
        }
        if (state == Playing)
        {
            cell.backgroundColor = [UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:1.0];
            cell.textLabel.textColor = [UIColor orangeColor];
        }
    }
}

@end
