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

#define kPtSchedulerDecisionInclude @"kPtSchedulerDecisionInclude"
#define kPtSchedulerDecisionExcludeScheduleWouldRunTooLong @"kPtSchedulerDecisionExcludeScheduleRanTooLong"
#define kPtSchedulerDecisionExcludeIgnoredDueToScheduleTimeLimit @"kPtSchedulerDecisionExcludeCutDueToScheduleTimeLimit"
#define kPtSchedulerDecisionExcludeHasPreviousUnwatchedEpisodes @"kPtSchedulerDecisionExcludeHasPreviousUnwatchedEpisodes"
#define kPtSchedulerDecisionExcludeHasNoAllowedRepresentations @"kPtSchedulerDecisionExcludeHasNoAllowedRepresentations"

#define kPtSchedulerDecisionIncludedToAvoidShortSchedule @"kPtSchedulerDecisionIncludedToAvoidShortSchedule"
#define kPtSchedulerDecisionIncludedToAvoidEmptySchedule @"kPtSchedulerDecisionIncludedToAvoidEmptySchedule"

enum {
	kPtSchedulerPriorityToOldestUnseen = 0,
	kPtSchedulerPriorityToNewestUnseen,
	kPtSchedulerPriorityRandom,
};
typedef NSInteger PtSchedulerPriority;

@interface PtScheduler : NSObject {
	NSMutableSet* videos;
	NSMutableArray* schedule;
	NSMutableDictionary* appropriateVideos;
	NSSet* allowedRepresentationClasses;
	
	NSUInteger holdCount;
	
	PtSchedulerPriority priority;
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
// can be KVO'd.
@property(nonatomic, readonly, copy) NSDictionary* decisions;

@property double approximateDesiredDuration;
@property(nonatomic, copy) NSSet* allowedRepresentationClasses;

- (void) beginHoldingScheduleUpdates;
- (void) endHoldingScheduleUpdates;

@property(nonatomic) PtSchedulerPriority priority;

// can be KVO'd.
// if YES, the scheduler is currently editing the .schedule property (which may produce multiple KVO notifications); if NO, the scheduler property has been changed and will not change in the foreseeable future. If you want to act upon a completed schedule only, observe this property and perform your operation only when this property is NO.
@property(nonatomic, readonly, getter=isEditingSchedule) BOOL editingSchedule;

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
	- [[SBApplication applicationWithBundleIdentifier:@"com.apple.itunes"] classForScriptingClass:@"track"]
 */
- (id) representationOfClass:(Class) c;
- (NSSet*) representationClasses;

@end
