/*
 * MACDRV Cocoa window code
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

#import <Carbon/Carbon.h>

#import "cocoa_window.h"

#include "macdrv_cocoa.h"
#import "cocoa_app.h"
#import "cocoa_event.h"


/* Additional Mac virtual keycode, to complement those in Carbon's <HIToolbox/Events.h>. */
enum {
    kVK_RightCommand              = 0x36, /* Invented for Wine; was unused */
};


static NSUInteger style_mask_for_features(const struct macdrv_window_features* wf)
{
    NSUInteger style_mask;

    if (wf->title_bar)
    {
        style_mask = NSTitledWindowMask;
        if (wf->close_button) style_mask |= NSClosableWindowMask;
        if (wf->minimize_button) style_mask |= NSMiniaturizableWindowMask;
        if (wf->resizable) style_mask |= NSResizableWindowMask;
        if (wf->utility) style_mask |= NSUtilityWindowMask;
    }
    else style_mask = NSBorderlessWindowMask;

    return style_mask;
}


static BOOL frame_intersects_screens(NSRect frame, NSArray* screens)
{
    NSScreen* screen;
    for (screen in screens)
    {
        if (NSIntersectsRect(frame, [screen frame]))
            return TRUE;
    }
    return FALSE;
}


static NSScreen* screen_covered_by_rect(NSRect rect, NSArray* screens)
{
    for (NSScreen* screen in screens)
    {
        if (NSContainsRect(rect, [screen frame]))
            return screen;
    }
    return nil;
}


/* We rely on the supposedly device-dependent modifier flags to distinguish the
   keys on the left side of the keyboard from those on the right.  Some event
   sources don't set those device-depdendent flags.  If we see a device-independent
   flag for a modifier without either corresponding device-dependent flag, assume
   the left one. */
static inline void fix_device_modifiers_by_generic(NSUInteger* modifiers)
{
    if ((*modifiers & (NX_COMMANDMASK | NX_DEVICELCMDKEYMASK | NX_DEVICERCMDKEYMASK)) == NX_COMMANDMASK)
        *modifiers |= NX_DEVICELCMDKEYMASK;
    if ((*modifiers & (NX_SHIFTMASK | NX_DEVICELSHIFTKEYMASK | NX_DEVICERSHIFTKEYMASK)) == NX_SHIFTMASK)
        *modifiers |= NX_DEVICELSHIFTKEYMASK;
    if ((*modifiers & (NX_CONTROLMASK | NX_DEVICELCTLKEYMASK | NX_DEVICERCTLKEYMASK)) == NX_CONTROLMASK)
        *modifiers |= NX_DEVICELCTLKEYMASK;
    if ((*modifiers & (NX_ALTERNATEMASK | NX_DEVICELALTKEYMASK | NX_DEVICERALTKEYMASK)) == NX_ALTERNATEMASK)
        *modifiers |= NX_DEVICELALTKEYMASK;
}

/* As we manipulate individual bits of a modifier mask, we can end up with
   inconsistent sets of flags.  In particular, we might set or clear one of the
   left/right-specific bits, but not the corresponding non-side-specific bit.
   Fix that.  If either side-specific bit is set, set the non-side-specific bit,
   otherwise clear it. */
static inline void fix_generic_modifiers_by_device(NSUInteger* modifiers)
{
    if (*modifiers & (NX_DEVICELCMDKEYMASK | NX_DEVICERCMDKEYMASK))
        *modifiers |= NX_COMMANDMASK;
    else
        *modifiers &= ~NX_COMMANDMASK;
    if (*modifiers & (NX_DEVICELSHIFTKEYMASK | NX_DEVICERSHIFTKEYMASK))
        *modifiers |= NX_SHIFTMASK;
    else
        *modifiers &= ~NX_SHIFTMASK;
    if (*modifiers & (NX_DEVICELCTLKEYMASK | NX_DEVICERCTLKEYMASK))
        *modifiers |= NX_CONTROLMASK;
    else
        *modifiers &= ~NX_CONTROLMASK;
    if (*modifiers & (NX_DEVICELALTKEYMASK | NX_DEVICERALTKEYMASK))
        *modifiers |= NX_ALTERNATEMASK;
    else
        *modifiers &= ~NX_ALTERNATEMASK;
}


@interface WineContentView : NSView
@end


@interface WineWindow ()

@property (nonatomic) BOOL disabled;
@property (nonatomic) BOOL noActivate;
@property (readwrite, nonatomic) BOOL floating;
@property (retain, nonatomic) NSWindow* latentParentWindow;

@property (nonatomic) void* hwnd;
@property (retain, readwrite, nonatomic) WineEventQueue* queue;

@property (nonatomic) void* surface;
@property (nonatomic) pthread_mutex_t* surface_mutex;

@property (copy, nonatomic) NSBezierPath* shape;
@property (nonatomic) BOOL shapeChangedSinceLastDraw;
@property (readonly, nonatomic) BOOL needsTransparency;

@property (nonatomic) BOOL colorKeyed;
@property (nonatomic) CGFloat colorKeyRed, colorKeyGreen, colorKeyBlue;
@property (nonatomic) BOOL usePerPixelAlpha;

@property (readwrite, nonatomic) NSInteger levelWhenActive;

@end


@implementation WineContentView

    - (BOOL) isFlipped
    {
        return YES;
    }

    - (void) drawRect:(NSRect)rect
    {
        WineWindow* window = (WineWindow*)[self window];

        if (window.surface && window.surface_mutex &&
            !pthread_mutex_lock(window.surface_mutex))
        {
            const CGRect* rects;
            int count;

            if (!get_surface_region_rects(window.surface, &rects, &count) || count)
            {
                CGRect imageRect;
                CGImageRef image;

                imageRect = NSRectToCGRect(rect);
                image = create_surface_image(window.surface, &imageRect, FALSE);

                if (image)
                {
                    CGContextRef context;

                    if (rects && count)
                    {
                        NSBezierPath* surfaceClip = [NSBezierPath bezierPath];
                        int i;
                        for (i = 0; i < count; i++)
                            [surfaceClip appendBezierPathWithRect:NSRectFromCGRect(rects[i])];
                        [surfaceClip addClip];
                    }

                    [window.shape addClip];

                    if (window.colorKeyed)
                    {
                        CGImageRef maskedImage;
                        CGFloat components[] = { window.colorKeyRed - 0.5, window.colorKeyRed + 0.5,
                                                 window.colorKeyGreen - 0.5, window.colorKeyGreen + 0.5,
                                                 window.colorKeyBlue - 0.5, window.colorKeyBlue + 0.5 };
                        maskedImage = CGImageCreateWithMaskingColors(image, components);
                        if (maskedImage)
                        {
                            CGImageRelease(image);
                            image = maskedImage;
                        }
                    }

                    context = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
                    CGContextSetBlendMode(context, kCGBlendModeCopy);
                    CGContextDrawImage(context, imageRect, image);

                    CGImageRelease(image);

                    if (window.shapeChangedSinceLastDraw || window.colorKeyed ||
                        window.usePerPixelAlpha)
                    {
                        window.shapeChangedSinceLastDraw = FALSE;
                        [window invalidateShadow];
                    }
                }
            }

            pthread_mutex_unlock(window.surface_mutex);
        }
    }

    /* By default, NSView will swallow right-clicks in an attempt to support contextual
       menus.  We need to bypass that and allow the event to make it to the window. */
    - (void) rightMouseDown:(NSEvent*)theEvent
    {
        [[self window] rightMouseDown:theEvent];
    }

    - (BOOL) acceptsFirstMouse:(NSEvent*)theEvent
    {
        return YES;
    }

@end


@implementation WineWindow

    @synthesize disabled, noActivate, floating, latentParentWindow, hwnd, queue;
    @synthesize surface, surface_mutex;
    @synthesize shape, shapeChangedSinceLastDraw;
    @synthesize colorKeyed, colorKeyRed, colorKeyGreen, colorKeyBlue;
    @synthesize usePerPixelAlpha;
    @synthesize levelWhenActive;

    + (WineWindow*) createWindowWithFeatures:(const struct macdrv_window_features*)wf
                                 windowFrame:(NSRect)window_frame
                                        hwnd:(void*)hwnd
                                       queue:(WineEventQueue*)queue
    {
        WineWindow* window;
        WineContentView* contentView;
        NSTrackingArea* trackingArea;

        [NSApp flipRect:&window_frame];

        window = [[[self alloc] initWithContentRect:window_frame
                                          styleMask:style_mask_for_features(wf)
                                            backing:NSBackingStoreBuffered
                                              defer:YES] autorelease];

        if (!window) return nil;
        window->normalStyleMask = [window styleMask];

        /* Standardize windows to eliminate differences between titled and
           borderless windows and between NSWindow and NSPanel. */
        [window setHidesOnDeactivate:NO];
        [window setReleasedWhenClosed:NO];

        [window disableCursorRects];
        [window setShowsResizeIndicator:NO];
        [window setHasShadow:wf->shadow];
        [window setAcceptsMouseMovedEvents:YES];
        [window setColorSpace:[NSColorSpace genericRGBColorSpace]];
        [window setDelegate:window];
        window.hwnd = hwnd;
        window.queue = queue;

        contentView = [[[WineContentView alloc] initWithFrame:NSZeroRect] autorelease];
        if (!contentView)
            return nil;
        [contentView setAutoresizesSubviews:NO];

        /* We use tracking areas in addition to setAcceptsMouseMovedEvents:YES
           because they give us mouse moves in the background. */
        trackingArea = [[[NSTrackingArea alloc] initWithRect:[contentView bounds]
                                                     options:(NSTrackingMouseMoved |
                                                              NSTrackingActiveAlways |
                                                              NSTrackingInVisibleRect)
                                                       owner:window
                                                    userInfo:nil] autorelease];
        if (!trackingArea)
            return nil;
        [contentView addTrackingArea:trackingArea];

        [window setContentView:contentView];

        return window;
    }

    - (void) dealloc
    {
        [queue release];
        [latentParentWindow release];
        [shape release];
        [super dealloc];
    }

    - (void) adjustFeaturesForState
    {
        NSUInteger style = normalStyleMask;

        if (self.disabled)
            style &= ~NSResizableWindowMask;
        if (style != [self styleMask])
            [self setStyleMask:style];

        if (style & NSClosableWindowMask)
            [[self standardWindowButton:NSWindowCloseButton] setEnabled:!self.disabled];
        if (style & NSMiniaturizableWindowMask)
            [[self standardWindowButton:NSWindowMiniaturizeButton] setEnabled:!self.disabled];
    }

    - (void) setWindowFeatures:(const struct macdrv_window_features*)wf
    {
        normalStyleMask = style_mask_for_features(wf);
        [self adjustFeaturesForState];
        [self setHasShadow:wf->shadow];
    }

    - (void) adjustWindowLevel
    {
        NSInteger level;
        BOOL fullscreen, captured;
        NSScreen* screen;
        NSUInteger index;
        WineWindow* other = nil;

        screen = screen_covered_by_rect([self frame], [NSScreen screens]);
        fullscreen = (screen != nil);
        captured = (screen || [self screen]) && [NSApp areDisplaysCaptured];

        if (captured || fullscreen)
        {
            if (captured)
                level = CGShieldingWindowLevel() + 1; /* Need +1 or we don't get mouse moves */
            else
                level = NSMainMenuWindowLevel + 1;

            if (self.floating)
                level++;
        }
        else if (self.floating)
            level = NSFloatingWindowLevel;
        else
            level = NSNormalWindowLevel;

        index = [[NSApp orderedWineWindows] indexOfObjectIdenticalTo:self];
        if (index != NSNotFound && index + 1 < [[NSApp orderedWineWindows] count])
        {
            other = [[NSApp orderedWineWindows] objectAtIndex:index + 1];
            if (level < [other level])
                level = [other level];
        }

        if (level != [self level])
        {
            [self setLevelWhenActive:level];

            /* Setting the window level above has moved this window to the front
               of all other windows at the same level.  We need to move it
               back into its proper place among other windows of that level.
               Also, any windows which are supposed to be in front of it had
               better have the same or higher window level.  If not, bump them
               up. */
            if (index != NSNotFound)
            {
                for (; index > 0; index--)
                {
                    other = [[NSApp orderedWineWindows] objectAtIndex:index - 1];
                    if ([other level] < level)
                        [other setLevelWhenActive:level];
                    else
                    {
                        [self orderWindow:NSWindowBelow relativeTo:[other windowNumber]];
                        break;
                    }
                }
            }
        }
    }

    - (void) setMacDrvState:(const struct macdrv_window_state*)state
    {
        NSWindowCollectionBehavior behavior;

        self.disabled = state->disabled;
        self.noActivate = state->no_activate;

        self.floating = state->floating;
        [self adjustWindowLevel];

        behavior = NSWindowCollectionBehaviorDefault;
        if (state->excluded_by_expose)
            behavior |= NSWindowCollectionBehaviorTransient;
        else
            behavior |= NSWindowCollectionBehaviorManaged;
        if (state->excluded_by_cycle)
        {
            behavior |= NSWindowCollectionBehaviorIgnoresCycle;
            if ([self isVisible])
                [NSApp removeWindowsItem:self];
        }
        else
        {
            behavior |= NSWindowCollectionBehaviorParticipatesInCycle;
            if ([self isVisible])
                [NSApp addWindowsItem:self title:[self title] filename:NO];
        }
        [self setCollectionBehavior:behavior];

        if (state->minimized && ![self isMiniaturized])
        {
            ignore_windowMiniaturize = TRUE;
            [self miniaturize:nil];
        }
        else if (!state->minimized && [self isMiniaturized])
        {
            ignore_windowDeminiaturize = TRUE;
            [self deminiaturize:nil];
        }

        /* Whatever events regarding minimization might have been in the queue are now stale. */
        [queue discardEventsMatchingMask:event_mask_for_type(WINDOW_DID_MINIMIZE) |
                                         event_mask_for_type(WINDOW_DID_UNMINIMIZE)
                               forWindow:self];
    }

    /* Returns whether or not the window was ordered in, which depends on if
       its frame intersects any screen. */
    - (BOOL) orderBelow:(WineWindow*)prev orAbove:(WineWindow*)next
    {
        BOOL on_screen = frame_intersects_screens([self frame], [NSScreen screens]);
        if (on_screen)
        {
            [NSApp transformProcessToForeground];

            if (prev)
            {
                /* Make sure that windows that should be above this one really are.
                   This is necessary since a full-screen window gets a boost to its
                   window level to be in front of the menu bar and Dock and that moves
                   it out of the z-order that Win32 would otherwise establish. */
                if ([prev level] < [self level])
                {
                    NSUInteger index = [[NSApp orderedWineWindows] indexOfObjectIdenticalTo:prev];
                    if (index != NSNotFound)
                    {
                        [prev setLevelWhenActive:[self level]];
                        for (; index > 0; index--)
                        {
                            WineWindow* other = [[NSApp orderedWineWindows] objectAtIndex:index - 1];
                            if ([other level] < [self level])
                                [other setLevelWhenActive:[self level]];
                        }
                    }
                }
                [self orderWindow:NSWindowBelow relativeTo:[prev windowNumber]];
                [NSApp wineWindow:self ordered:NSWindowBelow relativeTo:prev];
            }
            else
            {
                /* Similarly, make sure this window is really above what it should be. */
                if (next && [next level] > [self level])
                    [self setLevelWhenActive:[next level]];
                [self orderWindow:NSWindowAbove relativeTo:[next windowNumber]];
                [NSApp wineWindow:self ordered:NSWindowAbove relativeTo:next];
            }
            if (latentParentWindow)
            {
                if ([latentParentWindow level] > [self level])
                    [self setLevelWhenActive:[latentParentWindow level]];
                [latentParentWindow addChildWindow:self ordered:NSWindowAbove];
                [NSApp wineWindow:self ordered:NSWindowAbove relativeTo:latentParentWindow];
                self.latentParentWindow = nil;
            }

            /* Cocoa may adjust the frame when the window is ordered onto the screen.
               Generate a frame-changed event just in case.  The back end will ignore
               it if nothing actually changed. */
            [self windowDidResize:nil];

            if (![self isExcludedFromWindowsMenu])
                [NSApp addWindowsItem:self title:[self title] filename:NO];
        }

        return on_screen;
    }

    - (void) doOrderOut
    {
        self.latentParentWindow = [self parentWindow];
        [latentParentWindow removeChildWindow:self];
        [self orderOut:nil];
        [NSApp wineWindow:self ordered:NSWindowOut relativeTo:nil];
        [NSApp removeWindowsItem:self];
    }

    - (BOOL) setFrameIfOnScreen:(NSRect)contentRect
    {
        NSArray* screens = [NSScreen screens];
        BOOL on_screen = [self isVisible];
        NSRect frame, oldFrame;

        if (![screens count]) return on_screen;

        /* Origin is (left, top) in a top-down space.  Need to convert it to
           (left, bottom) in a bottom-up space. */
        [NSApp flipRect:&contentRect];

        if (on_screen)
        {
            on_screen = frame_intersects_screens(contentRect, screens);
            if (!on_screen)
                [self doOrderOut];
        }

        if (!NSIsEmptyRect(contentRect))
        {
            oldFrame = [self frame];
            frame = [self frameRectForContentRect:contentRect];
            if (!NSEqualRects(frame, oldFrame))
            {
                if (NSEqualSizes(frame.size, oldFrame.size))
                    [self setFrameOrigin:frame.origin];
                else
                    [self setFrame:frame display:YES];
            }
        }

        if (on_screen)
        {
            [self adjustWindowLevel];

            /* In case Cocoa adjusted the frame we tried to set, generate a frame-changed
               event.  The back end will ignore it if nothing actually changed. */
            [self windowDidResize:nil];
        }
        else
        {
            /* The back end is establishing a new window size and position.  It's
               not interested in any stale events regarding those that may be sitting
               in the queue. */
            [queue discardEventsMatchingMask:event_mask_for_type(WINDOW_FRAME_CHANGED)
                                   forWindow:self];
        }

        return on_screen;
    }

    - (void) setMacDrvParentWindow:(WineWindow*)parent
    {
        if ([self parentWindow] != parent)
        {
            [[self parentWindow] removeChildWindow:self];
            self.latentParentWindow = nil;
            if ([self isVisible] && parent)
            {
                if ([parent level] > [self level])
                    [self setLevelWhenActive:[parent level]];
                [parent addChildWindow:self ordered:NSWindowAbove];
                [NSApp wineWindow:self ordered:NSWindowAbove relativeTo:parent];
            }
            else
                self.latentParentWindow = parent;
        }
    }

    - (void) setDisabled:(BOOL)newValue
    {
        if (disabled != newValue)
        {
            disabled = newValue;
            [self adjustFeaturesForState];
        }
    }

    - (BOOL) needsTransparency
    {
        return self.shape || self.colorKeyed || self.usePerPixelAlpha;
    }

    - (void) checkTransparency
    {
        if (![self isOpaque] && !self.needsTransparency)
        {
            [self setBackgroundColor:[NSColor windowBackgroundColor]];
            [self setOpaque:YES];
        }
        else if ([self isOpaque] && self.needsTransparency)
        {
            [self setBackgroundColor:[NSColor clearColor]];
            [self setOpaque:NO];
        }
    }

    - (void) setShape:(NSBezierPath*)newShape
    {
        if (shape == newShape) return;
        if (shape && newShape && [shape isEqual:newShape]) return;

        if (shape)
        {
            [[self contentView] setNeedsDisplayInRect:[shape bounds]];
            [shape release];
        }
        if (newShape)
            [[self contentView] setNeedsDisplayInRect:[newShape bounds]];

        shape = [newShape copy];
        self.shapeChangedSinceLastDraw = TRUE;

        [self checkTransparency];
    }

    - (void) postMouseButtonEvent:(NSEvent *)theEvent pressed:(int)pressed
    {
        CGPoint pt = CGEventGetLocation([theEvent CGEvent]);
        macdrv_event event;

        event.type = MOUSE_BUTTON;
        event.window = (macdrv_window)[self retain];
        event.mouse_button.button = [theEvent buttonNumber];
        event.mouse_button.pressed = pressed;
        event.mouse_button.x = pt.x;
        event.mouse_button.y = pt.y;
        event.mouse_button.time_ms = [NSApp ticksForEventTime:[theEvent timestamp]];

        [queue postEvent:&event];
    }

    - (void) makeFocused
    {
        NSArray* screens;

        [NSApp transformProcessToForeground];

        /* If a borderless window is offscreen, orderFront: won't move
           it onscreen like it would for a titled window.  Do that ourselves. */
        screens = [NSScreen screens];
        if (!([self styleMask] & NSTitledWindowMask) && ![self isVisible] &&
            !frame_intersects_screens([self frame], screens))
        {
            NSScreen* primaryScreen = [screens objectAtIndex:0];
            NSRect frame = [primaryScreen frame];
            [self setFrameTopLeftPoint:NSMakePoint(NSMinX(frame), NSMaxY(frame))];
            frame = [self constrainFrameRect:[self frame] toScreen:primaryScreen];
            [self setFrame:frame display:YES];
        }

        if ([[NSApp orderedWineWindows] count])
        {
            WineWindow* front;
            if (self.floating)
                front = [[NSApp orderedWineWindows] objectAtIndex:0];
            else
            {
                for (front in [NSApp orderedWineWindows])
                    if (!front.floating) break;
            }
            if (front && [front levelWhenActive] > [self levelWhenActive])
                [self setLevelWhenActive:[front levelWhenActive]];
        }
        [self orderFront:nil];
        [NSApp wineWindow:self ordered:NSWindowAbove relativeTo:nil];
        causing_becomeKeyWindow = TRUE;
        [self makeKeyWindow];
        causing_becomeKeyWindow = FALSE;
        if (latentParentWindow)
        {
            if ([latentParentWindow level] > [self level])
                [self setLevelWhenActive:[latentParentWindow level]];
            [latentParentWindow addChildWindow:self ordered:NSWindowAbove];
            [NSApp wineWindow:self ordered:NSWindowAbove relativeTo:latentParentWindow];
            self.latentParentWindow = nil;
        }
        if (![self isExcludedFromWindowsMenu])
            [NSApp addWindowsItem:self title:[self title] filename:NO];

        /* Cocoa may adjust the frame when the window is ordered onto the screen.
           Generate a frame-changed event just in case.  The back end will ignore
           it if nothing actually changed. */
        [self windowDidResize:nil];
    }

    - (void) postKey:(uint16_t)keyCode
             pressed:(BOOL)pressed
           modifiers:(NSUInteger)modifiers
               event:(NSEvent*)theEvent
    {
        macdrv_event event;
        CGEventRef cgevent;
        WineApplication* app = (WineApplication*)NSApp;

        event.type          = pressed ? KEY_PRESS : KEY_RELEASE;
        event.window        = (macdrv_window)[self retain];
        event.key.keycode   = keyCode;
        event.key.modifiers = modifiers;
        event.key.time_ms   = [app ticksForEventTime:[theEvent timestamp]];

        if ((cgevent = [theEvent CGEvent]))
        {
            CGEventSourceKeyboardType keyboardType = CGEventGetIntegerValueField(cgevent,
                                                        kCGKeyboardEventKeyboardType);
            if (keyboardType != app.keyboardType)
            {
                app.keyboardType = keyboardType;
                [app keyboardSelectionDidChange];
            }
        }

        [queue postEvent:&event];
    }

    - (void) postKeyEvent:(NSEvent *)theEvent
    {
        [self flagsChanged:theEvent];
        [self postKey:[theEvent keyCode]
              pressed:[theEvent type] == NSKeyDown
            modifiers:[theEvent modifierFlags]
                event:theEvent];
    }

    - (void) postMouseMovedEvent:(NSEvent *)theEvent absolute:(BOOL)absolute
    {
        macdrv_event event;

        if (absolute)
        {
            CGPoint point = CGEventGetLocation([theEvent CGEvent]);

            event.type = MOUSE_MOVED_ABSOLUTE;
            event.mouse_moved.x = point.x;
            event.mouse_moved.y = point.y;

            mouseMoveDeltaX = 0;
            mouseMoveDeltaY = 0;
        }
        else
        {
            /* Add event delta to accumulated delta error */
            /* deltaY is already flipped */
            mouseMoveDeltaX += [theEvent deltaX];
            mouseMoveDeltaY += [theEvent deltaY];

            event.type = MOUSE_MOVED;
            event.mouse_moved.x = mouseMoveDeltaX;
            event.mouse_moved.y = mouseMoveDeltaY;

            /* Keep the remainder after integer truncation. */
            mouseMoveDeltaX -= event.mouse_moved.x;
            mouseMoveDeltaY -= event.mouse_moved.y;
        }

        if (event.type == MOUSE_MOVED_ABSOLUTE || event.mouse_moved.x || event.mouse_moved.y)
        {
            event.window = (macdrv_window)[self retain];
            event.mouse_moved.time_ms = [NSApp ticksForEventTime:[theEvent timestamp]];

            [queue postEvent:&event];
        }
    }

    - (void) setLevelWhenActive:(NSInteger)level
    {
        levelWhenActive = level;
        if (([NSApp isActive] || level <= NSFloatingWindowLevel) &&
            level != [self level])
            [self setLevel:level];
    }


    /*
     * ---------- NSWindow method overrides ----------
     */
    - (BOOL) canBecomeKeyWindow
    {
        if (causing_becomeKeyWindow) return YES;
        if (self.disabled || self.noActivate) return NO;
        return [self isKeyWindow];
    }

    - (BOOL) canBecomeMainWindow
    {
        return [self canBecomeKeyWindow];
    }

    - (NSRect) constrainFrameRect:(NSRect)frameRect toScreen:(NSScreen *)screen
    {
        // If a window is sized to completely cover a screen, then it's in
        // full-screen mode.  In that case, we don't allow NSWindow to constrain
        // it.
        NSRect contentRect = [self contentRectForFrameRect:frameRect];
        if (!screen_covered_by_rect(contentRect, [NSScreen screens]))
            frameRect = [super constrainFrameRect:frameRect toScreen:screen];
        return frameRect;
    }

    - (BOOL) isExcludedFromWindowsMenu
    {
        return !([self collectionBehavior] & NSWindowCollectionBehaviorParticipatesInCycle);
    }

    - (BOOL) validateMenuItem:(NSMenuItem *)menuItem
    {
        if ([menuItem action] == @selector(makeKeyAndOrderFront:))
            return [self isKeyWindow] || (!self.disabled && !self.noActivate);
        return [super validateMenuItem:menuItem];
    }

    /* We don't call this.  It's the action method of the items in the Window menu. */
    - (void) makeKeyAndOrderFront:(id)sender
    {
        if (![self isKeyWindow] && !self.disabled && !self.noActivate)
            [NSApp windowGotFocus:self];
    }

    - (void) sendEvent:(NSEvent*)event
    {
        /* NSWindow consumes certain key-down events as part of Cocoa's keyboard
           interface control.  For example, Control-Tab switches focus among
           views.  We want to bypass that feature, so directly route key-down
           events to -keyDown:. */
        if ([event type] == NSKeyDown)
            [[self firstResponder] keyDown:event];
        else
        {
            if ([event type] == NSLeftMouseDown)
            {
                NSWindowButton windowButton;
                BOOL broughtWindowForward = TRUE;

                /* Since our windows generally claim they can't be made key, clicks
                   in their title bars are swallowed by the theme frame stuff.  So,
                   we hook directly into the event stream and assume that any click
                   in the window will activate it, if Wine and the Win32 program
                   accept. */
                if (![self isKeyWindow] && !self.disabled && !self.noActivate)
                    [NSApp windowGotFocus:self];

                /* Any left-click on our window anyplace other than the close or
                   minimize buttons will bring it forward. */
                for (windowButton = NSWindowCloseButton;
                     windowButton <= NSWindowMiniaturizeButton;
                     windowButton++)
                {
                    NSButton* button = [[event window] standardWindowButton:windowButton];
                    if (button)
                    {
                        NSPoint point = [button convertPoint:[event locationInWindow] fromView:nil];
                        if ([button mouse:point inRect:[button bounds]])
                        {
                            broughtWindowForward = FALSE;
                            break;
                        }
                    }
                }

                if (broughtWindowForward)
                    [NSApp wineWindow:self ordered:NSWindowAbove relativeTo:nil];
            }

            [super sendEvent:event];
        }
    }


    /*
     * ---------- NSResponder method overrides ----------
     */
    - (void) mouseDown:(NSEvent *)theEvent { [self postMouseButtonEvent:theEvent pressed:1]; }
    - (void) rightMouseDown:(NSEvent *)theEvent { [self mouseDown:theEvent]; }
    - (void) otherMouseDown:(NSEvent *)theEvent { [self mouseDown:theEvent]; }

    - (void) mouseUp:(NSEvent *)theEvent { [self postMouseButtonEvent:theEvent pressed:0]; }
    - (void) rightMouseUp:(NSEvent *)theEvent { [self mouseUp:theEvent]; }
    - (void) otherMouseUp:(NSEvent *)theEvent { [self mouseUp:theEvent]; }

    - (void) keyDown:(NSEvent *)theEvent { [self postKeyEvent:theEvent]; }
    - (void) keyUp:(NSEvent *)theEvent   { [self postKeyEvent:theEvent]; }

    - (void) flagsChanged:(NSEvent *)theEvent
    {
        static const struct {
            NSUInteger  mask;
            uint16_t    keycode;
        } modifiers[] = {
            { NX_ALPHASHIFTMASK,        kVK_CapsLock },
            { NX_DEVICELSHIFTKEYMASK,   kVK_Shift },
            { NX_DEVICERSHIFTKEYMASK,   kVK_RightShift },
            { NX_DEVICELCTLKEYMASK,     kVK_Control },
            { NX_DEVICERCTLKEYMASK,     kVK_RightControl },
            { NX_DEVICELALTKEYMASK,     kVK_Option },
            { NX_DEVICERALTKEYMASK,     kVK_RightOption },
            { NX_DEVICELCMDKEYMASK,     kVK_Command },
            { NX_DEVICERCMDKEYMASK,     kVK_RightCommand },
        };

        NSUInteger modifierFlags = [theEvent modifierFlags];
        NSUInteger changed;
        int i, last_changed;

        fix_device_modifiers_by_generic(&modifierFlags);
        changed = modifierFlags ^ lastModifierFlags;

        last_changed = -1;
        for (i = 0; i < sizeof(modifiers)/sizeof(modifiers[0]); i++)
            if (changed & modifiers[i].mask)
                last_changed = i;

        for (i = 0; i <= last_changed; i++)
        {
            if (changed & modifiers[i].mask)
            {
                BOOL pressed = (modifierFlags & modifiers[i].mask) != 0;

                if (i == last_changed)
                    lastModifierFlags = modifierFlags;
                else
                {
                    lastModifierFlags ^= modifiers[i].mask;
                    fix_generic_modifiers_by_device(&lastModifierFlags);
                }

                // Caps lock generates one event for each press-release action.
                // We need to simulate a pair of events for each actual event.
                if (modifiers[i].mask == NX_ALPHASHIFTMASK)
                {
                    [self postKey:modifiers[i].keycode
                          pressed:TRUE
                        modifiers:lastModifierFlags
                            event:(NSEvent*)theEvent];
                    pressed = FALSE;
                }

                [self postKey:modifiers[i].keycode
                      pressed:pressed
                    modifiers:lastModifierFlags
                        event:(NSEvent*)theEvent];
            }
        }
    }

    - (void) scrollWheel:(NSEvent *)theEvent
    {
        CGPoint pt;
        macdrv_event event;
        CGEventRef cgevent;
        CGFloat x, y;
        BOOL continuous = FALSE;

        cgevent = [theEvent CGEvent];
        pt = CGEventGetLocation(cgevent);

        event.type = MOUSE_SCROLL;
        event.window = (macdrv_window)[self retain];
        event.mouse_scroll.x = pt.x;
        event.mouse_scroll.y = pt.y;
        event.mouse_scroll.time_ms = [NSApp ticksForEventTime:[theEvent timestamp]];

        if (CGEventGetIntegerValueField(cgevent, kCGScrollWheelEventIsContinuous))
        {
            continuous = TRUE;

            /* Continuous scroll wheel events come from high-precision scrolling
               hardware like Apple's Magic Mouse, Mighty Mouse, and trackpads.
               For these, we can get more precise data from the CGEvent API. */
            /* Axis 1 is vertical, axis 2 is horizontal. */
            x = CGEventGetDoubleValueField(cgevent, kCGScrollWheelEventPointDeltaAxis2);
            y = CGEventGetDoubleValueField(cgevent, kCGScrollWheelEventPointDeltaAxis1);
        }
        else
        {
            double pixelsPerLine = 10;
            CGEventSourceRef source;

            /* The non-continuous values are in units of "lines", not pixels. */
            if ((source = CGEventCreateSourceFromEvent(cgevent)))
            {
                pixelsPerLine = CGEventSourceGetPixelsPerLine(source);
                CFRelease(source);
            }

            x = pixelsPerLine * [theEvent deltaX];
            y = pixelsPerLine * [theEvent deltaY];
        }

        /* Mac: negative is right or down, positive is left or up.
           Win32: negative is left or down, positive is right or up.
           So, negate the X scroll value to translate. */
        x = -x;

        /* The x,y values so far are in pixels.  Win32 expects to receive some
           fraction of WHEEL_DELTA == 120.  By my estimation, that's roughly
           6 times the pixel value. */
        event.mouse_scroll.x_scroll = 6 * x;
        event.mouse_scroll.y_scroll = 6 * y;

        if (!continuous)
        {
            /* For non-continuous "clicky" wheels, if there was any motion, make
               sure there was at least WHEEL_DELTA motion.  This is so, at slow
               speeds where the system's acceleration curve is actually reducing the
               scroll distance, the user is sure to get some action out of each click.
               For example, this is important for rotating though weapons in a
               first-person shooter. */
            if (0 < event.mouse_scroll.x_scroll && event.mouse_scroll.x_scroll < 120)
                event.mouse_scroll.x_scroll = 120;
            else if (-120 < event.mouse_scroll.x_scroll && event.mouse_scroll.x_scroll < 0)
                event.mouse_scroll.x_scroll = -120;

            if (0 < event.mouse_scroll.y_scroll && event.mouse_scroll.y_scroll < 120)
                event.mouse_scroll.y_scroll = 120;
            else if (-120 < event.mouse_scroll.y_scroll && event.mouse_scroll.y_scroll < 0)
                event.mouse_scroll.y_scroll = -120;
        }

        if (event.mouse_scroll.x_scroll || event.mouse_scroll.y_scroll)
            [queue postEvent:&event];
    }


    /*
     * ---------- NSWindowDelegate methods ----------
     */
    - (void)windowDidBecomeKey:(NSNotification *)notification
    {
        NSEvent* event = [NSApp lastFlagsChanged];
        if (event)
            [self flagsChanged:event];

        if (causing_becomeKeyWindow) return;

        [NSApp windowGotFocus:self];
    }

    - (void)windowDidDeminiaturize:(NSNotification *)notification
    {
        if (!ignore_windowDeminiaturize)
        {
            macdrv_event event;

            /* Coalesce events by discarding any previous ones still in the queue. */
            [queue discardEventsMatchingMask:event_mask_for_type(WINDOW_DID_MINIMIZE) |
                                             event_mask_for_type(WINDOW_DID_UNMINIMIZE)
                                   forWindow:self];

            event.type = WINDOW_DID_UNMINIMIZE;
            event.window = (macdrv_window)[self retain];
            [queue postEvent:&event];
        }

        ignore_windowDeminiaturize = FALSE;

        [NSApp wineWindow:self ordered:NSWindowAbove relativeTo:nil];
    }

    - (void)windowDidMove:(NSNotification *)notification
    {
        [self windowDidResize:notification];
    }

    - (void)windowDidResignKey:(NSNotification *)notification
    {
        macdrv_event event;

        if (causing_becomeKeyWindow) return;

        event.type = WINDOW_LOST_FOCUS;
        event.window = (macdrv_window)[self retain];
        [queue postEvent:&event];
    }

    - (void)windowDidResize:(NSNotification *)notification
    {
        macdrv_event event;
        NSRect frame = [self contentRectForFrameRect:[self frame]];

        [NSApp flipRect:&frame];

        /* Coalesce events by discarding any previous ones still in the queue. */
        [queue discardEventsMatchingMask:event_mask_for_type(WINDOW_FRAME_CHANGED)
                               forWindow:self];

        event.type = WINDOW_FRAME_CHANGED;
        event.window = (macdrv_window)[self retain];
        event.window_frame_changed.frame = NSRectToCGRect(frame);
        [queue postEvent:&event];
    }

    - (BOOL)windowShouldClose:(id)sender
    {
        macdrv_event event;
        event.type = WINDOW_CLOSE_REQUESTED;
        event.window = (macdrv_window)[self retain];
        [queue postEvent:&event];
        return NO;
    }

    - (void)windowWillMiniaturize:(NSNotification *)notification
    {
        if (!ignore_windowMiniaturize)
        {
            macdrv_event event;

            /* Coalesce events by discarding any previous ones still in the queue. */
            [queue discardEventsMatchingMask:event_mask_for_type(WINDOW_DID_MINIMIZE) |
                                             event_mask_for_type(WINDOW_DID_UNMINIMIZE)
                                   forWindow:self];

            event.type = WINDOW_DID_MINIMIZE;
            event.window = (macdrv_window)[self retain];
            [queue postEvent:&event];
        }

        ignore_windowMiniaturize = FALSE;
    }

@end


/***********************************************************************
 *              macdrv_create_cocoa_window
 *
 * Create a Cocoa window with the given content frame and features (e.g.
 * title bar, close box, etc.).
 */
macdrv_window macdrv_create_cocoa_window(const struct macdrv_window_features* wf,
        CGRect frame, void* hwnd, macdrv_event_queue queue)
{
    __block WineWindow* window;

    OnMainThread(^{
        window = [[WineWindow createWindowWithFeatures:wf
                                           windowFrame:NSRectFromCGRect(frame)
                                                  hwnd:hwnd
                                                 queue:(WineEventQueue*)queue] retain];
    });

    return (macdrv_window)window;
}

/***********************************************************************
 *              macdrv_destroy_cocoa_window
 *
 * Destroy a Cocoa window.
 */
void macdrv_destroy_cocoa_window(macdrv_window w)
{
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    WineWindow* window = (WineWindow*)w;

    [window.queue discardEventsMatchingMask:-1 forWindow:window];
    [window close];
    [window release];

    [pool release];
}

/***********************************************************************
 *              macdrv_get_window_hwnd
 *
 * Get the hwnd that was set for the window at creation.
 */
void* macdrv_get_window_hwnd(macdrv_window w)
{
    WineWindow* window = (WineWindow*)w;
    return window.hwnd;
}

/***********************************************************************
 *              macdrv_set_cocoa_window_features
 *
 * Update a Cocoa window's features.
 */
void macdrv_set_cocoa_window_features(macdrv_window w,
        const struct macdrv_window_features* wf)
{
    WineWindow* window = (WineWindow*)w;

    OnMainThread(^{
        [window setWindowFeatures:wf];
    });
}

/***********************************************************************
 *              macdrv_set_cocoa_window_state
 *
 * Update a Cocoa window's state.
 */
void macdrv_set_cocoa_window_state(macdrv_window w,
        const struct macdrv_window_state* state)
{
    WineWindow* window = (WineWindow*)w;

    OnMainThread(^{
        [window setMacDrvState:state];
    });
}

/***********************************************************************
 *              macdrv_set_cocoa_window_title
 *
 * Set a Cocoa window's title.
 */
void macdrv_set_cocoa_window_title(macdrv_window w, const unsigned short* title,
        size_t length)
{
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    WineWindow* window = (WineWindow*)w;
    NSString* titleString;

    if (title)
        titleString = [NSString stringWithCharacters:title length:length];
    else
        titleString = @"";
    OnMainThreadAsync(^{
        [window setTitle:titleString];
        if ([window isVisible] && ![window isExcludedFromWindowsMenu])
            [NSApp changeWindowsItem:window title:titleString filename:NO];
    });

    [pool release];
}

/***********************************************************************
 *              macdrv_order_cocoa_window
 *
 * Reorder a Cocoa window relative to other windows.  If prev is
 * non-NULL, it is ordered below that window.  Else, if next is non-NULL,
 * it is ordered above that window.  Otherwise, it is ordered to the
 * front.
 *
 * Returns true if the window has actually been ordered onto the screen
 * (i.e. if its frame intersects with a screen).  Otherwise, false.
 */
int macdrv_order_cocoa_window(macdrv_window w, macdrv_window prev,
        macdrv_window next)
{
    WineWindow* window = (WineWindow*)w;
    __block BOOL on_screen;

    OnMainThread(^{
        on_screen = [window orderBelow:(WineWindow*)prev
                               orAbove:(WineWindow*)next];
    });

    return on_screen;
}

/***********************************************************************
 *              macdrv_hide_cocoa_window
 *
 * Hides a Cocoa window.
 */
void macdrv_hide_cocoa_window(macdrv_window w)
{
    WineWindow* window = (WineWindow*)w;

    OnMainThread(^{
        [window doOrderOut];
    });
}

/***********************************************************************
 *              macdrv_set_cocoa_window_frame
 *
 * Move a Cocoa window.  If the window has been moved out of the bounds
 * of the desktop, it is ordered out.  (This routine won't ever order a
 * window in, though.)
 *
 * Returns true if the window is on screen; false otherwise.
 */
int macdrv_set_cocoa_window_frame(macdrv_window w, const CGRect* new_frame)
{
    WineWindow* window = (WineWindow*)w;
    __block BOOL on_screen;

    OnMainThread(^{
        on_screen = [window setFrameIfOnScreen:NSRectFromCGRect(*new_frame)];
    });

    return on_screen;
}

/***********************************************************************
 *              macdrv_get_cocoa_window_frame
 *
 * Gets the frame of a Cocoa window.
 */
void macdrv_get_cocoa_window_frame(macdrv_window w, CGRect* out_frame)
{
    WineWindow* window = (WineWindow*)w;

    OnMainThread(^{
        NSRect frame;

        frame = [window contentRectForFrameRect:[window frame]];
        [NSApp flipRect:&frame];
        *out_frame = NSRectToCGRect(frame);
    });
}

/***********************************************************************
 *              macdrv_set_cocoa_parent_window
 *
 * Sets the parent window for a Cocoa window.  If parent is NULL, clears
 * the parent window.
 */
void macdrv_set_cocoa_parent_window(macdrv_window w, macdrv_window parent)
{
    WineWindow* window = (WineWindow*)w;

    OnMainThread(^{
        [window setMacDrvParentWindow:(WineWindow*)parent];
    });
}

/***********************************************************************
 *              macdrv_set_window_surface
 */
void macdrv_set_window_surface(macdrv_window w, void *surface, pthread_mutex_t *mutex)
{
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    WineWindow* window = (WineWindow*)w;

    OnMainThread(^{
        window.surface = surface;
        window.surface_mutex = mutex;
    });

    [pool release];
}

/***********************************************************************
 *              macdrv_window_needs_display
 *
 * Mark a window as needing display in a specified rect (in non-client
 * area coordinates).
 */
void macdrv_window_needs_display(macdrv_window w, CGRect rect)
{
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    WineWindow* window = (WineWindow*)w;

    OnMainThreadAsync(^{
        [[window contentView] setNeedsDisplayInRect:NSRectFromCGRect(rect)];
    });

    [pool release];
}

/***********************************************************************
 *              macdrv_set_window_shape
 *
 * Sets the shape of a Cocoa window from an array of rectangles.  If
 * rects is NULL, resets the window's shape to its frame.
 */
void macdrv_set_window_shape(macdrv_window w, const CGRect *rects, int count)
{
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    WineWindow* window = (WineWindow*)w;

    OnMainThread(^{
        if (!rects || !count)
            window.shape = nil;
        else
        {
            NSBezierPath* path;
            unsigned int i;

            path = [NSBezierPath bezierPath];
            for (i = 0; i < count; i++)
                [path appendBezierPathWithRect:NSRectFromCGRect(rects[i])];
            window.shape = path;
        }
    });

    [pool release];
}

/***********************************************************************
 *              macdrv_set_window_alpha
 */
void macdrv_set_window_alpha(macdrv_window w, CGFloat alpha)
{
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    WineWindow* window = (WineWindow*)w;

    [window setAlphaValue:alpha];

    [pool release];
}

/***********************************************************************
 *              macdrv_set_window_color_key
 */
void macdrv_set_window_color_key(macdrv_window w, CGFloat keyRed, CGFloat keyGreen,
                                 CGFloat keyBlue)
{
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    WineWindow* window = (WineWindow*)w;

    OnMainThread(^{
        window.colorKeyed       = TRUE;
        window.colorKeyRed      = keyRed;
        window.colorKeyGreen    = keyGreen;
        window.colorKeyBlue     = keyBlue;
        [window checkTransparency];
    });

    [pool release];
}

/***********************************************************************
 *              macdrv_clear_window_color_key
 */
void macdrv_clear_window_color_key(macdrv_window w)
{
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    WineWindow* window = (WineWindow*)w;

    OnMainThread(^{
        window.colorKeyed = FALSE;
        [window checkTransparency];
    });

    [pool release];
}

/***********************************************************************
 *              macdrv_window_use_per_pixel_alpha
 */
void macdrv_window_use_per_pixel_alpha(macdrv_window w, int use_per_pixel_alpha)
{
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    WineWindow* window = (WineWindow*)w;

    OnMainThread(^{
        window.usePerPixelAlpha = use_per_pixel_alpha;
        [window checkTransparency];
    });

    [pool release];
}

/***********************************************************************
 *              macdrv_give_cocoa_window_focus
 *
 * Makes the Cocoa window "key" (gives it keyboard focus).  This also
 * orders it front and, if its frame was not within the desktop bounds,
 * Cocoa will typically move it on-screen.
 */
void macdrv_give_cocoa_window_focus(macdrv_window w)
{
    WineWindow* window = (WineWindow*)w;

    OnMainThread(^{
        [window makeFocused];
    });
}
