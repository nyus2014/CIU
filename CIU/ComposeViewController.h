//
//  ComposeViewController.h
//  CIU
//
//  Created by Huang, Jason on 9/15/14.
//  Copyright (c) 2014 Huang, Jason. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ComposeViewController : UIViewController
@property (weak, nonatomic) IBOutlet UITextView *textView;
@property (strong, nonatomic) NSString *categoryName;
@end