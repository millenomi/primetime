//
//  PtSchedule.h
//  Primetime
//
//  Created by ∞ on 16/12/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol PtVideo, PtVideosSource;

extern NSString* PtVideoDescription(id <PtVideo> video);

@interface PtScheduler : NSObject {
	NSMutableSet* videos;
	NSMutableArray* schedule;
	NSMutableDictionary* appropriateVideos;
	NSSet* allowedRepresentationClasses;
	
	NSUInteger holdCount;
}

+ schedule;

// can be KVO'd. If non-nil, the schedule will KVO this object's .videos key and update its .videos key accordingly.
// This is primarily for iOS, where there are no bindings. :(
@property(nonatomic, retain) id <PtVideosSource> videosSource;

// can be KVO'd.
@property(nonatomic, readonly) NSSet* videos;
- (void) addVideosObject:(id <PtVideo>) video;
- (void) removeVideosObject:(id <PtVideo>) video;

// can be KVO'd.
@property(nonatomic, readonly) NSArray* schedule;

@property double approximateDesiredDuration;
@property(nonatomic, copy) NSSet* allowedRepresentationClasses;

- (void) beginHoldingScheduleUpdates;
- (void) endHoldingScheduleUpdates;

@end


@protocol PtVideosSource <NSObject>

// can be KVO'd.
- (NSSet*) videos;

@end

@protocol PtVideo <NSObject>

- (NSString*) series;
- (NSUInteger) seasonNumber;
- (NSUInteger) episodeNumber;

- (NSTimeInterval) duration;

- (NSDate*) dateAdded;

/*
	This produces a track representation of that particular class. You can use representationClasses to see which ones are available.
	Classes we want to have if available:
	- NSURL
	- [[SBApplication applicationWithBundleIdentifier:@"com.apple.itunes"] classForScriptingClass:@"file track"]
 */
- (id) representationOfClass:(Class) c;
- (NSSet*) representationClasses;

@end
