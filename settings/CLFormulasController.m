/*
Copyright (C) 2014 Reed Weichler

This file is part of Cylinder.

Cylinder is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Cylinder is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Cylinder.  If not, see <http://www.gnu.org/licenses/>.
*/

#import <Defines.h>
#import "CLFormulasController.h"
#import "CylinderSettings.h"
#import "writeit.h"

// #import "UDTableView.h"
#import "CLAlignedTableViewCell.h"
#include <objc/runtime.h>

@implementation UIDevice (OSVersion)
- (BOOL)iOSVersionIsAtLeast:(NSString*)version
{
    NSComparisonResult result = [[self systemVersion] compare:version options:NSNumericSearch];
    return (result == NSOrderedDescending || result == NSOrderedSame);
}
@end

@interface UITableView (Private)
- (NSArray *) indexPathsForSelectedRows;
@property(nonatomic) BOOL allowsMultipleSelectionDuringEditing;
@end

@interface PSViewController(Private)
-(void)viewWillAppear:(BOOL)animated;
-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath;
@end


@implementation CLFormulasController
@synthesize formulas=_formulas,selectedFormula=_selectedFormula,createFormulaButton=_createFormulaButton;

- (id)initForContentSize:(CGSize)size
{
	if ((self = [super initForContentSize:size]))
    {
		_tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height) style:UITableViewStyleGrouped];
		[_tableView setDataSource:self];
		[_tableView setDelegate:self];
		[_tableView setEditing:NO];
		[_tableView setAllowsSelection:YES];

		if ([[UIDevice currentDevice] iOSVersionIsAtLeast: @"5.0"]) {
			[_tableView setAllowsMultipleSelection:NO];
			[_tableView setAllowsSelectionDuringEditing:YES];
			[_tableView setAllowsMultipleSelectionDuringEditing:YES];
		}
		
		if ([self respondsToSelector:@selector(setView:)])
			[self performSelectorOnMainThread:@selector(setView:) withObject:_tableView waitUntilDone:YES];	

        self.createFormulaButton = [[UIBarButtonItem.alloc initWithTitle:@"New" style:UIBarButtonItemStyleBordered target:self action:@selector(createFormulaButtonPressed:)] autorelease];
	}
	return self;
}

- (void)refreshList
{
    CylinderSettingsListController *ctrl = (CylinderSettingsListController*)self.parentController;

    NSDictionary *formulas = [ctrl.settings objectForKey:PrefsFormulaKey];
    if(!formulas)
    {
        self.formulas = [NSMutableDictionary dictionary];
    }
    else
    {
        self.formulas = formulas.mutableCopy;
        /*
        self.formulas = [NSMutableDictionary dictionaryWithCapacity:formulas.count];
        for(NSString *key in formulas)
        {
            NSArray *effectDicts = [formulas objectForKey:key];
            NSMutableArray *effects = [NSMutableArray arrayWithCapacity:effectDicts.count];
            for(NSDictionary *effectDict in effectDicts)
            {
                NSString *dir = [effectDict objectForKey:PrefsEffectDirKey];
                NSString *name = [effectDict objectForKey:PrefsEffectKey];

                if(dir && name)
                {
                    NSString *path = [[kEffectsDirectory stringByAppendingPathComponent:dir] stringByAppendingPathComponent:name];
                    CLEffect *effect = [CLEffect effectWithPath:path];
                    if(effect)
                        [effects addObject:effectDict];
                }
            }
            [self.formulas setObject:effects forKey:key];
        }
        */
    }

    self.selectedFormula = [ctrl.settings objectForKey:PrefsSelectedFormulaKey];
}

-(void)showAlertWithText:(NSString *)text
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil message:text delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Create Formula", nil];
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    [alert textFieldAtIndex:0].placeholder = @"Formula name";
    [alert show];

}

-(void)createFormulaWithName:(NSString *)name
{
    CylinderSettingsListController *ctrl = (CylinderSettingsListController*)self.parentController;
    NSArray *effects = [ctrl.settings objectForKey:PrefsEffectKey];

    if(!effects)
    {
        [self showAlertWithText:@"IT FUCKED UP!"];
        return;
    }

    [self.formulas setObject:effects forKey:name];
    self.selectedFormula = name;
    [self updateSettings];
    [_tableView reloadData];
}

-(void)createFormulaButtonPressed:(UIBarButtonItem *)button
{
    if(button != self.createFormulaButton) return;

    CylinderSettingsListController *ctrl = (CylinderSettingsListController*)self.parentController;

    NSDictionary *effects = [ctrl.settings objectForKey:PrefsEffectKey];

    if(effects.count == 0)
    {
        [[UIAlertView.alloc initWithTitle:@"You have no effects enabled!" message:@"Go back to the effects list, enable some effects, then come back here and create a new formula." delegate:self cancelButtonTitle:@"Okay" otherButtonTitles:nil] show];
    }
    else
    {
        [self showAlertWithText:@"The new formula will have whatever effects you have enabled right now."];
    }
}

static NSString *_theFormulaName;

-(void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if(buttonIndex == alertView.cancelButtonIndex)
    {
        //do nothing
    }
    else if(alertView.alertViewStyle == UIAlertViewStylePlainTextInput)
    {
        NSString *name = [alertView textFieldAtIndex:0].text;

        if(name.length == 0)
        {
            [self showAlertWithText:@"You didn't type anything."];
        }
        else if([self.formulas objectForKey:name])
        {
            _theFormulaName = [name retain];
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil message:@"A formula with that name already exists." delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Overwrite it", nil];
            [alert show];
        }
        else
        {
            [self createFormulaWithName:name];
        }
    }
    else if(_theFormulaName)
    {
        [self createFormulaWithName:[_theFormulaName autorelease]];
        _theFormulaName = nil;
    }
    [alertView release];
}

- (void)viewWillAppear:(BOOL)animated
{
    if(!_initialized)
    {
        [self refreshList];
        _initialized = true;
    }
    [super viewWillAppear:animated];

    ((UINavigationItem *)self.navigationItem).rightBarButtonItem = self.createFormulaButton;
}

- (void)dealloc
{
    self.formulas = nil;
    self.selectedFormula = nil;
    self.createFormulaButton = nil;
    [super dealloc];
}

- (NSString*)navigationTitle
{
    return @"Formulas";
}

- (id)view
{
    return _tableView;
}

/* UITableViewDelegate / UITableViewDataSource Methods {{{ */
- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

-(NSString *)keyForIndex:(int)index
{
    int i = 0;
    for(NSString *key in self.formulas)
    {
        if(i == index) return key;
        i++;
    }
    return nil;
}

-(NSUInteger)indexForKey:(NSString *)key
{
    NSUInteger i = 0;
    for(NSString *k in self.formulas)
    {
        if([k isEqualToString:key]) return i;
        i++;
    }
    return NSNotFound;
}

- (id) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return nil;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.formulas.count;
}

-(id)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    CLAlignedTableViewCell *cell = (CLAlignedTableViewCell*)[tableView dequeueReusableCellWithIdentifier:@"EffectCell"];
    if (!cell)
    {
        cell = [CLAlignedTableViewCell.alloc initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"EffectCell"].autorelease;
        cell.textLabel.adjustsFontSizeToFitWidth = true;
    }

    NSString *name = [self keyForIndex:indexPath.row];
    BOOL selected = [name isEqualToString:self.selectedFormula];

    cell.textLabel.text = name;
    cell.selected = false;
    cell.accessoryType = selected ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;

    return cell;
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (!tableView.isEditing)
    {
        [tableView deselectRowAtIndexPath:indexPath animated:true];

        if(self.selectedFormula)
        {
            int index = [self indexForKey:self.selectedFormula];
            UITableViewCell *cell = [_tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]];
            cell.accessoryType = UITableViewCellAccessoryNone;
        }

        self.selectedFormula = [self keyForIndex:indexPath.row];
        UITableViewCell *cell = [_tableView cellForRowAtIndexPath:indexPath];

        cell.accessoryType = UITableViewCellAccessoryCheckmark;

        [self updateSettings];
    }
}

-(void)updateSettings
{
    // make the title changes
    CylinderSettingsListController *ctrl = (CylinderSettingsListController*)self.parentController;
    ctrl.formulas = self.formulas;
    ctrl.selectedFormula = self.selectedFormula;
    [ctrl sendSettings];
}

- (UITableViewCellEditingStyle)tableView:(UITableView*)tableView editingStyleForRowAtIndexPath:(NSIndexPath*)indexPath
{
    return (UITableViewCellEditingStyle)3;
}

@end
