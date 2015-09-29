//
//  StatusTableCell.m
//  FastPost
//
//  Created by Huang, Sihang on 11/25/13.
//  Copyright (c) 2013 Huang, Sihang. All rights reserved.
//

#import <Parse/Parse.h>
#import "SurpriseTableViewCell.h"
#import "ImageCollectionViewCell.h"
#import "Helper.h"
#import "PFFile+Utilities.h"

#define REVIVE_PROGRESS_VIEW_INIT_ALPHA .7f
#define PROGRESSION_RATE 1
#define TRESHOLD 60.0f

static CGFloat const kCollectionCellWidth = 84.0f;
static CGFloat const kCollectionCellHeight = 84.0f;

typedef NS_ENUM(NSInteger, DataSourceType) {
    DataSourceTypeFile,
    DataSourceTypeImage
};

@interface SurpriseTableViewCell() <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>{

}

@property (nonatomic, strong) NSArray *dataSource;
@property (nonatomic, assign) DataSourceType dataSourceType;

@end

@implementation SurpriseTableViewCell

+ (CGFloat)imageViewWidth
{
    return kCollectionCellWidth;
}

+ (CGFloat)imageViewHeight
{
    return kCollectionCellHeight;
}

- (void)awakeFromNib
{
    self.collectionView.dataSource  = self;
    self.collectionView.delegate = self;
    self.collectionView.scrollsToTop = NO;
    self.statusCellAvatarImageView.layer.masksToBounds = YES;
    self.statusCellAvatarImageView.layer.cornerRadius = 30;
    
    if (self.dataSource && self.dataSource.count > 0) {
        [self.collectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]
                                    atScrollPosition:UICollectionViewScrollPositionNone
                                            animated:NO];
    }
}

- (IBAction)flagBadContentButtonTapped:(id)sender {
    [self.delegate flagBadContentButtonTappedOnCell:self];
}

- (IBAction)commentButtonTapped:(id)sender {
    [self.delegate commentButtonTappedOnCell:self];
}

- (void)setDataSourceWithFiles:(NSArray *)filesArray
{
    if (_dataSource != filesArray) {
        _dataSource = filesArray;
        _dataSourceType = DataSourceTypeFile;
        [_collectionView reloadData];
    }
}

- (void)setDataSourceWithImages:(NSArray *)imagesArray
{
    if (_dataSource != imagesArray) {
        _dataSource = imagesArray;
        _dataSourceType = DataSourceTypeImage;
        [_collectionView reloadData];
    }
}

- (UIImage *)imageForCellAtIndexPath:(NSIndexPath *)indexPath
{
    if (_dataSourceType == DataSourceTypeFile) {
        PFFile *file = _dataSource[indexPath.row];
        
        if (file.isDataAvailable) {

            dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
                //Background Thread
                NSData *data = file.getData;
                NSLog(@"save 1");
                [Helper saveImageToLocal:data
                            forImageName:FSTRING(@"%@%d", self.statusPhotoId, (int)indexPath.row)
                               isHighRes:NO];
                dispatch_async(dispatch_get_main_queue(), ^(void){
                    //Run UI Updates
                    [self.collectionView reloadItemsAtIndexPaths:@[indexPath]];
                });
            });
            
            return nil;
        } else {
            
            [file fetchImageWithCompletionBlock:^(BOOL completed, NSData *data) {
                if (completed) {
                    NSLog(@"save 2");
                    [Helper saveImageToLocal:data
                                forImageName:FSTRING(@"%@%d", self.statusPhotoId, (int)indexPath.row)
                                   isHighRes:NO];
                    [self.collectionView reloadItemsAtIndexPaths:@[indexPath]];
                }
            }];
            
            return nil;
        }
    } else if (_dataSourceType == DataSourceTypeImage) {
        
        return _dataSource[indexPath.row];
    }
    
    return nil;
}

- (void)clearDataSource
{
    self.dataSource = nil;
    [self.collectionView reloadData];
}

#pragma mark - uicollectionview delegate

-(NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section{
    
    if (!self.dataSource || self.dataSource.count == 0) {
        return self.dummyDataCount;
    }
    
    return self.dataSource.count;
}

-(ImageCollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    ImageCollectionViewCell *collectionViewCell = (ImageCollectionViewCell *)[collectionView dequeueReusableCellWithReuseIdentifier:@"cell" forIndexPath:indexPath];
    
    // Clear out old image first
    
    if (self.dataSource && self.dataSource.count > 0) {
        collectionViewCell.imageView.image = [self imageForCellAtIndexPath:indexPath];
    } else {
        collectionViewCell.imageView.image = nil;
    }
    
    return collectionViewCell;
}

#pragma mark - uicollectionview flow layout delegate

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout *)collectionViewLayout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
//    if (!self.dataSource || self.dataSource.count == 0) {
    
        return CGSizeMake([ImageCollectionViewCell imageViewWidth], [ImageCollectionViewCell imageViewHeight]);
//    }
//    
//    UIImage *image = [self imageForCellAtIndexPath:indexPath];
//    CGFloat width = image.size.width < image.size.height ?
//    [ImageCollectionViewCell imageViewHeight] / image.size.height * image.size.width :
//    [ImageCollectionViewCell imageViewWidth];
//    
//    return CGSizeMake(width, [ImageCollectionViewCell imageViewHeight]);
}

@end
