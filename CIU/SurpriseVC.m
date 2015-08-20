//
//  SurpriseVC.m
//  CIU
//
//  Created by Sihang Huang on 10/14/14.
//  Copyright (c) 2014 Huang, Sihang. All rights reserved.
//

#import "SurpriseVC.h"
#import "SurpriseTableViewCell.h"
#import <Parse/Parse.h>
#import "ComposeSurpriseVC.h"
#import "LogInVC.h"
#import "Helper.h"
#import "CommentVC.h"
#import <MessageUI/MessageUI.h>
#import <MessageUI/MFMailComposeViewController.h>
#import "CommentVC.h"
#import <CoreData/CoreData.h>
#import "SharedDataManager.h"
#import "StatusObject.h"
#import "ComposeSurpriseVC.h"
#import "SpinnerImageView.h"
#import "NSPredicate+Utilities.h"
#import "PFQuery+Utilities.h"
#import "TabbarController.h"
#import "StatusObject+Utilities.h"
#import "ImageCollectionViewCell.h"

static float const kStatusRadius = 30;
static float const kServerFetchCount = 100;
static float const kLocalFetchCount = 50;
static UIImage *defaultAvatar;
static NSString *const kEntityName = @"StatusObject";

#define BACKGROUND_CELL_HEIGHT 300.0f
#define ORIGIN_Y_CELL_MESSAGE_LABEL 54.0f

@interface SurpriseVC () <UIAlertViewDelegate, StatusTableViewCellDelegate,UITableViewDataSource,UITableViewDelegate> {
    SurpriseTableViewCell *cellToRevive;
    UITapGestureRecognizer *tapGesture;
    CommentVC *commentVC;
    CGRect commentViewOriginalFrame;
    NSIndexPath *selectedPath;
}

@property (nonatomic, strong) NSMutableDictionary *avatarQueries;
@property (nonatomic, strong) NSMutableDictionary *postImageQueries;
@property (nonatomic, strong) NSMutableDictionary *surpriseImagesArrayByIndexPath;

@end

@implementation SurpriseVC

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    
    if (self) {
        self.surpriseImagesArrayByIndexPath = [NSMutableDictionary dictionary];
        self.avatarQueries = [NSMutableDictionary dictionary];
        self.postImageQueries = [NSMutableDictionary dictionary];
        defaultAvatar = [UIImage imageNamed:@"default-user-icon-profile.png"];
    }
    
    return self;
}

- (NSString *)serverDataParseClassName
{
    return DDStatusParseClassName;
}

- (NSString *)localDataEntityName
{
    return kEntityName;
}

- (float)dataFetchRadius
{
    return kStatusRadius;
}

- (float)serverFetchCount
{
    return kServerFetchCount;
}

- (float)localFetchCount
{
    return kLocalFetchCount;
}

- (NSString *)keyForIndexPath:(NSIndexPath *)indexPath
{
    return [NSString stringWithFormat:@"%d:%d",(int)indexPath.row, (int)indexPath.section];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self addRefreshControle];
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    self.tabBarController.tabBar.hidden = NO;
    [[PFUser currentUser] fetchInBackground];
    [Flurry logEvent:@"View surprise" timed:YES];
}

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [Flurry endTimedEvent:@"View surprise" withParameters:nil];
}

- (void)populateManagedObject:(NSManagedObject *)managedObject
              fromParseObject:(PFObject *)object
{
    [((StatusObject *)managedObject) populateFromParseObject:object];
}

- (void)setupServerQueryWithClassName:(NSString *)className
                           fetchLimit:(NSUInteger)fetchLimit
                          fetchRadius:(CGFloat)fetchRadius
                     greaterOrEqualTo:(NSDate *)greaterDate
                      lesserOrEqualTo:(NSDate *)lesserDate
{
    if (self.fetchQuery) {
        [self.fetchQuery cancel];
        self.fetchQuery = nil;
    }
    
    NSDictionary *dictionary = [Helper userLocation];
    if (!dictionary) {
        
        return;
    }
    
    // Subquries: fetch geo-bounded objects and "on top" objects
    
    PFQuery *geoQuery = [[PFQuery alloc] initWithClassName:className];
    CLLocationCoordinate2D center = CLLocationCoordinate2DMake([dictionary[DDLatitudeKey] doubleValue],
                                                               [dictionary[DDLongitudeKey] doubleValue]);
    [geoQuery addBoundingCoordinatesToCenter:center
                                      radius:@(fetchRadius)];
    
    PFQuery *stickyPostQuery = [[PFQuery alloc] initWithClassName:className];
    [stickyPostQuery whereKey:DDIsStickyPostKey
                      equalTo:@YES];
    
    self.fetchQuery = [PFQuery orQueryWithSubqueries:@[geoQuery, stickyPostQuery]];
    [self.fetchQuery orderByDescending:DDCreatedAtKey];
    [self.fetchQuery whereKey:DDIsBadContentKey
                   notEqualTo:@YES];
    
    if (greaterDate) {
        [self.fetchQuery whereKey:DDCreatedAtKey
                      greaterThan:greaterDate];
    }
    
    if (lesserDate) {
        [self.fetchQuery whereKey:DDCreatedAtKey
                         lessThan:lesserDate];
    }
    
    self.fetchQuery.limit = fetchLimit;
}

- (void)setAvatarOnCell:(SurpriseTableViewCell *)cell
            atIndexPath:(NSIndexPath *)indexPath
             withStatus:(StatusObject *)status
{
    cell.statusCellAvatarImageView.image =
    status.anonymous.boolValue ? 
    defaultAvatar :
    [Helper getLocalAvatarForUser:status.posterUsername
                        isHighRes:NO];
    
    if (!status.anonymous.boolValue && self.tableView.isDecelerating == NO && self.tableView.isDragging == NO) {
        PFQuery *query = [Helper getServerAvatarForUser:status.posterUsername
                                              isHighRes:NO
                                             completion:^(NSError *error, UIImage *image) {
                                                 cell.statusCellAvatarImageView.image = image;
                                             }];
        
        if (query) {
            [self.avatarQueries setObject:query forKey:indexPath];
        }
    }
}

#pragma mark - UITableViewDelete

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    
    return self.dataSource.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    StatusObject *status = self.dataSource[indexPath.row];
    
    __block SurpriseTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    
    // Configure the cell...
    cell.delegate = self;
    
    //message
    cell.statusCellMessageLabel.text = status.message;
    
    //username
    if (status.anonymous.boolValue) {
        cell.statusCellUsernameLabel.text = @"Anonymous";
    }else{
        cell.statusCellUsernameLabel.text = [NSString stringWithFormat:@"%@ %@",status.posterFirstName,status.posterLastName];
    }
    
    // Cell date
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"HH:mm MM/dd/yy"];
    NSString *str = [formatter stringFromDate:status.createdAt];
    cell.statusCellDateLabel.text = str;
    
    // Comment count
    cell.commentCountLabel.text = status.commentCount.stringValue;
    
    // Flag button
    cell.flagButton.enabled = !status.isBadContent.boolValue;
    
    // Avatar
    [self setAvatarOnCell:cell atIndexPath:indexPath withStatus:status];
    
    // Collection view
    if (status.photoCount.intValue>0){
        
        cell.collectionView.hidden = NO;
        
        // Clear out old photos
        if (self.surpriseImagesArrayByIndexPath[[self keyForIndexPath:indexPath]]) {
            [self.surpriseImagesArrayByIndexPath removeObjectForKey:[self keyForIndexPath:indexPath]];
        }
        [cell.collectionView reloadData];
        
        NSMutableArray *postImages = [Helper fetchLocalPostImagesWithGenericPhotoID:status.photoID totalCount:status.photoCount.intValue isHighRes:NO];
        
        if (postImages.count == status.photoCount.intValue) {
            self.surpriseImagesArrayByIndexPath[[self keyForIndexPath:indexPath]] = postImages;
            [cell.collectionView reloadData];
        }else{
            
            if (tableView.isDecelerating == NO && tableView.isDragging == NO){
                PFQuery *query = [self getServerPostImageForCellAtIndexpath:indexPath];
                [self.postImageQueries setObject:query forKey:indexPath];
            }
        }
    } else {
        cell.collectionView.hidden = YES;
    }
    
    return cell;
}

-(CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath{
    StatusObject *status = self.dataSource[indexPath.row];
    //status.statusCellHeight defaults to 0, so cant check nil
    
    if (status.statusCellHeight.floatValue != 0) {
        return status.statusCellHeight.floatValue;
    }else{
        return 200;
    }
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    
    if(!self.dataSource || self.dataSource.count == 0){
        
        return BACKGROUND_CELL_HEIGHT;
    }else{
        StatusObject *status = self.dataSource[indexPath.row];
        
        //is cell height has been calculated, return it
        if (status.statusCellHeight.floatValue != 0 ) {
            
            return status.statusCellHeight.floatValue;
            
        }else{
            
            //determine height of label(message must exist)
            CGRect rect = [status.message boundingRectWithSize:CGSizeMake(190, MAXFLOAT)
                                                       options:NSStringDrawingUsesLineFragmentOrigin
                                                    attributes:@{NSFontAttributeName:[UIFont fontWithName:@"Helvetica Light" size:14]}
                                                       context:nil];
            float labelHeight = rect.size.height;
            
            //determine if there is a picture
            float pictureHeight = 0;;
            NSNumber *photoCount = status.photoCount;
            if (photoCount.intValue==0) {
                pictureHeight = 0;
            }else{
                //204 height of picture image view
                pictureHeight = [ImageCollectionViewCell imageViewHeight];
            }
            
            float cellHeight = ORIGIN_Y_CELL_MESSAGE_LABEL + labelHeight + pictureHeight + 40 + 10;//40: 10pixels btw image and flag button and 30 is the flag button height
            
            status.statusCellHeight = [NSNumber numberWithFloat:cellHeight];
            return cellHeight;
        }
    }
}

-(void)loadRemoteDataForVisibleCells{
    for (SurpriseTableViewCell *cell in self.tableView.visibleCells) {
        NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
        StatusObject *status = self.dataSource[indexPath.row];
        
        [self setAvatarOnCell:cell atIndexPath:indexPath withStatus:status];
        
        //get post image
        if(status.photoCount.intValue>0){
            
            NSMutableArray *postImages = [Helper fetchLocalPostImagesWithGenericPhotoID:status.photoID totalCount:status.photoCount.intValue isHighRes:NO];
            if (postImages.count == status.photoCount.intValue) {
                self.surpriseImagesArrayByIndexPath[[self keyForIndexPath:indexPath]] = postImages;
                [cell.collectionView reloadData];
            }else{
                //get post images
                PFQuery *query2 = [self getServerPostImageForCellAtIndexpath:indexPath];
                [self.postImageQueries setObject:query2 forKey:indexPath];
            }
        }
    }
}

-(PFQuery *)getServerPostImageForCellAtIndexpath:(NSIndexPath *)indexPath{
    
    __block SurpriseTableViewCell *cell = (SurpriseTableViewCell *)[self.tableView cellForRowAtIndexPath:indexPath];
    __block StatusObject *status = self.dataSource[indexPath.row];
    
    PFQuery *query = [[PFQuery alloc] initWithClassName:@"Photo"];
    [query whereKey:@"photoID" equalTo:status.photoID];
    [query whereKey:@"isHighRes" equalTo:@NO];
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if (!error && objects.count!=0) {
            if (cell==nil) {
                cell = (SurpriseTableViewCell *)[self.tableView cellForRowAtIndexPath:indexPath];
            }
            
            __block int index = status.photoCount.intValue-1;
            
            for (PFObject *photoObject in objects) {
                PFFile *image = photoObject[@"image"];
                [image getDataInBackgroundWithBlock:^(NSData *data, NSError *error) {
                    if (!error) {
                        
                        UIImage *image = [UIImage imageWithData:data];
                        NSString *name = [NSString stringWithFormat:@"%@%d",status.photoID,index];
                        [Helper saveImageToLocal:UIImagePNGRepresentation(image) forImageName:name isHighRes:NO];
                        index--;
                        
                        if (!self.surpriseImagesArrayByIndexPath[[self keyForIndexPath:indexPath]]) {
                            NSMutableArray *imagesArray = [NSMutableArray array];
                            self.surpriseImagesArrayByIndexPath[[self keyForIndexPath:indexPath]] = imagesArray;
                        }
                        
                        NSMutableArray *imagesArray = self.surpriseImagesArrayByIndexPath[[self keyForIndexPath:indexPath]];
                        [imagesArray addObject:image];
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [cell.collectionView reloadData];
                        });
                        
                    }
                }];
            }
        }
    }];
    
    return query;
}

-(void)cancelNetworkRequestForCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath{
    PFQuery *avatarQ = [self.avatarQueries objectForKey:indexPath];
    PFQuery *postimageQ = [self.postImageQueries objectForKey:indexPath];
    if (avatarQ) {
        [avatarQ cancel];
        [self.avatarQueries removeObjectForKey:indexPath];
    }
    if (postimageQ) {
        [postimageQ cancel];
        [self.postImageQueries removeObjectForKey:indexPath];
    }
}

#pragma mark - SurpriseTableViewCellDelegate

-(void)commentButtonTappedOnCell:(SurpriseTableViewCell *)cell{
    [[GAnalyticsManager shareManager] trackUIAction:@"buttonPress" label:@"to comment view" value:nil];
    [Flurry logEvent:@"Comment button tapped"];
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    selectedPath = indexPath;
    [self performSegueWithIdentifier:@"toCommentView" sender:cell];
}

- (void)flagBadContentButtonTappedOnCell:(SurpriseTableViewCell *)cell{
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    __block StatusObject *statusObject = self.dataSource[indexPath.row];
    
    [self flagObjectForId:statusObject.objectId parseClassName:DDStatusParseClassName completion:^(BOOL succeeded, NSError *error) {
        if (succeeded) {
            statusObject.isBadContent = @YES;
            [self.dataSource removeObject:statusObject];
            [[SharedDataManager sharedInstance] saveContext];
            cell.flagButton.enabled = NO;
            [self.tableView reloadData];
        }
    }];
}

- (NSInteger)surpriseCell:(SurpriseTableViewCell *)cell collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    NSArray *images = self.surpriseImagesArrayByIndexPath[[self keyForIndexPath:indexPath]];
    return images.count;
}

- (ImageCollectionViewCell *)surpriseCell:(SurpriseTableViewCell *)cell collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    ImageCollectionViewCell *collectionViewCell = (ImageCollectionViewCell *)[collectionView dequeueReusableCellWithReuseIdentifier:@"cell" forIndexPath:indexPath];
    // Clear out old image first
    collectionViewCell.imageView.image = nil;
    
    NSIndexPath *cellIndexPath = [self.tableView indexPathForCell:cell];
    NSArray *images = self.surpriseImagesArrayByIndexPath[[self keyForIndexPath:cellIndexPath]];
    collectionViewCell.imageView.image = images[indexPath.row];
    
    return collectionViewCell;
}

- (CGSize)surpriseCell:(SurpriseTableViewCell *)cell collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSIndexPath *cellIndexPath = [self.tableView indexPathForCell:cell];
    NSArray *images = self.surpriseImagesArrayByIndexPath[[self keyForIndexPath:cellIndexPath]];
    if (indexPath.row < images.count) {
        UIImage *image = images[indexPath.row];
        CGFloat width = image.size.width < image.size.height ? [ImageCollectionViewCell imageViewHeight] / image.size.height * image.size.width : [ImageCollectionViewCell imageViewWidth];
        return CGSizeMake(width, [ImageCollectionViewCell imageViewHeight]);
    } else {
        return CGSizeZero;
    }
}

#pragma mark - UISegue

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender{
    if ([segue.identifier isEqualToString:@"toCommentView"]){
        CommentVC *vc = (CommentVC *)segue.destinationViewController;
        __block StatusObject *status = self.dataSource[selectedPath.row];
        vc.statusObjectId = status.objectId;
        __weak SurpriseVC *weakSelf= self;
        [vc updateCommentCountWithBlock:^{
            status.commentCount = [NSNumber numberWithInt:status.commentCount.intValue+1];
            [weakSelf.tableView reloadRowsAtIndexPaths:@[selectedPath] withRowAnimation:UITableViewRowAnimationNone];
        }];
        // This is a hack. need to do it the right way which consumes lots of time. so hold
        self.tabBarController.tabBar.hidden = YES;
    }
}

@end