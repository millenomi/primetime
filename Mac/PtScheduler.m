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

@property(nonatomic, copy) NSDictionary* decisions;

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
	self.decisions = nil;
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
	self.editingSchedule = YES;
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

static inline NSMutableArray* PtExistingOrNewMutableArrayForKey(NSMutableDictionary* dict, id key) {
	NSMutableArray* a = [dict objectForKey:key];
	if (!a) {
		a = [NSMutableArray array];
		[dict setObject:a forKey:key];
	}
	
	return a;
}

- (void) updateSchedule;
{	
	if (holdCount > 0)
		return;
	
	NSMutableDictionary* decs = [NSMutableDictionary dictionaryWithCapacity:[self.videos count]];
#define PtArrayForDecision(dec) PtExistingOrNewMutableArrayForKey(decs, (dec))
	
	
	NSMutableArray* s = [NSMutableArray array];
	NSSet* allowed = self.allowedRepresentationClasses;
	if (allowed && [allowed count] == 0)
		allowed = nil;
	
	NSMutableArray* applicableItems = [[[appropriateVideos allValues] mutableCopy] autorelease];
	
	// Apply priority
	if (self.priority == kPtSchedulerPriorityToOldestUnseen || self.priority == kPtSchedulerPriorityToNewestUnseen) {	
		[applicableItems sortUsingDescriptors:
		 [NSArray arrayWithObject:
		  [[[NSSortDescriptor alloc] initWithKey:@"dateAdded" ascending:(self.priority == kPtSchedulerPriorityToOldestUnseen)] autorelease]
		  ]
		 ];
	} else if (self.priority == kPtSchedulerPriorityRandom) {
		
		arc4random_stir();
		
		// Modern Knuth shuffle impl -- http://en.wikipedia.org/wiki/Fisher%E2%80%93Yates_shuffle#The_modern_algorithm
		for (NSInteger i = [applicableItems count] - 1; i > 1; i--) {
			// not sure this is distributed evenly, but oh well. we don't need true white-noise level of randomness here.
			NSInteger j = arc4random() % i + 1;
			[applicableItems exchangeObjectAtIndex:j withObjectAtIndex:i];
		}
		
	}
	
	BOOL shouldHaveMaximumDuration = (self.approximateDesiredDuration != 0.0);
	BOOL cutDueToTime = NO;
	double totalDuration = 0.0;
	
	NSInteger i = 0;
	
	for (id <PtVideo> video in applicableItems) {
		
		if (allowed && ![[video representationClasses] intersectsSet:allowed]) {
			[PtArrayForDecision(kPtSchedulerDecisionExcludeHasNoAllowedRepresentations) addObject:video];
			continue;
		}
		
		if (shouldHaveMaximumDuration && [video duration] + totalDuration > self.approximateDesiredDuration) {
			
			if ([s count] == 0)
				[PtArrayForDecision(kPtSchedulerDecisionIncludedToAvoidEmptySchedule) addObject:video];
			else if (totalDuration < self.approximateDesiredDuration * 0.8 && totalDuration + [video duration] < self.approximateDesiredDuration * 1.5)
				[PtArrayForDecision(kPtSchedulerDecisionIncludedToAvoidShortSchedule) addObject:video];
			else {
				[PtArrayForDecision(kPtSchedulerDecisionExcludeScheduleWouldRunTooLong) addObject:video];
				continue;
			}
		}
		
		[s addObject:video];
		totalDuration += [video duration];
		[PtArrayForDecision(kPtSchedulerDecisionInclude) addObject:video];
		
		i++;
		
		if (shouldHaveMaximumDuration && totalDuration > self.approximateDesiredDuration) {
			cutDueToTime = YES;
			break;
		}
	}
	
	if (cutDueToTime) {
		NSArray* excluded = [applicableItems subarrayWithRange:NSMakeRange(i, [applicableItems count] - i)];
		[PtArrayForDecision(kPtSchedulerDecisionExcludeIgnoredDueToScheduleTimeLimit) addObjectsFromArray:excluded];
	}
	
	if (!self.editingSchedule)
		self.editingSchedule = YES;
	
	[[self mutableArrayValueForKey:@"schedule"] setArray:s];
	
	self.decisions = decs;
	self.editingSchedule = NO;
}

@synthesize decisions, editingSchedule;

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

@synthesize priority;
- (void) setPriority:(PtSchedulerPriority) p;
{
	priority = p;
	[self updateSchedule];
}

@end

NSString* PtVideoDescription(id <PtVideo> video) {
	return [NSString stringWithFormat:@"<%@ %p> { '%@' %lux%lu, %f added on %@ }",
			[video class], video, [video series], (unsigned long) [video seasonNumber], (unsigned long) [video episodeNumber], (double) [video duration], [video dateAdded]];
}
