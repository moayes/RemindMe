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

/** @brief A reminder list specific to this app. */
@property (strong, nonatomic) EKCalendar *calendar;

/** @brief An array of EKReminder objects fetched from Calendar database. */
@property (copy, nonatomic) NSArray *reminders;

@end

@implementation RWTableViewController

#pragma mark - Custom accessors

// Lazily instantiate (create) a reminder list for this app.
- (EKCalendar *)calendar {
  if (!_calendar) {
    
    // Get all the calendars with Reminder type.
    NSArray *calendars = [self.eventStore calendarsForEntityType:EKEntityTypeReminder];
    
    // Dose have our app's calendar (from previous run).
    NSString *calendarTitle = @"UDo!";
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"title matches %@", calendarTitle];
    NSArray *filtered = [calendars filteredArrayUsingPredicate:predicate];
    
    if ([filtered count]) {
      
      // If more than, assume the 1st one is ours.
      _calendar = [filtered firstObject];
    }
    else {
      
      // Create a reminder list for this app.
      _calendar = [EKCalendar calendarForEntityType:EKEntityTypeReminder eventStore:self.eventStore];
      _calendar.title = @"UDo!";
      _calendar.source = self.eventStore.defaultCalendarForNewReminders.source;
      
      NSError *calendarErr = nil;
      BOOL calendarSuccess = [self.eventStore saveCalendar:_calendar commit:YES error:&calendarErr];
      if (!calendarSuccess) {
        // Handle error
      }
    }
  }
  return _calendar;
}

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

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad {
  self.title = @"To Do!";
  
  UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressGestureRecognized:)];
  [self.tableView addGestureRecognizer:longPress];
  
  // Call a helper method to update authorization status.
  [self updateAuthorizationStatusToAccessEventStore];
  
  // Fetch user's reminders from database.
  [self fetchReminders];
  
  // Register to receive notification about changes in event store.
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(eventStoreDidChangeWithNotification:) name:EKEventStoreChangedNotification object:nil];
  
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
  
  // Add 'Add Reminder' button if app has access to Calendar database
  // and the to-do item is not already added to database.
  NSPredicate *predicate = [NSPredicate predicateWithFormat:@"title matches %@", object];
  NSArray *filtered = [self.reminders filteredArrayUsingPredicate:predicate];
  if (self.isAccessToEventStoreGranted && ![filtered count]) {
    
    // Add a button as accessory view that says 'Add Reminder'.
    UIButton *addReminderButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    addReminderButton.frame = CGRectMake(0.0, 0.0, 100.0, 30.0);
    [addReminderButton setTitle:@"Add Reminder" forState:UIControlStateNormal];
    
    __weak RWTableViewController *weakself = self;
    [addReminderButton addActionblock:^(UIButton *sender) {
      
      // Add a reminder for to do item.
      [weakself addReminderForToDoItem:object];
      
    } forControlEvents:UIControlEventTouchUpInside];
    
    cell.accessoryView = addReminderButton;
  }
  else {
    cell.accessoryView = nil;
  }
  
  return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  
  UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
  
  NSString *toDoItem = self.todoItems[indexPath.row];
  NSPredicate *predicate = [NSPredicate predicateWithFormat:@"title matches %@", toDoItem];
  
  // Assume there are no duplicates...
  NSArray *results = [self.reminders filteredArrayUsingPredicate:predicate];
  EKReminder *reminder = [results firstObject];
  reminder.completed = !reminder.isCompleted;
  cell.imageView.image = (reminder.isCompleted) ? [UIImage imageNamed:@"checkmarkOn"] : [UIImage imageNamed:@"checkmarkOff"];
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
  
  // App doesn't have access.
  if (!self.isAccessToEventStoreGranted)
    return;
  
  // Create a new reminder. At the minimum set its title and calendar property.
  EKReminder *reminder = [EKReminder reminderWithEventStore:self.eventStore];
  reminder.title = item;
  reminder.calendar = self.calendar;
  
  // Save and commit.
  NSError *error = nil;
  BOOL success = [self.eventStore saveReminder:reminder commit:YES error:&error];
  if (!success) {
    // Handle error.
  }
  
  // Give user some feedback!
  NSString *message = (success) ? @"Reminder was successfully added!" : @"Failed to add reminder!";
  UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:nil message:message delegate:nil cancelButtonTitle:nil otherButtonTitles:@"Dismiss", nil];
  [alertView show];
}

/** @brief Delete a to-do item from user's Reminder database, if applicable. */
- (void)deleteReminderForToDoItem:(NSString *)item {
  // Find the matching EKReminder(s).
  NSPredicate *predicate = [NSPredicate predicateWithFormat:@"title matches %@", item];
  NSArray *results = [self.reminders filteredArrayUsingPredicate:predicate];
  
  // Assuming we want to delete all matching reminders.
  if ([results count]) {
    [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
      NSError *error = nil;
      BOOL success = [self.eventStore removeReminder:obj commit:NO error:&error];
      if (!success) {
        // Handle delete error
      }
    }];
    
    NSError *commitErr = nil;
    BOOL success = [self.eventStore commit:&commitErr];
    if (!success) {
      // Handle commit error.
    }
  }
}

/** @brief Fetch reminder items from user's Reminder database. */
- (void)fetchReminders {
  
  if (self.isAccessToEventStoreGranted) {
    
    // A predicate to fetch all reminders.
    NSPredicate *predicate = [self.eventStore predicateForRemindersInCalendars:@[self.calendar]];
    
    // Fetch all matching reminders asynchronously.
    __weak RWTableViewController *weakSelf = self;
    [self.eventStore fetchRemindersMatchingPredicate:predicate completion:^(NSArray *reminders) {
      
      weakSelf.reminders = [NSMutableArray arrayWithArray:reminders];
      
      dispatch_async(dispatch_get_main_queue(), ^{
        // Update UI on the main thread.
        [weakSelf.tableView reloadData];
      });
    }];
  }
}

/** @brief Gets called when EKEventStoreChangedNotification is sent. */
- (void)eventStoreDidChangeWithNotification:(NSNotification *)notification {
  [self fetchReminders];
}

@end
