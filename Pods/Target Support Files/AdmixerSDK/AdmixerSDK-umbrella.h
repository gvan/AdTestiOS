#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "AdmixerSDK.h"
#import "GoogleMediation.h"
#import "GoogleMediationAdapter.h"

FOUNDATION_EXPORT double AdmixerSDKVersionNumber;
FOUNDATION_EXPORT const unsigned char AdmixerSDKVersionString[];

