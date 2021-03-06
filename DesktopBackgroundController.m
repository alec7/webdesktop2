#import "DesktopBackgroundController.h"
#import "DesktopBackgroundWindow.h"
#import <Carbon/Carbon.h>

@implementation DesktopBackgroundController

- (NSWindow*)downloadWindowForAuthenticationSheet:(WebDownload*)download;
{
	[NSApp activateIgnoringOtherApps:YES];
	return window;
}


- (NSURL*)formatURL:(NSURL*)inURL
{
	NSMutableString* url;

	if ( inURL == nil )
		return nil;

	url = [NSMutableString stringWithString:[inURL absoluteString]];

	if( [inURL path] == nil || [[inURL path] length] == 0  )
	{
		[url appendString:@"/"];

		if( [inURL scheme] == nil )
			[url insertString:@"http://" atIndex:0];

		return [NSURL URLWithString:url];
	}
	else
	if( [[[inURL path] pathExtension] length] == 0 )
	{
		if( ![url hasSuffix:@"/"] )
			[url appendString:@"/"];

		inURL = [NSURL URLWithString:url];
	}

	return [NSURL URLWithString:[inURL absoluteString]];
}


- (IBAction)goBack:(id)sender
{
	[webView goBack];
}


- (void)goForward:(id)inSender
{
	[webView goForward];
}

- (void)loadURL:(NSURL*)inURL
{
	[location autorelease];
	location = [self formatURL:inURL];

	if ( location )
	{
		[location retain];

		NSString* ua = [webView userAgentForURL:inURL];
		if ( ua )
		{
			NSScanner* scanner = [NSScanner scannerWithString:ua];
			if ( scanner )
			{
				[scanner scanUpToString:@"AppleWebKit/" intoString:nil];
				[scanner scanString:@"AppleWebKit/" intoString:nil];

				NSString* webKitVersion = nil;
				[scanner scanUpToString:@" " intoString:&webKitVersion];

				if ( webKitVersion )
				{
					[webView setApplicationNameForUserAgent:[NSString
										stringWithFormat:@"Safari/%@ (WebDesktop)", webKitVersion]]; // fix for Google Maps API javascript sniffer
				}
			}
		}

		[[NSUserDefaults standardUserDefaults] setObject:[inURL absoluteString] forKey:@"LastURL"];
		[[NSUserDefaults standardUserDefaults] synchronize];

		WebFrame* mainFrame = [webView mainFrame];
        [mainFrame stopLoading];
		[mainFrame loadRequest:[NSURLRequest requestWithURL:location]];

	}

	[window makeFirstResponder:webView];
}

- (void)refresh
{
	[[webView mainFrame] reload];
}


- (void)refreshTimerFired:(NSTimer*)inTimer
{
	[self refresh];
}


- (BOOL)validateMenuItem:(NSMenuItem*)item
{
	if ( [item action] == @selector(goBack:) )
		return [webView canGoBack];

	if ( [item action] == @selector(goForward:) )
		return [webView canGoForward];

	return YES;
}


- (void)webView:(WebView *)sender decidePolicyForNewWindowAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request newFrameName:(NSString *)frameName decisionListener:(id<WebPolicyDecisionListener>)listener
{
	[cachedRequest release];
	cachedRequest = [request copy];
	[listener use];
}


- (WebView*)webView:(WebView*)sender createWebViewWithRequest:(NSURLRequest*)request
{
	if ( request == nil )
		request = cachedRequest;

	[[NSWorkspace sharedWorkspace] openURL:[request URL]];

	[cachedRequest release];
	cachedRequest = nil;

	return nil;
}


- (void)webView:(WebView *)sender runJavaScriptAlertPanelWithMessage:(NSString *)message
{
//	NSRunAlertPanel(@"WebDesktop", message, @"OK", nil, nil);
}


- (BOOL)webView:(WebView *)sender runJavaScriptConfirmPanelWithMessage:(NSString *)message
{
//	return (NSRunAlertPanel(@"WebDesktop", message, @"Cancel", @"OK", nil) == NSAlertAlternateReturn);
    return FALSE;
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
    if (isPrimaryScreen){
        [sender stringByEvaluatingJavaScriptFromString:@"isPrimary(true)"];
    } else {
        [sender stringByEvaluatingJavaScriptFromString:@"isPrimary(false)"];
    }
}

- (void)createWindowWithContentRect:(NSRect)contentRect showFrame:(BOOL)showFrame alphaValue:(CGFloat)alphaValue screen:(NSScreen*)screen{

    clickThrough = YES;
	DesktopBackgroundWindow* oldWindow = window;
    window = [[DesktopBackgroundWindow alloc] initWithContentRect:contentRect styleMask:(showFrame ? NSTitledWindowMask | NSResizableWindowMask : NSBorderlessWindowMask) backing:NSBackingStoreBuffered defer:NO screen:screen];

    NSRect frame = [screen frame];
    isPrimaryScreen = (frame.origin.x == 0 && frame.origin.y == 0);
    [window setMinSize:NSMakeSize(200, 100)];
	[window setTitle:@"WebDesktop"];

	[window setFrame:contentRect display:YES];

	[window setDelegate:self];
	[self toggleClickThrough];

	if ( !webView )
	{
		webView = [[WebView alloc] initWithFrame:[[window contentView] frame] frameName:@"main" groupName:@"main"];
		[webView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
		[webView setUIDelegate:self];
		[webView setPolicyDelegate:self];
		[webView setDownloadDelegate:self];
        [webView setFrameLoadDelegate:self];
        [self disablePluginsInWebView];
        [[window contentView] addSubview:webView];
	}
	else
	{
		[webView setFrame:[[window contentView] frame]];
		[webView retain];
		[[window contentView] addSubview:webView];
		[webView release];
	}

	[window makeFirstResponder:webView];
    [window makeKeyAndOrderFront:nil];

    [window display];

	if ( oldWindow )
		[oldWindow release];

    NSString* lastURL = [[NSUserDefaults standardUserDefaults] objectForKey:@"LastURL"];
   	if ( lastURL )
   		[self loadURL:[NSURL URLWithString:lastURL]];
   	else
   		[self loadURL:[NSURL URLWithString:@"http://www.panic.com/"]];
}

- (void)disablePluginsInWebView {
    WebPreferences *prefs = [WebPreferences standardPreferences];
    [prefs setPlugInsEnabled:FALSE];
    [webView setPreferences:prefs];
}

- (void)toggleClickThrough
{
	void* ref = [window windowRef];

	if ( clickThrough )
	{
		ChangeWindowAttributes(ref,
				kWindowIgnoreClicksAttribute, kWindowNoAttributes);
        [window setLevel:kCGDesktopWindowLevel];
	}
	else
	{
		ChangeWindowAttributes(ref,
				kWindowNoAttributes, kWindowIgnoreClicksAttribute);
        [window setLevel:kCGDesktopIconWindowLevel];
        
	}

	[window setIgnoresMouseEvents:clickThrough];
    clickThrough = !clickThrough;
}

- (void)dealloc {
    [window release];
    [cachedRequest release];
    [location release];
    [super dealloc];
}

@end
