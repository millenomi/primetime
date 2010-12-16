//
//  PtiTunesTrackVideo.m
//  Primetime
//
//  Created by ∞ on 16/12/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "PtiTunesTrackVideo.h"


@implementation PtiTunesTrackVideo

- (id) initWithTrack:(iTTrack*) t application:(iTApplication*) i;
{
	if ((self = [super init])) {
		itunes = [i retain];
		track = [[t get] retain];
	}
	
	return self;
}

- (void) dealloc
{
	[reps release];
	[itunes release];
	[track release];
	[super dealloc];
}


- (NSString*) series;
{
	return track.show ?: track.album;
}

- (NSUInteger) seasonNumber;
{
	return track.seasonNumber;
}

- (NSUInteger) episodeNumber;
{
	return track.episodeNumber;
}

- (NSTimeInterval) duration;
{
	return (NSTimeInterval) track.duration;
}

- (NSDate*) dateAdded;
{
	return track.dateAdded;
}

- (id) representationOfClass:(Class) c;
{
	if (c == [itunes classForScriptingClass:@"track"])
		return track;
	
	Class ft = [itunes classForScriptingClass:@"file track"];
	
	if ([track isKindOfClass:ft]) {
		if (c == ft)
			return track;
		else if (c == [NSURL class])
			return ((iTFileTrack*)track).location;
	}
	
	return nil;
}

- (NSSet*) representationClasses;
{
	if (!reps) {
		NSMutableSet* s = [NSMutableSet setWithObject:[itunes classForScriptingClass:@"track"]];
		Class ft = [itunes classForScriptingClass:@"file track"];
	
		if ([track isKindOfClass:ft]) {
			[s addObject:ft];
			[s addObject:[NSURL class]];
		}
		
		reps = [s copy];
	}
	
	return reps;
}

- (NSString *) description;
{
	return PtVideoDescription(self);
}

@end
