//
//  JWMainViewController.m
//  BusRider
//
//  Created by John Wong on 12/15/14.
//  Copyright (c) 2014 John Wong. All rights reserved.
//

#import "JWMainViewController.h"
#import "JWSearchRequest.h"
#import "JWBusLineItem.h"
#import "JWBusLineViewController.h"
#import "JWViewUtil.h"
#import "JWSearchListItem.h"
#import "JWSearchLineItem.h"
#import "JWSearchStopItem.h"
#import "JWSearchTableViewCell.h"
#import "JWUserDefaultsUtil.h"
#import "SVPullToRefresh.h"
#import "UINavigationController+SGProgress.h"
#import "JWMainTableViewCell.h"
#import "JWStopTableViewController.h"
#import "JWBusInfoItem.h"
#import "JWNavigationCenterView.h"
#import "JWCityRequest.h"
#import "JWCityItem.h"
#import "AHKActionSheet.h"

#define JWCellIdMain                @"JWCellIdMain"
#define JWCellIdSearch              @"JWCellIdSearch"

typedef NS_ENUM(NSInteger, JWSearchResultType) {
    JWSearchResultTypeNone = 0,
    JWSearchResultTypeList = 1,
    JWSearchResultTypeSingle = 2
};

@interface JWMainViewController () <UISearchBarDelegate, UITableViewDataSource, JWNavigationCenterDelegate>

@property (nonatomic, strong) JWSearchRequest *searchRequest;
@property (nonatomic, strong) JWSearchListItem *searchListItem;
/**
 *  array of JWSearchLineItem
 */
@property (nonatomic, strong) NSArray *collectLineItem;

@property (strong, nonatomic) IBOutlet UISearchDisplayController *searchController;

/**
 *  Pass to JWBusLineViewController
 */
@property (nonatomic, strong) JWBusLineItem *busLineItem;
/**
 *  Pass to JWBusLineViewController
 */
@property (nonatomic, strong) JWBusInfoItem *busInfoItem;
/**
 *  Pass to JWStopViewController
 */
@property (nonatomic, strong) JWSearchStopItem *selectedStop;
@property (nonatomic, strong) JWNavigationCenterView *cityButtonItem;
@property (nonatomic, strong) JWCityRequest *cityRequest;

@end

@implementation JWMainViewController

#pragma mark lifecycle
- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:self.cityButtonItem];
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:nil action:nil];
    [self.searchController.searchResultsTableView registerNib:[UINib nibWithNibName:@"JWSearchTableViewCell" bundle:[NSBundle mainBundle]] forCellReuseIdentifier:JWCellIdSearch];
    [self.tableView registerNib:[UINib nibWithNibName:@"JWMainTableViewCell" bundle:[NSBundle mainBundle]] forCellReuseIdentifier:JWCellIdMain];
    self.tableView.tableFooterView = [[UIView alloc] init];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self loadData];
    __weak typeof(self) weakSelf = self;
    [self.tableView addPullToRefreshWithActionHandler:^{
        [weakSelf loadData];
        [weakSelf.tableView.pullToRefreshView stopAnimating];
    }];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:JWSeguePushLineWithData]) {
        if ([segue.destinationViewController isKindOfClass:[JWBusLineViewController class]]) {
            JWBusLineViewController *busLineViewController = (JWBusLineViewController *)segue.destinationViewController;
            busLineViewController.busLineItem = self.busLineItem;
            busLineViewController.busInfoItem = self.busInfoItem;
        }
    } else if ([segue.identifier isEqualToString:JWSeguePushLineWithId]) {
        if ([segue.destinationViewController isKindOfClass:[JWBusLineViewController class]]) {
            JWBusLineViewController *busLineViewController = (JWBusLineViewController *)segue.destinationViewController;
            busLineViewController.lineId = self.selectedLineId;
        }
    } else if ([segue.identifier isEqualToString:JWSeguePushStopList]) {
        if ([segue.destinationViewController isKindOfClass:[JWStopTableViewController class]]) {
            JWStopTableViewController *stopTableViewController = (JWStopTableViewController *)segue.destinationViewController;
            stopTableViewController.stopItem = self.selectedStop;
        }
    }
}

#pragma mark UITableViewDataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (tableView == self.tableView) {
        return self.collectLineItem ? self.collectLineItem.count : 0;
    } else {
        if (self.searchListItem) {
            if (section == 0 && self.searchListItem.lineList.count > 0) {
                return self.searchListItem.lineList.count;
            } else {
                return self.searchListItem.stopList.count;
            }
        } else {
            return 0;
        }
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (tableView == self.tableView) {
        return 1;
    } else {
        if (self.searchListItem) {
            return (self.searchListItem.lineList.count == 0 ? 0 : 1) + (self.searchListItem.stopList.count == 0 ? 0 : 1);
        } else {
            return 0;
        }
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView == self.tableView) {
        JWMainTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:JWCellIdMain forIndexPath:indexPath];
        JWCollectItem *item = self.collectLineItem[indexPath.row];
        cell.titleLabel.text = item.lineNumber;
        cell.subTitle.text = [NSString stringWithFormat:@"%@-%@", item.from, item.to];
        return cell;
    } else {
        JWSearchTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:JWCellIdSearch forIndexPath:indexPath];
        if (indexPath.section == 0 && self.searchListItem.lineList.count > 0) {
            JWSearchLineItem *lineItem = self.searchListItem.lineList[indexPath.row];
            cell.titleLabel.text = lineItem.lineNumber;
        } else {
            JWSearchStopItem *stopItem = self.searchListItem.stopList[indexPath.row];
            cell.titleLabel.text = stopItem.stopName;
        }
        return cell;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (tableView == self.tableView) {
        
    } else {
        if (section == 0 && self.searchListItem.lineList.count > 0) {
            return @"公交路线";
        } else {
            return @"公交站点";
        }
    }
    return nil;
}

#pragma mark UITableViewDelegate
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView == self.tableView) {
        return 54;
    } else {
        return 44;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView == self.tableView) {
        JWCollectItem *item = self.collectLineItem[indexPath.row];
        self.selectedLineId = item.lineId;
        [self performSegueWithIdentifier:JWSeguePushLineWithId sender:self];
    } else {
        if (indexPath.section == 0 && self.searchListItem.lineList.count > 0) {
            JWSearchLineItem *lineItem = self.searchListItem.lineList[indexPath.row];
            self.selectedLineId = lineItem.lineId;
            [self performSegueWithIdentifier:JWSeguePushLineWithId sender:self];
        } else {
            self.selectedStop = self.searchListItem.stopList[indexPath.row];
            [self performSegueWithIdentifier:JWSeguePushStopList sender:self];
        }
    }
}

#pragma mark JWNavigationCenterDelegate
- (void)buttonItem:(JWNavigationCenterView *)buttonItem setOn:(BOOL)isOn {
    if (isOn) {
        [self showCityList];
    }
}

#pragma mark UISearchBarDelegate
- (BOOL)searchBarShouldBeginEditing:(UISearchBar *)searchBar {
    JWCityItem *cityItem = [JWUserDefaultsUtil cityItem];
    if (cityItem) {
        return YES;
    } else {
        [self showCityList];
        return NO;
    }
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    NSString *searchText = searchBar.text;
    if (searchText && searchText.length > 0) {
        [self loadRequestWithKeyword:searchText showHUD:YES];
    }
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if (searchText && searchText.length > 0) {
        [self loadRequestWithKeyword:searchText showHUD:NO];
    }
}

#pragma mark getter
- (JWSearchRequest *)searchRequest {
    if (!_searchRequest) {
        _searchRequest = [[JWSearchRequest alloc] init];
    }
    return _searchRequest;
}

- (JWCityRequest *)cityRequest {
    if (!_cityRequest) {
        _cityRequest = [[JWCityRequest alloc] init];
    }
    return _cityRequest;
}

- (NSArray *)collectLineItem {
    if (!_collectLineItem) {
        _collectLineItem = [[[JWUserDefaultsUtil allCollectItems] reverseObjectEnumerator] allObjects];
    }
    return _collectLineItem;
}

- (JWNavigationCenterView *)cityButtonItem {
    if (!_cityButtonItem) {
        JWCityItem *cityItem = [JWUserDefaultsUtil cityItem];
        _cityButtonItem = [[JWNavigationCenterView alloc] initWithTitle:cityItem ? cityItem.cityName : @"城市"];
        _cityButtonItem.delegate = self;
    }
    return _cityButtonItem;
}

#pragma mark action
- (void)loadData {
    _collectLineItem = nil;
    [self.tableView reloadData];
}

- (void)showCityList {
    __weak typeof(self) weakSelf = self;
    [self.cityRequest loadWithCompletion:^(NSDictionary *dict, NSError *error) {
        if (!error) {
            NSArray *array = [JWCityItem arrayFromDictionary:dict];
            AHKActionSheet *actionSheet = [[AHKActionSheet alloc] initWithTitle:@"选择站点"];
            actionSheet.cancelButtonTitle = @"取消";
            actionSheet.buttonHeight = 44;
            actionSheet.cancelHandler = ^(AHKActionSheet *actionSheet) {
                [weakSelf.cityButtonItem setOn:NO];
            };
            for (JWCityItem *cityItem in array) {
                [actionSheet addButtonWithTitle:cityItem.cityName image:[UIImage imageNamed:@"JWIconCity"] type:AHKActionSheetButtonTypeDefault handler:^(AHKActionSheet *actionSheet) {
                    [weakSelf.cityButtonItem setOn:NO];
                    [weakSelf.cityButtonItem setTitle:cityItem.cityName];
                    [JWUserDefaultsUtil setCityItem:cityItem];
                    [weakSelf loadData];
                }];
            }
            [actionSheet show];
        }
    }];
}

- (void)loadRequestWithKeyword:(NSString *)keyword showHUD:(BOOL)isShowHUD{
    if (isShowHUD) {
        [JWViewUtil showProgress];
    }
    
    self.searchRequest.keyWord = keyword;
    __weak typeof(self) weakSelf = self;
    [self.searchRequest loadWithCompletion:^(NSDictionary *dict, NSError *error) {
        if (isShowHUD) {
            if (error) {
                [JWViewUtil showError:error];
            } else {
                [JWViewUtil hideProgress];
            }
        }
        if (error) {
            weakSelf.searchListItem = nil;
            [weakSelf.searchController.searchResultsTableView reloadData];
            return;
        }
        NSInteger result = [dict[@"result"] integerValue];
        if (result == JWSearchResultTypeNone) {
            weakSelf.searchListItem = nil;
            [weakSelf.searchController.searchResultsTableView reloadData];
        } else if (result == JWSearchResultTypeList) {
            // list result
            weakSelf.searchListItem = [[JWSearchListItem alloc] initWithDictionary:dict];
            [weakSelf.searchController.searchResultsTableView reloadData];
        } else if (result == JWSearchResultTypeSingle) {
            // single result
            JWBusLineItem *busLineItem = [[JWBusLineItem alloc] initWithDictionary:dict];
            weakSelf.busLineItem = busLineItem;
            
            JWCollectItem *collectItem = [JWUserDefaultsUtil collectItemForLineId:busLineItem.lineItem.lineId];
            if (collectItem && collectItem.stopId && collectItem.stopName) {
                JWStopItem *stopItem = [[JWStopItem alloc] initWithStopId:collectItem.stopId stopName:collectItem.stopName];
                weakSelf.busInfoItem = [[JWBusInfoItem alloc] initWithUserStop:stopItem.stopId busInfo:dict];
            } else {
                weakSelf.busInfoItem = nil;
            }
            [weakSelf performSegueWithIdentifier:JWSeguePushLineWithData sender:weakSelf];
        }
    }];
}

@end
