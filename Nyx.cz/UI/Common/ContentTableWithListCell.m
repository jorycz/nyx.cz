//
//  ContentTableWithListCell.m
//  Nyx.cz
//
//  Created by Josef Rysanek on 25/11/2017.
//  Copyright © 2017 Josef Rysanek. All rights reserved.
//

#import "ContentTableWithListCell.h"
#import "Colors.h"
#import <QuartzCore/QuartzCore.h>


@implementation ContentTableWithListCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])
    {
        self.backgroundColor = [UIColor themeColorMainBackgroundDefault];
        
        _unreadLabel = [[UnreadLabel alloc] init];
        [self addSubview:_unreadLabel];
        
        _boardNameLabel = [[UILabel alloc] init];
        _boardNameLabel.backgroundColor = [UIColor themeColorMainBackgroundDefault];
        _boardNameLabel.userInteractionEnabled = NO;
        _boardNameLabel.textAlignment = NSTextAlignmentLeft;
        _boardNameLabel.font = [UIFont systemFontOfSize:12];
        _boardNameLabel.textColor = [UIColor themeColorStandardText];
        [self addSubview:_boardNameLabel];
        
        _separator = [[UIView alloc] init];
        _sepColor = [UIColor colorWithWhite:.6 alpha:.1];
        _separator.backgroundColor = _sepColor;
        [self addSubview:_separator];
    }
    return self;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];
    // Preserver background colors.
    _unreadLabel.backgroundColor = [UIColor themeColorMainBackgroundStyledElement];
    _separator.backgroundColor = _sepColor;
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated
{
    [super setHighlighted:highlighted animated:animated];
    // Preserver background colors.
    _unreadLabel.backgroundColor = [UIColor themeColorMainBackgroundStyledElement];
    _separator.backgroundColor = _sepColor;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGRect f = self.frame;
    
    _unreadLabel.frame = CGRectMake(3, 2, 29, f.size.height - 5);
    
    _boardNameLabel.frame = CGRectMake(36, 1, f.size.width - 36, f.size.height - 4);
    
    _separator.frame = CGRectMake(15, f.size.height - 1, f.size.width - 30, 1);
}

- (void)configureCellForIndexPath:(NSIndexPath *)idxPath
{
    _unreadLabel.alpha = 1;
    NSInteger unread = [self.unreadCount integerValue];
    if (unread > 999) {
        _unreadLabel.text = @"1K+";
    } else {
        _unreadLabel.text = self.unreadCount;
    }
    if (unread < 1)
        _unreadLabel.alpha = .2;
    _boardNameLabel.text = self.boardName;
    self.backgroundColor = [UIColor themeColorMainBackgroundDefault];
}


@end
