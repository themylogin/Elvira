//
//  LibraryController.m
//  Elvira
//
//  Created by themylogin on 30.04.12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "LibraryController.h"
#import "QuartzCore/QuartzCore.h"

@interface LibraryController ()

@end

@implementation LibraryController

@synthesize library, cwd, mm, directories, files;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil library:(NSDictionary *)_library cwd:(NSMutableArray *)_cwd musicManager:(MusicManager *)_mm
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
    {
        // store references
        self.library = _library;
        self.cwd = _cwd;
        self.mm = _mm;
        
        // chdir to cwd
        NSDictionary* cwdDictionary = library;
        NSEnumerator* enumerator = [cwd objectEnumerator];
        NSString* element;
        while (element = [enumerator nextObject])
        {
            id object = [cwdDictionary objectForKey:element];
            if (object == nil || !([object isKindOfClass:[NSDictionary class]]))
            {
                [self.cwd release];
                self.cwd = [[NSMutableArray alloc] init];
                cwdDictionary = library;
                break;
            }
            cwdDictionary = object;
        }
        
        // fill directories and files
        self.directories = [[NSMutableArray alloc] initWithCapacity:[cwdDictionary count]];
        self.files = [[NSMutableArray alloc] initWithCapacity:[cwdDictionary count]];    
        enumerator = [cwdDictionary keyEnumerator];
        NSString* key;
        while (key = [enumerator nextObject])
        {
            if ([[cwdDictionary objectForKey:key] isKindOfClass:[NSDictionary class]])
            {
                [directories addObject:key];
            }
            else
            {
                [files addObject:key];
            }
        }    
        [directories sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
        [files sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
        
        // set title
        if (cwd.count)
        {
            self.navigationItem.title = [cwd lastObject];
        }
        
        // subscribe to mm events
        [[NSNotificationCenter defaultCenter] addObserver:self.tableView selector:@selector(reloadData) name:@"musicManagerStateChange" object:mm];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
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
    }
    
    if (indexPath.row < directories.count)
    {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.textLabel.text = [directories objectAtIndex:indexPath.row];
    }
    else
    {
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.textLabel.text = [files objectAtIndex:indexPath.row - directories.count];
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
    if (indexPath.row < directories.count)
    {
        NSMutableArray* newCwd = [[NSMutableArray alloc] initWithArray:cwd copyItems:YES];
        [newCwd addObject:[directories objectAtIndex:indexPath.row]];
        
        LibraryController* libraryController = [[LibraryController alloc] initWithNibName:@"LibraryController" bundle:nil library:library cwd:newCwd musicManager:mm];
        [self.navigationController pushViewController:libraryController animated:YES];
        [libraryController release];
    }
    else
    {
        [mm playFile:[files objectAtIndex:indexPath.row - directories.count] locatedIn:cwd];
        mm.playlist = files;
    }
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    cell.backgroundColor = [UIColor clearColor];
    cell.backgroundView = nil;
    
    if (indexPath.row < directories.count)
    {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.textLabel.text = [directories objectAtIndex:indexPath.row];
    }
    else
    {
        MusicState state = [mm getStateOfFile:[files objectAtIndex:indexPath.row - directories.count] locatedIn:cwd];
        if (state == Buffering)
        {
            float progress = [mm getFileBufferingProgress:[files objectAtIndex:indexPath.row - directories.count] locatedIn:cwd];
            UIView* view = [[UIView alloc] initWithFrame:cell.contentView.bounds];
            CAGradientLayer* gradient = [CAGradientLayer layer];
            gradient.frame = view.bounds;
            gradient.colors = [NSArray arrayWithObjects:(id)[[UIColor lightGrayColor] CGColor], (id)[[UIColor whiteColor] CGColor], nil];
            gradient.locations = [NSArray arrayWithObjects:[NSNumber numberWithFloat:progress], (id)[NSNumber numberWithFloat:progress], nil];
            gradient.startPoint = CGPointMake(0.0, 0.5);
            gradient.endPoint = CGPointMake(1.0, 0.5);
            [view.layer insertSublayer:gradient atIndex:0];
            cell.backgroundView = view;   
        }
        if (state == Buffered)
        {
            cell.backgroundColor = [UIColor lightGrayColor];
        }
        if (state == Playing)
        {
            cell.backgroundColor = [UIColor greenColor];
        }
    }
}

@end
