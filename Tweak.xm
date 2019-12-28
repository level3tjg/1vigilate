#import <dlfcn.h>
#import <substrate.h>
#import <objc/runtime.h>
#import "fishhook/fishhook.c"

bool shouldSpoof;
NSDictionary *prefs;

@interface IvarHook : NSObject{
	BOOL _inPopover;
}
@end

@implementation IvarHook
@end

IvarHook *ivarHook;

Ivar hook_class_getInstanceVariable(Class _class, const char *name){
	Ivar (*orig_class_getInstanceVariable)(Class _class, const char *name) = (Ivar
      (*)(__unsafe_unretained Class, const char *))dlsym(RTLD_DEFAULT, "class_getInstanceVariable");
	if([_class isEqual:NSClassFromString(@"_UIAlertControllerView")] && [@(name) isEqualToString:@"_inPopover"])
		_class = [ivarHook class];
	return orig_class_getInstanceVariable(_class, name);
}

%group iOS13Hooks

%hookf(Class, NSClassFromString, NSString *_class){
	if([_class isEqualToString:@"_UIInterfaceActionItemSeparatorView_iOS"])
		return %orig(@"_UIInterfaceActionVibrantSeparatorView");
	return %orig();
}

%hook UIAlertController
-(void)viewDidLayoutSubviews{
	const char *function = "class_getInstanceVariable";
    void *original = dlsym(RTLD_DEFAULT, function);
    struct rebinding binding = {function, (void *)hook_class_getInstanceVariable};
    struct rebinding bindings[] = {binding};
    rebind_symbols(bindings, 1);
    %orig;
    binding.replacement = original;
    rebind_symbols(bindings, 1);
}
%end

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

__attribute__((constructor))
static void init(){
	prefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.integeritis.palert.plist"];
	MSHookMessageEx(%c(UIDevice), @selector(systemVersion), (IMP)hook_systemVersion, (IMP *)&orig_systemVersion);
	if(@available(iOS 13, *)){
		%init(iOS13Hooks)
		ivarHook = [[IvarHook alloc] init];
	}
	shouldSpoof = TRUE;
	dlopen("/Library/MobileSubstrate/DynamicLibraries/Palert.dylib", 1);
	shouldSpoof = FALSE;
}