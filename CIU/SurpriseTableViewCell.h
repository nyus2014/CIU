//
//  StatusTableCell.h
//  FastPost
//
//  Created by Huang, Sihang on 11/25/13.
//  Copyright (c) 2013 Huang, Sihang. All rights reserved.
//

#import <UIKit/UIKit.h>

@class SurpriseTableViewCell;
@class Status;
@class SpinnerImageView;
@class ImageCollectionViewCell;
@class PFFile;

@protocol StatusTableViewCellDelegate <NSObject>

@optional
- (void)usernameLabelTappedOnCell:(SurpriseTableViewCell *)cell;
- (void)flagBadContentButtonTappedOnCell:(SurpriseTableViewCell *)cell;
- (void)commentButtonTappedOnCell:(SurpriseTableViewCell *)cell;
- (void)reviveAnimationDidEndOnCell:(SurpriseTableViewCell *)cell withProgress:(float)percentage;
- (void)swipeGestureRecognizedOnCell:(SurpriseTableViewCell *)cell;
- (NSInteger)surpriseCell:(SurpriseTableViewCell *)cell collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section;
- (ImageCollectionViewCell *)surpriseCell:(SurpriseTableViewCell *)cell collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath;
- (CGSize)surpriseCell:(SurpriseTableViewCell *)cell collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath;

@end

@interface SurpriseTableViewCell : UITableViewCell

@property (strong,nonatomic) Status *status;
@property (assign, nonatomic) id<StatusTableViewCellDelegate>delegate;
@property (weak, nonatomic) IBOutlet UILabel *statusCellMessageLabel;
@property (weak, nonatomic) IBOutlet UILabel *statusCellUsernameLabel;
@property (weak, nonatomic) IBOutlet UILabel *statusCellDateLabel;
@property (weak, nonatomic) IBOutlet UIImageView *statusCellAvatarImageView;
@property (weak, nonatomic) IBOutlet UILabel *reviveCountLabel;
@property (weak, nonatomic) IBOutlet UILabel *commentCountLabel;
@property (weak, nonatomic) IBOutlet UIButton *commentButton;
@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;
@property (weak, nonatomic) IBOutlet UIView *contentContainerView;
@property (weak, nonatomic) IBOutlet UIButton *flagButton;
@property (weak, nonatomic) IBOutlet UIImageView *imageView;


@property (nonatomic, copy) NSArray *imagesArray;
@property (nonatomic, copy) NSArray *filesArray;
@property (nonatomic, copy) NSString *statusPhotoId;
@property (nonatomic) NSInteger dummyDataCount;

+ (CGFloat)imageViewWidth;
+ (CGFloat)imageViewHeight;

- (IBAction)flagBadContentButtonTapped:(id)sender;
- (IBAction)commentButtonTapped:(id)sender;
- (void)cancelDownloadImages;
- (void)setDataSourceWithFiles:(NSArray *)filesArray;
- (void)setDataSourceWithImages:(NSArray *)imagesArray;
- (void)clearDataSource;

@end
