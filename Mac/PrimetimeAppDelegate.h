//
//  PrimetimeAppDelegate.h
//  Primetime
//
//  Created by ∞ on 16/12/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "PtScheduler.h"
#import "PtVideosSource.h"

@interface PrimetimeAppDelegate : NSObject <NSApplicationDelegate> {
    NSWindow *window;
	
	PtScheduler* scheduler;
	// PtVideosSource* videosSource;
	
	NSInteger durationInQuartersOfHour;
}

@property(assign) IBOutlet NSWindow *window;

@property(retain) PtScheduler* scheduler;
// @property(retain) PtVideosSource* videosSource;

@property NSInteger durationInQuartersOfHour;
@property(readonly) NSString* userVisibleDuration;

@end
