/*
 * MACDRV Cocoa window declarations
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


@class WineEventQueue;


@interface WineWindow : NSPanel <NSWindowDelegate>
{
    NSUInteger normalStyleMask;
    BOOL disabled;
    BOOL noActivate;
    BOOL floating;
    WineWindow* latentParentWindow;

    void* hwnd;
    WineEventQueue* queue;

    void* surface;
    pthread_mutex_t* surface_mutex;

    NSBezierPath* shape;
    BOOL shapeChangedSinceLastDraw;

    BOOL colorKeyed;
    CGFloat colorKeyRed, colorKeyGreen, colorKeyBlue;

    BOOL usePerPixelAlpha;

    NSUInteger lastModifierFlags;

    double mouseMoveDeltaX, mouseMoveDeltaY;

    NSInteger levelWhenActive;

    BOOL causing_becomeKeyWindow;
    BOOL ignore_windowMiniaturize;
    BOOL ignore_windowDeminiaturize;
}

@property (retain, readonly, nonatomic) WineEventQueue* queue;
@property (readonly, nonatomic) BOOL floating;
@property (readonly, nonatomic) NSInteger levelWhenActive;

    - (void) adjustWindowLevel;

    - (void) postMouseMovedEvent:(NSEvent *)theEvent absolute:(BOOL)absolute;

@end
