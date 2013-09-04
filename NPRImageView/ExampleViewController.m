//
//  ViewController.m
//  ImageViewProgressActivity
//
//  Created by Nico Prananta on 4/22/13.
//  Copyright (c) 2013 Touches. All rights reserved.
//

#import "ExampleViewController.h"

#import "ImageViewCell.h"

#import <EXTScope.h>

#define MAX_IMAGES 100

@interface ExampleViewController ()

@property (nonatomic, strong) NSArray *images;

@end

@implementation ExampleViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self.tableView setRowHeight:310];
    [self.tableView setSeparatorStyle:UITableViewCellSeparatorStyleNone];
    
    [self getImageUrls];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.images.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    ImageViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) {
        cell = [[ImageViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
        [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
    }
    [cell setImageURL:[self.images objectAtIndex:indexPath.row] placeholderImage:nil];
    [cell.customTextLabel setText:[NSString stringWithFormat:@"Row %d", indexPath.row]];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSLog(@"Selected: %@", [[self.images objectAtIndex:indexPath.row] absoluteString]);
}

- (void)getImageUrls
{
    @weakify(self);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @strongify(self);
        NSMutableArray *urls = [NSMutableArray array];
        //google image api has an 8 page max, with 8 images per page, so 64 image max per search term
        int urls_grabbed = 0;
        for (int i = 0; i < 8; i++) {
            if (urls_grabbed < MAX_IMAGES) {
                NSURL *jsonURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://ajax.googleapis.com/ajax/services/search/images?v=1.0&q=maki+horikita&rsz=8&start=%d", i * 8]];
                NSData *jsonData = [NSData dataWithContentsOfURL:jsonURL];
                
                id json = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableLeaves error:nil];
                for (id result in [[json objectForKey:@"responseData"] objectForKey:@"results"]) {
                    [urls addObject:[NSURL URLWithString:[result objectForKey:@"url"]]];
                }
                
                urls_grabbed++;
            }
        }
        
        self.images = [NSArray arrayWithArray:urls];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.tableView reloadData];
        });
    });
}


@end
