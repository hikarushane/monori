#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The resource bundle ID.
static NSString * const ACBundleID AC_SWIFT_PRIVATE = @"dev.monori.Monori";

/// The "AccentColor" asset catalog color resource.
static NSString * const ACColorNameAccentColor AC_SWIFT_PRIVATE = @"AccentColor";

/// The "BrandSage" asset catalog color resource.
static NSString * const ACColorNameBrandSage AC_SWIFT_PRIVATE = @"BrandSage";

/// The "LaunchMark" asset catalog image resource.
static NSString * const ACImageNameLaunchMark AC_SWIFT_PRIVATE = @"LaunchMark";

#undef AC_SWIFT_PRIVATE
