//
//  helper.m
//  Monolingual
//
//  Created by Ingmar Stein on Tue Mar 23 2004.
//  Copyright (c) 2004 Ingmar Stein. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 2 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program; if not, write to the Free Software
//  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
//

#import "DeleteHelper.h"

int main( int argc, const char *argv[] )
{
	int i;

	if( argc <= 1 ) {
		return( 1 );
	}

	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	NSMutableSet *directories = [[NSMutableSet alloc] initWithCapacity: argc-1];
	for( i=1; i<argc; ++i ) {
		[directories addObject: [NSString stringWithCString: argv[i]]];
	}

	DeleteHelper *deleteHelper = [[DeleteHelper alloc] initWithDirectories: directories];
	NSApp = [NSApplication sharedApplication];
	[NSApp setDelegate: deleteHelper];
	[pool release];
	[NSApp run];

	return( 0 );
}