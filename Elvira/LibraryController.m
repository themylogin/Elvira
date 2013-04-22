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

- (id)initWithNibName:(NSString*)nibNameOrNil bundle:(NSBundle*)nibBundleOrNil reloadButton:(UIBarButtonItem*)aReloadButton musicManager:(MusicManager*)aMusicManager
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
    {
        self.reloadButton = aReloadButton;
        
        self.musicManager = aMusicManager;        
        [[NSNotificationCenter defaultCenter] addObserver:self.tableView selector:@selector(reloadData) name:@"change" object:self.musicManager];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self.navigationItem setRightBarButtonItem:self.reloadButton];
    
    UISwipeGestureRecognizer* bufferGestureRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(buffer:)];
    [bufferGestureRecognizer setDirection:UISwipeGestureRecognizerDirectionRight];
    [self.tableView addGestureRecognizer:bufferGestureRecognizer];
    
    UISwipeGestureRecognizer* stopBufferingGestureRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(stopBuffering:)];
    [bufferGestureRecognizer setDirection:UISwipeGestureRecognizerDirectionLeft];
    [self.tableView addGestureRecognizer:stopBufferingGestureRecognizer];
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

- (BOOL)setLibrary:(NSDictionary *)aLibrary cwd:(NSMutableArray *)aCwd
{
    self.library = aLibrary;
    self.cwd = aCwd;
    
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
        musicManager.playlist = [[NSMutableArray alloc] init];
        for (int i = indexPath.row - directories.count; i < self.files.count; i++)
        {
            [musicManager.playlist addObject:[[MusicFile alloc] initWithFilename:[files objectAtIndex:i] locatedIn:cwd]];
        }        
        MusicFile* file = [musicManager.playlist objectAtIndex:0];
        [musicManager.playlist removeObjectAtIndex:0];
        [musicManager playFile:file];
    }
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    cell.backgroundColor = [UIColor clearColor];
    cell.backgroundView = nil;
    cell.textLabel.textColor = [UIColor blackColor];
    
    if (indexPath.row < directories.count)
    {
        if ([musicManager willBufferAnythingInDirectory:[directories objectAtIndex:indexPath.row] locatedIn:cwd])
        {
            cell.textLabel.textColor = [UIColor blueColor];
        }
    }
    else
    {
        MusicState state = [musicManager getStateOfFile:[self fileAtIndexPath:indexPath]];
        
        if (state.state == NotBuffered)
        {
            cell.textLabel.textColor = [UIColor grayColor];
        }
        if (state.state == Buffering || state.state == BufferingPlaying)
        {            
            UIView* view = [[UIView alloc] initWithFrame:cell.contentView.bounds];
            CAGradientLayer* gradient = [CAGradientLayer layer];
            gradient.frame = view.bounds;
            gradient.colors = [NSArray arrayWithObjects:(id)[[UIColor whiteColor] CGColor], [[UIColor grayColor] CGColor], nil];
            gradient.locations = [NSArray arrayWithObjects:[NSNumber numberWithFloat:state.buffering.progress], (id)[NSNumber numberWithFloat:state.buffering.progress], nil];
            gradient.startPoint = CGPointMake(0.0, 0.5);
            gradient.endPoint = CGPointMake(1.0, 0.5);
            [view.layer insertSublayer:gradient atIndex:0];
            cell.backgroundView = view;   
        }
        if (state.state == Buffered)
        {
        }
        if (state.state == BufferingPlaying || state.state == BufferedPlaying)
        {
            cell.textLabel.textColor = [UIColor orangeColor];
        }
    }
}

#pragma mark - Table view gestures

- (void) buffer:(UISwipeGestureRecognizer*)gestureRecognizer
{
    NSIndexPath* indexPath = [self.tableView indexPathForRowAtPoint:[gestureRecognizer locationInView:self.tableView]];
    if (indexPath)
    {
        if (indexPath.row < self.directories.count)
        {
            NSMutableArray* filesToBuffer = [[NSMutableArray alloc] init];
            
            NSMutableArray* queue = [[NSMutableArray alloc] init];
            [queue addObject:[self.cwd arrayByAddingObject:[self.directories objectAtIndex:indexPath.row]]];
            while (queue.count > 0)
            {
                // get arg
                NSMutableArray* arg = [queue objectAtIndex:0];
                [queue removeObjectAtIndex:0];
                
                // chdir to cwd
                NSDictionary* cwdDictionary = self.library;
                for (NSString* element in arg)
                {
                    id object = [cwdDictionary objectForKey:element];
                    if ([object isKindOfClass:[NSDictionary class]])
                    {
                        cwdDictionary = object;
                    }
                    else
                    {
                        return;
                    }
                }
                
                // fill directories and files
                NSMutableArray* argDirectories = [[NSMutableArray alloc] initWithCapacity:[cwdDictionary count]];
                NSMutableArray* argFiles = [[NSMutableArray alloc] initWithCapacity:[cwdDictionary count]];
                for (NSString* key in cwdDictionary)
                {
                    if ([[cwdDictionary objectForKey:key] isKindOfClass:[NSDictionary class]])
                    {
                        [argDirectories addObject:key];
                    }
                    else
                    {
                        [argFiles addObject:key];
                    }
                }
                [argDirectories sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
                [argFiles sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
                
                // buffer all directories
                for (NSString* directory in argDirectories)
                {
                    [queue addObject:[arg arrayByAddingObject:directory]];
                }
                // buffer all files
                for (NSString* file in argFiles)
                {
                    [filesToBuffer addObject:[[MusicFile alloc] initWithFilename:file locatedIn:arg]];
                    if (filesToBuffer.count > 128)
                    {
                        return;
                    }
                }
            }
            
            for (MusicFile* file in filesToBuffer)
            {
                [self.musicManager bufferFile:file];
            }
        }
        else
        {
            [self.musicManager bufferFile:[self fileAtIndexPath:indexPath]];
        }
    }
}


- (void) stopBuffering:(UISwipeGestureRecognizer*)gestureRecognizer
{
    NSIndexPath* indexPath = [self.tableView indexPathForRowAtPoint:[gestureRecognizer locationInView:self.tableView]];
    if (indexPath)
    {
        if (indexPath.row < self.directories.count)
        {
            [self.musicManager stopBufferingDirectory:[self.cwd arrayByAddingObject:[self.directories objectAtIndex:indexPath.row]]];
        }
        else
        {
            [self.musicManager stopBufferingFile:[self fileAtIndexPath:indexPath]];
        }
    }
}

#pragma mark - Internals

- (MusicFile*) fileAtIndexPath:(NSIndexPath*)indexPath
{
    return [[MusicFile alloc] initWithFilename:[self.files objectAtIndex:indexPath.row - self.directories.count] locatedIn:self.cwd];
}

@end
