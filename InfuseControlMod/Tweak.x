// InfuseControlMod
// Stops the player controls (overlay) from auto-appearing when a collection /
// playlist auto-advances to the next video. Manual taps to show the controls,
// and the first video you open, are left untouched.
//
// How it works (classes/selectors confirmed by class-dumping Infuse 8):
//   - The player screen is `FCVideoViewController`.
//   - Each time a new item begins, it calls
//       -[FCVideoViewController updateControlPanelToPlayItem:changedItem:]
//     which pushes `setPlayerState:` into the control panel's model and makes
//     the overlay appear.
//   - The overlay itself is a UIView<FCVideoControlPanelProtocol>, reachable
//     via -[FCVideoViewController controlPanel], and it responds to
//       -setControlsHidden:animated:
//
// Strategy: after each *item change*, if the user has NOT touched the screen in
// the last `kTouchWindow` seconds, we force the overlay hidden immediately.
//   - Auto-advance to the next item  -> no recent touch  -> overlay stays hidden.
//   - You tapping the "Next" button    -> recent touch     -> overlay left alone.
//   - The very first item of a session -> left alone (so a normal single video
//     still shows its controls briefly on open).
//
// We go through the app's own -setControlsHidden:animated: so the control
// model's internal state stays consistent (no desync with tap-to-toggle).

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

// --- Tunables -------------------------------------------------------------
// If a touch happened within this many seconds before the item changed, we
// treat the change as user-initiated and leave the controls alone.
static const CFTimeInterval kTouchWindow = 1.5;
// Set to NO if you also want the very first video of a session to open with
// its controls already hidden.
static const BOOL kLeaveFirstItemAlone = YES;
// -------------------------------------------------------------------------

static CFTimeInterval gLastTouch = 0;

@interface FCVideoViewController : UIViewController
- (id)controlPanel;
// Backing storage is provided by %property in the %hook below; declaring it
// here lets the dot-syntax type-check under ARC.
@property (nonatomic, assign) BOOL icm_hasPlayedItem;
@end

@protocol _ICM_Panel
- (void)setControlsHidden:(BOOL)hidden animated:(BOOL)animated;
@end

%hook UIWindow
- (void)sendEvent:(UIEvent *)event {
    if (event.type == UIEventTypeTouches) {
        gLastTouch = CACurrentMediaTime();
    }
    %orig;
}
%end

%hook FCVideoViewController

%property (nonatomic, assign) BOOL icm_hasPlayedItem;

- (void)updateControlPanelToPlayItem:(id)item changedItem:(BOOL)changedItem {
    %orig;

    if (!changedItem) return;

    BOOL firstItem = !self.icm_hasPlayedItem;
    self.icm_hasPlayedItem = YES;
    if (firstItem && kLeaveFirstItemAlone) return;

    // User just interacted (e.g. tapped the Next button) -> keep controls up.
    if (CACurrentMediaTime() - gLastTouch < kTouchWindow) return;

    // Auto-advance: hide the overlay right away.
    id panel = [self controlPanel];
    if ([panel respondsToSelector:@selector(setControlsHidden:animated:)]) {
        [(id<_ICM_Panel>)panel setControlsHidden:YES animated:NO];
    }
}

%end
