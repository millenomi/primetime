//
//  PtiTunesTrackVideo.h
//  Primetime
//
//  Created by ∞ on 16/12/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ScriptingBridge/ScriptingBridge.h>

#import "iTunes.h"

#import "PtScheduler.h"

@interface PtiTunesTrackVideo : NSObject <PtVideo> {
	iTApplication* itunes;
	iTTrack* track;
	NSSet* reps;
}

- (id) initWithTrack:(iTTrack*) t application:(iTApplication*) i;

@end
