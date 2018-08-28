# Interacting with Nebula

Out of the box, Nebula does not offer toggles for all browsers. However, other tweaks can interact with Nebula. This means that developers can write add-ons that allow use in more browsers.

The `NBLBroadcaster` class provides a few basic features that are necessary for writing such add-ons. (Reading and toggling dark mode at the time of this writing.) The class is part of Nebula, so it can be used on any device with Nebula installed, and you do not need to download extra files.

## Use

You can use `NBLBroadcaster` in any process where Nebula is running. When Nebula is *not* running, using the class will cause a crash. Therefore, you should be careful to check for the class before you use it.

You also need to interface the class before using it.

```objc

@interface NBLBroadcaster
+(NBLBroadcaster *)sharedBroadcaster;
-(BOOL)darkModeEnabled;
-(void)toggleDarkmode:(BOOL)dark;
-(void)forceToggleDarkmode:(BOOL)dark;

@end

```

Toggling darkmode with `toggleDarkmode:` will only work when a web view is visible. If a web view is not visible, use `forceToggleDarkmode:`, which has *almost* the same effect. The only difference is that the effect of `forceToggleDarkmode:` will only be seen when a new web view is created or is interacted with for the first time.

### Example

```objc

//when something happens that will use NBLBroadcaster
-(void)workMajek {
	//quit if Nebula is disabled in this app
	if(![%c(NBLBroadcaster) class]) return;
	//turn on dark mode
	[[%c(NBLBroadcaster) sharedBroadcaster] toggleDarkmode:YES];
}

```

Note that NBLBroadcaster is a singleton class, and is made to crash with the exception *"Multiple instances of NBLBroadcaster cannot be created"* when you attempt to create a new instance. Always use `[%c(NBLBroadcaster) sharedBroadcaster] `.
