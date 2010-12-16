//
//  PtVideosSource.h
//  Primetime
//
//  Created by ∞ on 16/12/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "PtScheduler.h"

@interface PtVideosSource : NSObject <PtVideosSource> {
	NSMutableSet* videos;
}

+ videosSource;

@property(nonatomic, readonly) NSMutableSet* mutableVideos;

@property(nonatomic, copy) NSSet* videos;

- (void) addVideosObject:(id <PtVideo>) v;
- (void) removeVideosObject:(id <PtVideo>) v;

- (void) addVideos:(NSSet*) vs;
- (void) removeVideos:(NSSet*) vs;

@end
