
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
	
	NSMutableDictionary* earliestUnseenEpisodes = [NSMutableDictionary dictionary];
	
	NSMutableArray* allTracks = [NSMutableArray array];
	[allTracks addObjectsFromArray:[tvShowsPlaylist tracks]];
	[allTracks addObjectsFromArray:[podcastsPlaylist tracks]];
	
	for (iTTrack* track in [tvShowsPlaylist tracks]) {
		if (track.videoKind == iTEVdKNone)
			continue; // only videos.
		
		if (track.playedCount > 0)
			continue; // don't look at watched tracks.
		
		NSString* show = track.show;
		if (!show) {
			show = track.album;
			if (!show)
				continue;
		}
		
		NSInteger epNo = track.episodeNumber;
		if (epNo == 0)
			continue;
		
		NSInteger seasonNo = track.seasonNumber;
		if (seasonNo == 0)
			seasonNo = 1;
		
		iTTrack* earliestKnown = [earliestUnseenEpisodes objectForKey:show];
		
		NSInteger earliestKnownSeason = earliestKnown.seasonNumber;
		if (earliestKnownSeason == 0)
			earliestKnownSeason = 1;
		
		if (!earliestKnown || (seasonNo < earliestKnownSeason) || (seasonNo == earliestKnownSeason && epNo < earliestKnown.episodeNumber))
			[earliestUnseenEpisodes setObject:track forKey:show];
	}
	
	NSMutableArray* orderedTracks = [[earliestUnseenEpisodes allValues] mutableCopy];
	
	[orderedTracks sortUsingDescriptors:
	 [NSArray arrayWithObject:
	  [[NSSortDescriptor alloc] initWithKey:@"dateAdded" ascending:YES]
	  ]];
	
	BOOL addedAny = NO;
	double totalDuration = 0.0;
	
	for (iTTrack* track in orderedTracks) {
		// we're not going over two hours, but we stop as soon as we have one hour and a half of content at least.
		
		if (addedAny && totalDuration + track.duration > 2 * 60 * 60 /* two hours */)
			break;
		
		[track duplicateTo:primetimePlaylist];
		addedAny = YES;
		
		totalDuration += track.duration;
		if (totalDuration > 1.5 * 60 * 60 /* one and a half hours */) 
			break;
	}
	
	// Class fileTrackClass = [itunes classForScriptingClass:@"file track"];
	
	NSMutableArray* orderedTrackURLs = [NSMutableArray array];
	
	for (iTTrack* track in orderedTracks) {
		track = [track get];
		if ([track respondsToSelector:@selector(location)])
			[orderedTrackURLs addObject:[(iTFileTrack*)track location]];
	}
	
	NSLog(@"%@", orderedTrackURLs);
	
	NSFileManager* fm = [NSFileManager defaultManager];
	
	NSString* appSupportPath = [[[fm URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask] objectAtIndex:0] path];
	NSString* primetimePath = [appSupportPath stringByAppendingPathComponent:@"Primetime"];
	
	NSString* videosPath = [primetimePath stringByAppendingPathComponent:@"Videos"];
	
	[fm createDirectoryAtPath:primetimePath withIntermediateDirectories:YES attributes:nil error:NULL];
	
	for (NSURL* fileURL in [fm contentsOfDirectoryAtURL:[NSURL fileURLWithPath:primetimePath] includingPropertiesForKeys:[NSArray array] options:0 error:NULL]) {
		
		[fm removeItemAtURL:fileURL error:nil];
		
	}
	
	[fm createDirectoryAtPath:videosPath withIntermediateDirectories:YES attributes:nil error:NULL];
	
	
	NSInteger i = 1;
	
	NSMutableData* m3uData = [NSMutableData data];
	
	uint8_t newline = '\n';
	NSData* newlineData = [NSData dataWithBytes:&newline length:1];
	
	for (NSURL* trackURL in orderedTrackURLs) {
		NSString* fileName = [[trackURL path] lastPathComponent];
		NSString* baseName = [NSString stringWithFormat:@"%ld - %@", (long) i, fileName];
		
		NSString* finalPath = [videosPath stringByAppendingPathComponent:baseName];
		
		[fm createSymbolicLinkAtPath:finalPath withDestinationPath:[trackURL path] error:NULL];
		
		i++;
		
		__strong const char* data = [[@"Videos" stringByAppendingPathComponent:baseName] fileSystemRepresentation];
		
		[m3uData appendData:[NSData dataWithBytes:data length:strlen(data)]];
		[m3uData appendData:newlineData];
	}
	
	[m3uData writeToFile:[primetimePath stringByAppendingPathComponent:@"Primetime.m3u"] atomically:YES];