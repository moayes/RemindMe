//
//  RWTableViewController.m
//  UDo
//
//  Created by Soheil Azarpour on 12/21/13.
//  Copyright (c) 2013 Ray Wenderlich. All rights reserved.
//

#import "RWTableViewController.h"
#import "UIAlertView+RWBlock.h"
#import "UIButton+RWBlock.h"
@import EventKit;

@interface RWTableViewController ()

/** @brief An array of NSString objects, data source of the table view. */
@property (strong, nonatomic) NSMutableArray *todoItems;

/** @brief A representative of Calendar database. */
@property (strong, nonatomic) EKEventStore *eventStore;

/** @brief A boolean indicating whether app has access to event store. */
@property (nonatomic) BOOL isAccessToEventStoreGranted;

@end

@implementation RWTableViewController

#pragma mark - Custom accessors

- (EKEventStore *)eventStore {
  if (!_eventStore) {
    _eventStore = [EKEventStore new];
  }
  return _eventStore;
}

- (NSMutableArray *)todoItems {
  if (!_todoItems) {
    _todoItems = [@[@"Get Milk!", @"Go to gym", @"Breakfast with Rita!", @"Call Bob", @"Pick up newspaper", @"Send an email to Joe", @"Read this tutorial!", @"Pick up flowers"] mutableCopy];
  }
  return _todoItems;
}

#pragma mark - View life cycle

- (void)viewDidLoad {
  self.title = @"To Do!";
  
  UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressGestureRecognized:)];
  [self.tableView addGestureRecognizer:longPress];
  
  // Call a helper method to update authorization status.
  [self updateAuthorizationStatusToAccessEventStore];
  
  [super viewDidLoad];
}

#pragma mark - UITableView data source and delegate methods

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  return [self.todoItems count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  static NSString *kIdentifier = @"Cell Identifier";
  
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kIdentifier forIndexPath:indexPath];
  
  // Update cell content from data source.
  NSString *object = self.todoItems[indexPath.row];
  cell.backgroundColor = [UIColor whiteColor];
  cell.textLabel.text = object;
  
  // Add a button as accessory view that says 'Add Reminder'.
  UIButton *addReminderButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
  addReminderButton.frame = CGRectMake(0.0, 0.0, 100.0, 30.0);
  [addReminderButton setTitle:@"Add Reminder" forState:UIControlStateNormal];
  
  __weak RWTableViewController *weakSelf = self;
  [addReminderButton addActionblock:^(UIButton *sender) {
    
    // Add a reminder for to do item.
    [weakSelf addReminderForToDoItem:object];
    
  } forControlEvents:UIControlEventTouchUpInside];
  
  cell.accessoryView = addReminderButton;
  
  return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
  return YES;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
  return UITableViewCellEditingStyleDelete;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
  
  NSString *todoItem = self.todoItems[indexPath.row];
  
  // Remove to-do item.
  [self.todoItems removeObject:todoItem];
  
  // Remove the associated reminder item (if it has one).
  [self deleteReminderForToDoItem:todoItem];
  
  [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
}

#pragma mark - IBActions

- (IBAction)addButtonPressed:(id)sender {
  
  // Display an alert view with a text input.
  UIAlertView *inputAlertView = [[UIAlertView alloc] initWithTitle:@"Add a new to-do item:" message:nil delegate:nil cancelButtonTitle:@"Dismiss" otherButtonTitles:@"Add", nil];
  
  inputAlertView.alertViewStyle = UIAlertViewStylePlainTextInput;
  
  __weak RWTableViewController *weakSelf = self;
  
  // Add a completion block (using our category to UIAlertView).
  [inputAlertView setCompletionBlock:^(UIAlertView *alertView, NSInteger buttonIndex) {
    
    // If user pressed 'Add'...
    if (buttonIndex == 1) {
      
      UITextField *textField = [alertView textFieldAtIndex:0];
      NSString *string = [textField.text capitalizedString];
      [weakSelf.todoItems addObject:string];
      
      NSUInteger row = [weakSelf.todoItems count] - 1;
      NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:0];
      [weakSelf.tableView insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
  }];
  
  [inputAlertView show];
}

- (IBAction)longPressGestureRecognized:(id)sender {
  
  UILongPressGestureRecognizer *longPress = (UILongPressGestureRecognizer *)sender;
  UIGestureRecognizerState state = longPress.state;
  
  CGPoint location = [longPress locationInView:self.tableView];
  NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:location];
  
  static UIView       *snapshot = nil;        ///< A snapshot of the row user is moving.
  static NSIndexPath  *sourceIndexPath = nil; ///< Initial index path, where gesture begins.
  
  switch (state) {
    case UIGestureRecognizerStateBegan: {
      if (indexPath) {
        sourceIndexPath = indexPath;
        
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
        
        // Take a snapshot of the selected row using helper method.
        snapshot = [self customSnapshoFromView:cell];
        
        // Add the snapshot as subview, centered at cell's center...
        __block CGPoint center = cell.center;
        snapshot.center = center;
        snapshot.alpha = 0.0;
        [self.tableView addSubview:snapshot];
        [UIView animateWithDuration:0.25 animations:^{
          
          // Offset for gesture location.
          center.y = location.y;
          snapshot.center = center;
          snapshot.transform = CGAffineTransformMakeScale(1.05, 1.05);
          snapshot.alpha = 0.98;
          
          // Black out.
          cell.backgroundColor = [UIColor blackColor];
        } completion:nil];
      }
      break;
    }
      
    case UIGestureRecognizerStateChanged: {
      CGPoint center = snapshot.center;
      center.y = location.y;
      snapshot.center = center;
      
      // Is destination valid and is it different from source?
      if (indexPath && ![indexPath isEqual:sourceIndexPath]) {
        
        // ... update data source.
        [self.todoItems exchangeObjectAtIndex:indexPath.row withObjectAtIndex:sourceIndexPath.row];
        
        // ... move the rows.
        [self.tableView moveRowAtIndexPath:sourceIndexPath toIndexPath:indexPath];
        
        // ... and update source so it is in sync with UI changes.
        sourceIndexPath = indexPath;
      }
      break;
    }
      
    default: {
      // Clean up.
      UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:sourceIndexPath];
      [UIView animateWithDuration:0.25 animations:^{
        
        snapshot.center = cell.center;
        snapshot.transform = CGAffineTransformIdentity;
        snapshot.alpha = 0.0;
        
        // Undo the black-out effect we did.
        cell.backgroundColor = [UIColor whiteColor];
        
      } completion:^(BOOL finished) {
        
        [snapshot removeFromSuperview];
        snapshot = nil;
        
      }];
      sourceIndexPath = nil;
      break;
    }
  }
}

#pragma mark - Helper methods

/** @brief Returns a customized snapshot of a given view. */
- (UIView *)customSnapshoFromView:(UIView *)inputView {
  
  UIView *snapshot = [inputView snapshotViewAfterScreenUpdates:YES];
  snapshot.layer.masksToBounds = NO;
  snapshot.layer.cornerRadius = 0.0;
  snapshot.layer.shadowOffset = CGSizeMake(-5.0, 0.0);
  snapshot.layer.shadowRadius = 5.0;
  snapshot.layer.shadowOpacity = 0.4;
  
  return snapshot;
}

/** @brief Update authorization status to access Reminder database. */
- (void)updateAuthorizationStatusToAccessEventStore {
  
  EKAuthorizationStatus authorizationStatus = [EKEventStore authorizationStatusForEntityType:EKEntityTypeReminder];
  
  switch (authorizationStatus) {
      
      // Fall through. If denied or restricted, display and alert that we can't add a reminder.
    case EKAuthorizationStatusDenied:
    case EKAuthorizationStatusRestricted: {
      
      self.isAccessToEventStoreGranted = NO;
      
      UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Access Denied" message:@"This app doesn't have access to your Reminders." delegate:nil cancelButtonTitle:@"Dismiss" otherButtonTitles:nil];
      [alertView show];
      
      [self.tableView reloadData];
      
      break;
    }
      
    case EKAuthorizationStatusAuthorized:
      self.isAccessToEventStoreGranted = YES;
      [self.tableView reloadData];
      break;
      
    case EKAuthorizationStatusNotDetermined: {
      __weak RWTableViewController *weakSelf = self;
      [self.eventStore requestAccessToEntityType:EKEntityTypeReminder completion:^(BOOL granted, NSError *error) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
          weakSelf.isAccessToEventStoreGranted = granted;
          [weakSelf.tableView reloadData];
        });
        
      }];
      break;
    }
  }
}

/** @brief Add a to-do item to user's Reminder database. */
- (void)addReminderForToDoItem:(NSString *)item {
  // TODO: implement this!
}

/** @brief Delete a to-do item from user's Reminder database, if applicable. */
- (void)deleteReminderForToDoItem:(NSString *)item {
  // TODO: implement this!
}

/** @brief Fetch reminder items from user's Reminder database. */
- (void)fetchReminders {
  // TODO: implement this!
}

@end
