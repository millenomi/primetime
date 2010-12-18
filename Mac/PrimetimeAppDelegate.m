//
//  PrimetimeAppDelegate.m
//  Primetime
//
//  Created by ∞ on 16/12/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "PrimetimeAppDelegate.h"
#import "iTunes.h"

#import "PtiTunesTrackVideo.h"

@interface SBElementArray (PtConveniences)
- (SBElementArray*) where:(NSString*) x, ...;
- (SBElementArray*) arrayOf:(SEL) prop;
@end

@implementation SBElementArray (PtConveniences)

- (SBElementArray*) where:(NSString*) x, ...;
{
	va_list l;
	va_start(l, x);
	
	NSPredicate* p = [NSPredicate predicateWithFormat:x arguments:l];
	
	va_end(l);
	
	return (SBElementArray*) [self filteredArrayUsingPredicate:p];
}

- (SBElementArray*) arrayOf:(SEL) prop;
{
	return (SBElementArray*) [self arrayByApplyingSelector:prop];
}

@end

#define PtEnum(x) [NSAppleEventDescriptor descriptorWithEnumCode:(x)]


@implementation PrimetimeAppDelegate

@synthesize window;

@synthesize scheduler;

- (void) applicationDidFinishLaunching:(NSNotification*) aNotification;
{
	self.durationInQuartersOfHour = 1;
	self.scheduler = [PtScheduler schedule];
	[self.scheduler addObserver:self forKeyPath:@"editingSchedule" options:0 context:NULL];
	[self.scheduler addObserver:self forKeyPath:@"decisions" options:0 context:NULL];
	
	iTApplication* itunes = [SBApplication applicationWithBundleIdentifier:@"com.apple.itunes"];
	
	SBElementArray* librarySources = [[itunes sources] where:@"kind == %@", PtEnum(iTESrcLibrary)];
	if ([librarySources count] == 0)
		return;
	
	iTSource* librarySource = [librarySources objectAtIndex:0];
	
	iTPlaylist* tvShowsPlaylist = nil, * podcastsPlaylist = nil;
	
	for (iTPlaylist* playlist in [librarySource playlists]) {
		if (!tvShowsPlaylist && playlist.specialKind == iTESpKTVShows)
			tvShowsPlaylist = [playlist get];
		else if (!podcastsPlaylist && playlist.specialKind == iTESpKPodcasts)
			podcastsPlaylist = [playlist get];		
		
		if (tvShowsPlaylist && podcastsPlaylist)
			break;
	}
	
	NSMutableArray* allTracks = [NSMutableArray array];
	[allTracks addObjectsFromArray:[tvShowsPlaylist tracks]];
	[allTracks addObjectsFromArray:[podcastsPlaylist tracks]];
	
	[self.scheduler beginHoldingScheduleUpdates];
	
	for (iTTrack* track in allTracks) {
		
		if (!track.enabled)
			continue;
		
		if (track.playedDate)
			continue;
		
		PtiTunesTrackVideo* itv = [[[PtiTunesTrackVideo alloc] initWithTrack:track application:itunes] autorelease];
		[self.scheduler addVideosObject:itv];
		
	}
	
	self.scheduler.approximateDesiredDuration = 2 * 60 * 60;

	[self.scheduler endHoldingScheduleUpdates];
	
	NSLog(@"%@", self.scheduler.schedule);
	NSLog(@"%@", self.scheduler.decisions);
}

@synthesize durationInQuartersOfHour;
- (void) setDurationInQuartersOfHour:(NSInteger) h;
{
	durationInQuartersOfHour = h;
	self.scheduler.approximateDesiredDuration = h * 15 * 60;
}

+ keyPathsForValuesAffectingUserVisibleDuration;
{
	return [NSSet setWithObjects:@"durationInQuartersOfHour", @"scheduler.approximateDesiredDuration", nil];
}
- (NSString*) userVisibleDuration;
{
	NSTimeInterval d = self.scheduler.approximateDesiredDuration;
	
	if (d == 0.0)
		return NSLocalizedString(@"no limit", @"User visible max duration - none");
	else if (d <= 60 * 60)
		return [NSString stringWithFormat:NSLocalizedString(@"%d minutes", @"User visible max duration - in minutes"), (int) d / 60];
	else
		return [NSString stringWithFormat:NSLocalizedString(@"%d hours", @"User visible max duration - in minutes"), (int) d / (60 * 60)];
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context;
{
	if ([keyPath isEqual:@"decisions"]) {
		NSLog(@"Decisions: %@", self.scheduler.decisions);
		return;
	}
	
#define kPtPrimetimePlaylistName [NSString stringWithFormat:@"%C Prima serata", 0x2022]
	
	if (self.scheduler.editingSchedule)
		return;
	
	iTApplication* itunes = [SBApplication applicationWithBundleIdentifier:@"com.apple.itunes"];
	
	SBElementArray* librarySources = [[itunes sources] where:@"kind == %@", PtEnum(iTESrcLibrary)];
	if ([librarySources count] == 0)
		return;
	
	iTSource* librarySource = [librarySources objectAtIndex:0];
	iTPlaylist* primetimePlaylist = nil;
	
	for (iTPlaylist* playlist in [librarySource playlists]) {
		if (!primetimePlaylist && [playlist.name isEqual:kPtPrimetimePlaylistName]) {
			primetimePlaylist = [playlist get];
			break;
		}
	}
	
	if (!primetimePlaylist) {
		primetimePlaylist = [[[itunes classForScriptingClass:@"playlist"] alloc] initWithProperties:
							 [NSDictionary dictionaryWithObject:kPtPrimetimePlaylistName forKey:@"name"]
							 ];
		[[librarySource playlists] addObject:primetimePlaylist];
	}
	
	[[primetimePlaylist tracks] removeAllObjects];
	
	if (!self.scheduler.schedule)
		return;
	
	Class c = [itunes classForScriptingClass:@"track"];
	
	for (id <PtVideo> v in self.scheduler.schedule)
		[[v representationOfClass:c] duplicateTo:primetimePlaylist];
	
	NSLog(@"%@", self.scheduler.schedule);
}

@end
