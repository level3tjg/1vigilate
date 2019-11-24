#import <dlfcn.h>
#import <substrate.h>
#import <objc/runtime.h>

bool shouldSpoof;
NSDictionary *prefs;

@interface IvarHook : NSObject{
	BOOL _inPopover;
}
@end

@implementation IvarHook
@end

IvarHook *ivarHook;

%group iOS13Hooks

%hookf(Ivar, class_getInstanceVariable, Class _class, const char *name){
	if([_class isEqual:NSClassFromString(@"_UIAlertControllerView")] && [@(name) isEqualToString:@"_inPopover"])
		return %orig([ivarHook class], "_inPopover");
	return %orig();
}

%hookf(Class, NSClassFromString, NSString *_class){
	if([_class isEqualToString:@"_UIInterfaceActionItemSeparatorView_iOS"])
		return %orig(@"_UIInterfaceActionVibrantSeparatorView");
	return %orig();
}

%hook _UIAlertControllerView
-(void)setPresentedAsPopover:(BOOL)arg1{
	%orig();
	Ivar ivar = class_getInstanceVariable([ivarHook class], "_inPopover");
	object_setIvar(ivarHook, ivar, @(arg1));
}
%end

%hook UIVisualEffectView
-(void)layoutSubviews{
	%orig;
	if([self.nextResponder isKindOfClass:NSClassFromString(@"_UIAlertControlleriOSHighlightedBackgroundView")])
		[self setHidden:true];
}
%end

%end

NSString *(*orig_systemVersion)(id self, SEL _cmd);
NSString *hook_systemVersion(id self, SEL _cmd){
	if(shouldSpoof)
		return @"10.1";
	return (*orig_systemVersion)(self, _cmd);
}

bool (*orig_eclipseEnabled)();
bool hook_eclipseEnabled(){
	if(@available(iOS 13, *)){
		if([[UITraitCollection currentTraitCollection] userInterfaceStyle] == 2)
			return true;
		return false;
	}
	return (*orig_eclipseEnabled)();
}

__attribute__((constructor))
static void init(){
	prefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.integeritis.palert.plist"];
	MSHookMessageEx(%c(UIDevice), @selector(systemVersion), (IMP)hook_systemVersion, (IMP *)&orig_systemVersion);
	if(@available(iOS 13, *)){
		%init(iOS13Hooks)
		ivarHook = [[IvarHook alloc] init];
		MSHookFunction((void *)MSFindSymbol(MSGetImageByName("/Library/MobileSubstrate/DynamicLibraries/Palert.dylib"), "__Z14eclipseEnabledv"), (void *)hook_eclipseEnabled, (void **)&orig_eclipseEnabled);
	}
	shouldSpoof = TRUE;
	dlopen("/Library/MobileSubstrate/DynamicLibraries/Palert.dylib", 1);
	shouldSpoof = FALSE;
}