/*
 * MACDRV Cocoa event queue declarations
 *
 * Copyright 2011, 2012, 2013 Ken Thomases for CodeWeavers Inc.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA
 */

#import <AppKit/AppKit.h>
#include "macdrv_cocoa.h"


@interface WineEventQueue : NSObject
{
    NSMutableArray* events;
    NSLock*         eventsLock;

    int             fds[2]; /* Pipe signaling when there are events queued. */
}

    - (void) postEvent:(const macdrv_event*)inEvent;
    - (void) discardEventsMatchingMask:(macdrv_event_mask)mask forWindow:(NSWindow*)window;

@end
