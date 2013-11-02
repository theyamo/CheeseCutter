/*
 * SDLMain.m - main entry point for our Cocoa-ized SDL app
 * Initial Version: Darrell Walisser <dwaliss1@purdue.edu>
 * Non-NIB-Code & other changes: Max Horn <max@quendi.de>
 * Port to the D programming language: Jacob Carlborg <jacob.carlborg@gmail.com>
 *
 * Feel free to customize this file to suit your needs
 */
module derelict.sdl.macinit.SDLMain;
import main;

version(DigitalMars) version(OSX) version = darwin;

version (darwin)
{

private
{
    version (Tango)
    {
        import tango.stdc.posix.unistd;
        import tango.stdc.stdlib;
        import tango.stdc.string;
    }

    else
    {
        import std.c.linux.linux;
        import std.c.stdlib;
        import std.c.string;

        static import std.string;
    }

    import derelict.sdl.sdltypes;
    import derelict.sdl.sdlfuncs;
    import derelict.sdl.macinit.CoreFoundation;
    import derelict.sdl.macinit.DerelictSDLMacLoader;
    import derelict.sdl.macinit.ID;
    import derelict.sdl.macinit.MacTypes;
    import derelict.sdl.macinit.NSApplication;
    import derelict.sdl.macinit.NSAutoreleasePool;
    import derelict.sdl.macinit.NSDictionary;
    import derelict.sdl.macinit.NSEnumerator;
    import derelict.sdl.macinit.NSEvent;
    import derelict.sdl.macinit.NSGeometry;
    import derelict.sdl.macinit.NSMenu;
    import derelict.sdl.macinit.NSMenuItem;
    import derelict.sdl.macinit.NSNotification;
    import derelict.sdl.macinit.NSObject;
    import derelict.sdl.macinit.NSProcessInfo;
    import derelict.sdl.macinit.NSString;
    import derelict.sdl.macinit.runtime;
    import derelict.sdl.macinit.selectors;
    import derelict.sdl.macinit.string;
    import derelict.util.compat;
    import derelict.util.loader;
}

private:

enum
{
    MAXPATHLEN = 1024 // from sys/param.h
}

/* Use this flag to determine whether we use CPS (docking) or not */
version = SDL_USE_CPS;

version (SDL_USE_CPS)
{
    struct CPSProcessSerNum
    {
        uint lo;
        uint hi;
    }

    extern (C)
    {
        mixin(gsharedString!() ~ "
        OSErr function (CPSProcessSerNum *psn) CPSGetCurrentProcess;
        OSErr function (CPSProcessSerNum *psn, UInt32 _arg2, UInt32 _arg3, UInt32 _arg4, UInt32 _arg5) CPSEnableForegroundOperation;
        OSErr function (CPSProcessSerNum *psn) CPSSetFrontProcess;");
    }

    void load (void delegate(void**, string, bool doThrow) bindFunc)
    {
        bindFunc(cast(void**)&CPSGetCurrentProcess, "CPSGetCurrentProcess", true);
        bindFunc(cast(void**)&CPSEnableForegroundOperation, "CPSEnableForegroundOperation", true);
        bindFunc(cast(void**)&CPSSetFrontProcess, "CPSSetFrontProcess", true);
    }
}

else
    version = NO_SDL_USE_CPS;

private
{
    NSAutoreleasePool pool;
    SDLMain sdlMain;
}

static this ()
{
    version (SDL_USE_CPS)
        load(&DerelictSDLMac.bindFunc);

    registerSubclasses();
    CustomApplicationMain();
}

static ~this()
{
    if(pool !is null)
        pool.release();

    if(sdlMain !is null)
        sdlMain.release;

    DerelictSDLMac.unload();
}

private void registerSubclasses ()
{
    objc_method terminateMethod;
    terminateMethod.method_imp = cast(IMP) &terminate;
    terminateMethod.method_name = sel_terminate;
    terminateMethod.method_types = "v@:";

    objc_method_list* terminateMethodList = cast(objc_method_list*) calloc(1, (objc_method_list).sizeof);
    terminateMethodList.method_count = 1;
    terminateMethodList.method_list[0] = terminateMethod;



    objc_method setupWorkingDirectoryMethod;
    setupWorkingDirectoryMethod.method_imp = cast(IMP) &setupWorkingDirectory;
    setupWorkingDirectoryMethod.method_name = sel_setupWorkingDirectory;
    setupWorkingDirectoryMethod.method_types = "v@:B";

    objc_method_list* setupWorkingDirectoryMethodList = cast(objc_method_list*) calloc(1, (objc_method_list).sizeof);
    setupWorkingDirectoryMethodList.method_count = 1;
    setupWorkingDirectoryMethodList.method_list[0] = setupWorkingDirectoryMethod;



    objc_method applicationMethod;
    applicationMethod.method_imp = cast(IMP) &application;
    applicationMethod.method_name = sel_application;
    applicationMethod.method_types = "B@:@@";

    objc_method_list* applicationMethodList = cast(objc_method_list*) calloc(1, (objc_method_list).sizeof);
    applicationMethodList.method_count = 1;
    applicationMethodList.method_list[0] = applicationMethod;



    objc_method applicationDidFinishLaunchingMethod;
    applicationDidFinishLaunchingMethod.method_imp = cast(IMP) &applicationDidFinishLaunching;
    applicationDidFinishLaunchingMethod.method_name = sel_applicationDidFinishLaunching;
    applicationDidFinishLaunchingMethod.method_types = "v@:@";

    objc_method_list* applicationDidFinishLaunchingMethodList = cast(objc_method_list*) calloc(1, (objc_method_list).sizeof);
    applicationDidFinishLaunchingMethodList.method_count = 1;
    applicationDidFinishLaunchingMethodList.method_list[0] = applicationDidFinishLaunchingMethod;



    auto sdlApplicationMethodList = [terminateMethodList];
    auto sdlMainMethodList = [setupWorkingDirectoryMethodList, applicationMethodList, applicationDidFinishLaunchingMethodList];

    registerClass!("SDLApplication")(cast(Class) class_NSApplication, sdlApplicationMethodList);
    registerClass!("SDLMain")(cast(Class) class_NSObject, sdlMainMethodList);

    class_SDLApplication = objc_getClass!("SDLApplication");
}

private void registerClass (string className) (Class superClass, objc_method_list*[] methodList)
{
    Class newClass;

    // Leopard and above
    if (!objc_addClass)
    {
        newClass = objc_allocateClassPair!(className)(cast(Class) superClass, 0);

        foreach (m ; methodList)
        {
            auto method = m.method_list[0];
            class_addMethod(newClass, method.method_name, method.method_imp, method.method_types);
        }

        objc_registerClassPair(newClass);
    }

    // Tiger and below
    else
    {
        enum
        {
            CLS_CLASS = 0x1,
            CLS_META = 0x2
        }

        Class metaClass;
        Class rootClass = superClass;

        // Find the root class
        while (rootClass.super_class !is null)
            rootClass = rootClass.super_class;

        // Allocate space for the class and its metaclass
        newClass = cast(Class) calloc(2, objc_class.sizeof);
        metaClass = &newClass[1];

        // Setup class
        newClass.isa = metaClass;
        newClass.info = CLS_CLASS;
        metaClass.info = CLS_META;

        /*
         * Create a copy of the class name.
         * For efficiency, we have the metaclass and the class itself
         * to share this copy of the name, but this is not a requirement
         * imposed by the runtime.
         */
        newClass.name = toCString(className);
        metaClass.name = newClass.name;

        // Allocate method lists.
        newClass.methodLists = cast(objc_method_list**) calloc(1, (objc_method_list*).sizeof);
        *(newClass.methodLists) = cast(objc_method_list*) -1;
        metaClass.methodLists = cast(objc_method_list**) calloc(1, (objc_method_list*).sizeof);
        *(metaClass.methodLists) = cast(objc_method_list*) -1;

        foreach (method ; methodList)
            class_addMethods(newClass, method);

        /*
         * Connect the class definition to the class hierarchy:
         * Connect the class to the superclass.
         * Connect the metaclass to the metaclass of the superclass.
         * Connect the metaclass of the metaclass to the metaclass of  the root class.
         */
        newClass.super_class = superClass;
        metaClass.super_class = superClass.isa;
        metaClass.isa = rootClass.isa;

        // Set the sizes of the class and the metaclass.
        newClass.instance_size = superClass.instance_size;
        metaClass.instance_size = metaClass.super_class.instance_size;

        // Finally, register the class with the runtime.
        objc_addClass(newClass);
    }
}

private NSString getApplicationName ()
{
    NSDictionary dict;
    NSString appName;

    /* Determine the application name */
    dict = new NSDictionary(cast(id)CFBundleGetInfoDictionary(CFBundleGetMainBundle()));

    if (dict)
        appName = cast(NSString) dict.objectForKey(NSString.stringWith("CFBundleName"));

    if (appName is null || !appName.length)
        appName = NSProcessInfo.processInfo.processName;

    return appName;
}

class SDLApplication : NSApplication
{
    this ()
    {
        id_ = null;
    }

    this (id id_)
    {
        this.id_ = id_;
    }

    static SDLApplication alloc ()
    {
        id result = objc_msgSend(cast(id)class_, sel_alloc);
        return result ? new SDLApplication(result) : null;
    }

    static Class class_ ()
    {
        return cast(Class) objc_getClass!(this.stringof);
    }

    static void poseAsClass (Class aClass)
    {
        objc_msgSend(class_SDLApplication, sel_poseAsClass, aClass);
    }

    SDLApplication init ()
    {
        id result = objc_msgSend(this.id_, sel_init);
        return result ? this : null;
    }

    /* Invoked from the Quit menu item */
    void terminate ()
    {
        objc_msgSend(this.id_, sel_terminate);
    }
}

/* Invoked from the Quit menu item */
extern (C) id terminate (id self, SEL selector)
{
    /* Post a SDL_QUIT event */
    SDL_Event event;
    event.type = SDL_QUIT;
    SDL_PushEvent(&event);

    return null;
}

/* The main class of the application, the application's delegate */
class SDLMain : NSObject
{
    this ()
    {
        id_ = null;
    }

    this (id id_)
    {
        this.id_ = id_;
    }

    static SDLMain alloc ()
    {
        id result = objc_msgSend(cast(id)class_, sel_alloc);
        return result ? new SDLMain(result) : null;
    }

    static Class class_ ()
    {
        return cast(Class) objc_getClass!(this.stringof);
    }

    SDLMain init ()
    {
        id result = objc_msgSend(this.id_, sel_init);
        return result ? this : null;
    }

    void setupWorkingDirectory (bool shouldChdir)
    {
        objc_msgSend(this.id_, sel_setupWorkingDirectory, shouldChdir);
    }

    bool application (NSApplication theApplication, NSString filename)
    {
        return objc_msgSend(this.id_, sel_application, theApplication ? theApplication.id_ : null, filename ? filename.id_ : null) !is null;
    }

    /* Called when the internal event loop has just started running */
    void applicationDidFinishLaunching (NSNotification note)
    {
        objc_msgSend(this.id_, sel_applicationDidFinishLaunching, note ? note.id_ : null);
    }
}

extern (C)
{
    id setupWorkingDirectory (id sender, SEL selector, bool shouldChdir)
    {
        if (shouldChdir)
        {
            char parentdir[MAXPATHLEN];

            CFURLRef url = CFBundleCopyBundleURL(CFBundleGetMainBundle());
            CFURLRef url2 = CFURLCreateCopyDeletingLastPathComponent(null, url);

            if (CFURLGetFileSystemRepresentation(url2, true, cast(ubyte*) parentdir, MAXPATHLEN))
                assert (chdir(parentdir.ptr) == 0);   /* chdir to the binary app's parent */

            CFRelease(url);
            CFRelease(url2);
        }

        return null;
    }

    id application (id sender, SEL selector, id arg0, id arg1)
    {
	   if (arg1) {
		main.openFile((new NSString(arg1)).UTF8String());
	    }

	    return cast(id) true;
    }

    /* Called when the internal event loop has just started running */
    id applicationDidFinishLaunching (id sender, SEL selector, id arg0)
    {
        NSNotification note = arg0 ? new NSNotification(arg0) : null;

        int status;

        /* Set the working directory to the .app's parent directory */
        setupWorkingDirectory(sender, selector, false);

        NSApp.stop(null);

        return null;
    }
}

private void setApplicationMenu ()
{
    /* warning: this code is very odd */
    NSMenu appleMenu;
    NSMenuItem menuItem;
    NSString title;
    NSString appName;

    appName = getApplicationName();
    appleMenu = NSMenu.alloc.initWithTitle(NSString.stringWith(""));

    /* Add menu items */
    title = NSString.stringWith("About ").stringByAppendingString(appName);
    appleMenu.addItemWithTitle(title, sel_registerName!("orderFrontStandardAboutPanel:"), NSString.stringWith(""));

    appleMenu.addItem(NSMenuItem.separatorItem);

    title = NSString.stringWith("Hide ").stringByAppendingString(appName);
    appleMenu.addItemWithTitle(title, sel_registerName!("hide:"), NSString.stringWith("h"));

    menuItem = appleMenu.addItemWithTitle(NSString.stringWith("Hide Others"), sel_registerName!("hideOtherApplications:"), NSString.stringWith("h"));
    menuItem.setKeyEquivalentModifierMask(NSAlternateKeyMask | NSCommandKeyMask);

    appleMenu.addItemWithTitle(NSString.stringWith("Show All"), sel_registerName!("unhideAllApplications:"), NSString.stringWith(""));

    appleMenu.addItem(NSMenuItem.separatorItem);

    title = NSString.stringWith("Quit ").stringByAppendingString(appName);
    appleMenu.addItemWithTitle(title, sel_registerName!("terminate:"), NSString.stringWith("q"));


    /* Put menu into the menubar */
    menuItem = NSMenuItem.alloc;
    menuItem = menuItem.initWithTitle(NSString.stringWith(""), null, NSString.stringWith(""));
    menuItem.setSubmenu = appleMenu;
    NSApp.mainMenu.addItem(menuItem);

    /* Tell the application object that this is now the application menu */
    NSApp.setAppleMenu = appleMenu;

    /* Finally give up our references to the objects */
    appleMenu.release;
    menuItem.release;
}

/* Create a window menu */
private void setupWindowMenu ()
{
    NSMenu windowMenu;
    NSMenuItem windowMenuItem;
    NSMenuItem menuItem;

    windowMenu = NSMenu.alloc.initWithTitle(NSString.stringWith("Window"));

    /* "Minimize" item */
    menuItem = NSMenuItem.alloc;
    menuItem = menuItem.initWithTitle(NSString.stringWith("Minimize"), sel_registerName!("performMiniaturize:"), NSString.stringWith("m"));
    windowMenu.addItem(menuItem);
    menuItem.release;

    /* Put menu into the menubar */
    windowMenuItem = NSMenuItem.alloc;
    windowMenuItem = windowMenuItem.initWithTitle(NSString.stringWith("Window"), null, NSString.stringWith(""));
    windowMenuItem.setSubmenu = windowMenu;
    NSApp.mainMenu.addItem(windowMenuItem);

    /* Tell the application object that this is now the window menu */
    NSApp.setWindowsMenu = windowMenu;

    /* Finally give up our references to the objects */
    windowMenu.release;
    windowMenuItem.release;
}

/* Replacement for NSApplicationMain */
private void CustomApplicationMain ()
{
    pool = NSAutoreleasePool.alloc.init;

    /* Ensure the application object is initialised */
    SDLApplication.sharedApplication;

    version (SDL_USE_CPS)
    {
        CPSProcessSerNum PSN;

        /* Tell the dock about us */
        if (!CPSGetCurrentProcess(&PSN))
            if (!CPSEnableForegroundOperation(&PSN, 0x03, 0x3C, 0x2C, 0x1103))
                if (!CPSSetFrontProcess(&PSN))
                    SDLApplication.sharedApplication;
    }

    /* Set up the menubar */
    NSApp.setMainMenu = NSMenu.alloc.init;
    setApplicationMenu();
    setupWindowMenu();


    /* Create SDLMain and make it the app delegate */
    sdlMain = SDLMain.alloc.init;
    NSApp.setDelegate = sdlMain;

    /* Start the main event loop */
    NSApp.run;
}

} // version(darwin)
