//
//  JWMainTableViewCell.h
//  BusRider
//
//  Created by John Wong on 1/11/15.
//  Copyright (c) 2015 John Wong. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface JWMainTableViewCell : UITableViewCell

@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UILabel *subTitle;
@property (weak, nonatomic) IBOutlet UILabel *stopLabel;

@end
