//
//  PtSchedule.m
//  Primetime
//
//  Created by ∞ on 16/12/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "PtScheduler.h"

static NSInteger PtCompareEpisodeAndSeason(id v, id v2, void* context) {
	if ([v seasonNumber] == [v2 seasonNumber] && [v episodeNumber] == [v2 episodeNumber])
		return NSOrderedSame;
	else if ([v seasonNumber] < [v2 seasonNumber])
		return NSOrderedAscending;
	else if ([v seasonNumber] > [v2 seasonNumber])
		return NSOrderedDescending;
	else if ([v episodeNumber] < [v2 episodeNumber])
		return NSOrderedAscending;
	else
		return NSOrderedSame;
}

@interface PtScheduler ()

- (void) updateSchedule;

- (void) setVideos:(NSSet*) videos;

@end


@implementation PtScheduler

+ (id) schedule;
{
	return [[self new] autorelease];
}

- (id) init
{
	self = [super init];
	if (self != nil) {
		videos = [NSMutableSet new];
		schedule = [NSMutableArray new];
		appropriateVideos = [NSMutableDictionary new];
	}
	
	return self;
}

- (void) dealloc
{
	self.videosSource = nil;
	[allowedRepresentationClasses release];
	[videos release];
	[schedule release];
	[appropriateVideos release];
	[super dealloc];
}


@synthesize videosSource;
- (void) setVideosSource:(id <PtVideosSource>) v;
{
	if (v != videosSource) {
		if (videosSource)
			[(id)videosSource removeObserver:self forKeyPath:@"videos"];
	
		[videosSource release];
		videosSource = [v retain];
		
		if (v) {
			[self setVideos:[v videos]];
			[(id)v addObserver:self forKeyPath:@"videos" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld context:NULL];
		}
	}
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context;
{
	NSUInteger changeKind = [[change objectForKey:NSKeyValueChangeKindKey] unsignedIntegerValue];
	if (changeKind == NSKeyValueChangeSetting) {
		[self setVideos:[self.videosSource videos]];
		return;
	}
	
	[self beginHoldingScheduleUpdates];
	
	for (id <PtVideo> v in [change objectForKey:NSKeyValueChangeOldKey])
		[self removeVideosObject:v];
	
	for (id <PtVideo> v in [change objectForKey:NSKeyValueChangeNewKey])
		[self addVideosObject:v];
	
	[self endHoldingScheduleUpdates];
}


- (NSSet *) videos;
{
	return videos;
}

- (void) setVideos:(NSSet *) newVideos;
{
	[self beginHoldingScheduleUpdates];
	
	for (id <PtVideo> v in [[videos copy] autorelease])
		[self removeVideosObject:v];
	
	for (id <PtVideo> v in newVideos)
		[self addVideosObject:v];
	
	[self endHoldingScheduleUpdates];
}

- (void) addVideosObject:(id <PtVideo>)video;
{
	[videos addObject:video];
	
	NSString* series = [video series];
	id <PtVideo> otherVideo = [appropriateVideos objectForKey:series];
	if (!otherVideo || PtCompareEpisodeAndSeason(video, otherVideo, NULL) == NSOrderedAscending) {
		[appropriateVideos setObject:video forKey:series];
		[self updateSchedule];
	}
}

- (void) removeVideosObject:(id <PtVideo>)video;
{
	NSString* series = [video series];
	
	if ([appropriateVideos objectForKey:series] == video) {
		
		id <PtVideo> newVideo = nil;
		for (id <PtVideo> candidate in videos) {
			if ([[candidate series] isEqual:series]) {
				if (!newVideo || PtCompareEpisodeAndSeason(candidate, newVideo, NULL) == NSOrderedAscending)
					newVideo = candidate;
			}
		}
		
		if (newVideo)
			[appropriateVideos setObject:newVideo forKey:series];
		else
			[appropriateVideos removeObjectForKey:series];
		
		[self updateSchedule];
	}
	
	[videos removeObject:video];
}

- (NSArray *) schedule;
{
	return schedule;
}

- (void) beginHoldingScheduleUpdates;
{
	holdCount++;
}

- (void) endHoldingScheduleUpdates;
{
	if (holdCount == 0)
		return;
	
	holdCount--;
	if (holdCount == 0)
		[self updateSchedule];
}

- (void) updateSchedule;
{
	if (holdCount > 0)
		return;
	
	NSMutableArray* s = [NSMutableArray array];
	NSSet* allowed = self.allowedRepresentationClasses;
	if (allowed && [allowed count] == 0)
		allowed = nil;
	
	BOOL shouldHaveMaximumDuration = (self.approximateDesiredDuration != 0.0);
	double totalDuration = 0.0;
	for (id <PtVideo> video in [appropriateVideos allValues]) {
		
		if (allowed && ![[video representationClasses] intersectsSet:allowed])
			continue;
		
		if (shouldHaveMaximumDuration && [s count] > 0 && totalDuration + [video duration] > self.approximateDesiredDuration * 1.5)
			break;
		
		[s addObject:video];
		totalDuration += [video duration];
		
		if (shouldHaveMaximumDuration && totalDuration > self.approximateDesiredDuration)
			break;
		
	}
	
	[s sortUsingDescriptors:
	 [NSArray arrayWithObject:
	  [[[NSSortDescriptor alloc] initWithKey:@"dateAdded" ascending:YES] autorelease]
	  ]
	 ];
	
	[[self mutableArrayValueForKey:@"schedule"] setArray:s];
}

@synthesize approximateDesiredDuration;
- (void) setApproximateDesiredDuration:(double) d;
{
	approximateDesiredDuration = d;
	[self updateSchedule];
}

@synthesize allowedRepresentationClasses;
- (void) setAllowedRepresentationClasses:(NSSet *) s;
{
	if (s != allowedRepresentationClasses) {
		[allowedRepresentationClasses release];
		allowedRepresentationClasses = [s copy];
		
		[self updateSchedule];
	}
}

@end

NSString* PtVideoDescription(id <PtVideo> video) {
	return [NSString stringWithFormat:@"<%@ %p> { '%@' %lux%lu, %f added on %@ }",
			[video class], video, [video series], (unsigned long) [video seasonNumber], (unsigned long) [video episodeNumber], (double) [video duration], [video dateAdded]];
}
