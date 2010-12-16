//
//  PtVideosSource.m
//  Primetime
//
//  Created by ∞ on 16/12/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "PtVideosSource.h"


@implementation PtVideosSource

+ videosSource;
{
	return [[self new] autorelease];
}

- (id) init;
{
	if ((self = [super init]))
		videos = [NSMutableSet new];
	
	return self;
}

- (void) dealloc
{
	[videos release];
	[super dealloc];
}


- (NSMutableSet *) mutableVideos;
{
	return [self mutableSetValueForKey:@"videos"];
}

- (NSSet *) videos;
{
	return videos;
}

- (void) setVideos:(NSSet *) vs;
{
	[videos setSet:vs];
}

- (void) addVideosObject:(id <PtVideo>) v;
{
	[videos addObject:v];
}

- (void) removeVideosObject:(id <PtVideo>) v;
{
	[videos removeObject:v];	
}

- (void) addVideos:(NSSet*) vs;
{
	[videos unionSet:vs];
}

- (void) removeVideos:(NSSet*) vs;
{
	[videos minusSet:vs];
}

@end
