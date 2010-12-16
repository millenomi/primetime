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
	self.scheduler = [PtScheduler schedule];
	
	iTApplication* itunes = [SBApplication applicationWithBundleIdentifier:@"com.apple.itunes"];
	
	SBElementArray* librarySources = [[itunes sources] where:@"kind == %@", PtEnum(iTESrcLibrary)];
	if ([librarySources count] == 0)
		return;
	
	iTSource* librarySource = [librarySources objectAtIndex:0];
	
#define kPtPrimetimePlaylistName [NSString stringWithFormat:@"%C Prima serata", 0x2022]
	
	iTPlaylist* primetimePlaylist = nil, * tvShowsPlaylist = nil, * podcastsPlaylist = nil;
	
	for (iTPlaylist* playlist in [librarySource playlists]) {
		if (!tvShowsPlaylist && playlist.specialKind == iTESpKTVShows)
			tvShowsPlaylist = [playlist get];
		else if (!podcastsPlaylist && playlist.specialKind == iTESpKPodcasts)
			podcastsPlaylist = [playlist get];
		else if (!primetimePlaylist && [playlist.name isEqual:kPtPrimetimePlaylistName])
			primetimePlaylist = [playlist get];
		
		
		if (primetimePlaylist && tvShowsPlaylist && podcastsPlaylist)
			break;
	}
	
	if (!primetimePlaylist) {
		primetimePlaylist = [[[itunes classForScriptingClass:@"playlist"] alloc] initWithProperties:
							 [NSDictionary dictionaryWithObject:kPtPrimetimePlaylistName forKey:@"name"]
							 ];
		[[librarySource playlists] addObject:primetimePlaylist];
	}
	
	[[primetimePlaylist tracks] removeAllObjects];
	
	NSMutableArray* allTracks = [NSMutableArray array];
	[allTracks addObjectsFromArray:[tvShowsPlaylist tracks]];
	[allTracks addObjectsFromArray:[podcastsPlaylist tracks]];
	
	[self.scheduler beginHoldingScheduleUpdates];
	
	for (iTTrack* track in allTracks) {
		
		if (!track.enabled)
			continue;
		
		PtiTunesTrackVideo* itv = [[[PtiTunesTrackVideo alloc] initWithTrack:track application:itunes] autorelease];
		[self.scheduler addVideosObject:itv];
		
	}
	
	self.scheduler.approximateDesiredDuration = 2 * 60 * 60;

	[self.scheduler endHoldingScheduleUpdates];
	
	NSLog(@"%@", self.scheduler.schedule);
	
	Class c = [itunes classForScriptingClass:@"track"];
	
	for (id <PtVideo> v in self.scheduler.schedule)
		[[v representationOfClass:c] duplicateTo:primetimePlaylist];
}

@end
