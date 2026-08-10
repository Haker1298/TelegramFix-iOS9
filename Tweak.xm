/**
 * Telegram Fix v2.1 for iOS 9
 * Для Telegram 5.x на iOS 9.3.6
 * 
 * 1. Полный обход SSL/TLS проверки сертификатов
 * 2. Подмена версии приложения (настраиваемая)
 * 3. Подмена версии системы и устройства (настраиваемые)
 * 4. Блокировка диалогов "обновите приложение"
 * 5. Блокировка перехода в App Store
 * 6. Настройки в Настройки -> Telegram Fix
 * Author: Haker1928
 */

%config(Generator=MobileSubstrate)

#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <UIKit/UIKit.h>
#import <dlfcn.h>
#import <substrate.h>

#pragma mark - Логирование

static NSString *logPath(void) {
    return @"/var/mobile/Library/Logs/TelegramFix.log";
}

static void ensureLogDir(void) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *dir = @"/var/mobile/Library/Logs";
    if (![fm fileExistsAtPath:dir]) {
        [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    }
}

static void writeLog(NSString *msg) {
    ensureLogDir();
    NSDateFormatter *ts = [[NSDateFormatter alloc] init];
    [ts setDateFormat:@"HH:mm:ss.SSS"];
    NSString *line = [NSString stringWithFormat:@"[%@] %@\n", [ts stringFromDate:[NSDate date]], msg];
    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:logPath()];
    if (!fh) {
        [line writeToFile:logPath() atomically:YES encoding:NSUTF8StringEncoding error:nil];
        return;
    }
    [fh seekToEndOfFile];
    [fh writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
    [fh closeFile];
}

#pragma mark - Настройки

static NSString *kPrefPath = @"/var/mobile/Library/Preferences/com.haker1928.telegramfix.plist";

static NSDictionary *loadPrefs(void) {
    return [NSDictionary dictionaryWithContentsOfFile:kPrefPath];
}

static NSString *prefString(NSDictionary *prefs, NSString *key, NSString *fallback) {
    id val = prefs[key];
    return ([val isKindOfClass:[NSString class]] && [(NSString *)val length] > 0) ? val : fallback;
}

static BOOL prefBool(NSDictionary *prefs, NSString *key, BOOL fallback) {
    id val = prefs[key];
    return (val != nil) ? [val boolValue] : fallback;
}

#pragma mark - 1. Подмена версии приложения

%hook NSBundle

- (id)objectForInfoDictionaryKey:(NSString *)key {
    id orig = %orig;
    NSDictionary *prefs = loadPrefs();
    if (prefBool(prefs, @"enabled", YES)) {
        if ([key isEqualToString:@"CFBundleShortVersionString"]) {
            return prefString(prefs, @"spoofAppVersion", @"11.10.1");
        }
        if ([key isEqualToString:@"CFBundleVersion"]) {
            return prefString(prefs, @"spoofBundleVersion", @"4652");
        }
    }
    return orig;
}

- (NSDictionary *)infoDictionary {
    NSDictionary *raw = %orig;
    NSMutableDictionary *orig = [raw mutableCopy];
    NSDictionary *prefs = loadPrefs();
    if (orig && prefBool(prefs, @"enabled", YES)) {
        orig[@"CFBundleShortVersionString"] = prefString(prefs, @"spoofAppVersion", @"11.10.1");
        orig[@"CFBundleVersion"] = prefString(prefs, @"spoofBundleVersion", @"4652");
    }
    return orig;
}

%end

#pragma mark - 2. Подмена версии системы

%hook UIDevice

- (NSString *)systemVersion {
    NSDictionary *prefs = loadPrefs();
    if (prefBool(prefs, @"enabled", YES)) {
        return prefString(prefs, @"spoofiOSVersion", @"26.4");
    }
    return %orig;
}

- (NSString *)model {
    NSDictionary *prefs = loadPrefs();
    if (prefBool(prefs, @"enabled", YES)) {
        return prefString(prefs, @"spoofDevice", @"iPhone12,1");
    }
    return %orig;
}

- (NSString *)machine {
    NSDictionary *prefs = loadPrefs();
    if (prefBool(prefs, @"enabled", YES)) {
        return prefString(prefs, @"spoofDevice", @"iPhone12,1");
    }
    return %orig;
}

- (NSString *)localizedModel {
    return @"iPhone";
}

%end

#pragma mark - 3. SSL bypass

%hookf(OSStatus, SecTrustEvaluate, SecTrustRef trust, SecTrustResultType *result) {
    NSDictionary *prefs = loadPrefs();
    if (prefBool(prefs, @"sslBypass", YES) && prefBool(prefs, @"enabled", YES)) {
        if (result) *result = kSecTrustResultProceed;
        return errSecSuccess;
    }
    return %orig;
}

%hookf(OSStatus, SecTrustSetPolicies, SecTrustRef trust, CFTypeRef policies) {
    NSDictionary *prefs = loadPrefs();
    if (prefBool(prefs, @"sslBypass", YES) && prefBool(prefs, @"enabled", YES)) {
        return errSecSuccess;
    }
    return %orig;
}

#pragma mark - 4. NSURLConnection SSL bypass

%hook NSURLConnection

+ (BOOL)allowsAnyHTTPSCertificateForHost:(NSString *)host {
    NSDictionary *prefs = loadPrefs();
    if (prefBool(prefs, @"sslBypass", YES) && prefBool(prefs, @"enabled", YES)) {
        return YES;
    }
    return %orig;
}

%end

#pragma mark - 5. Блокировка диалогов обновления

static BOOL isUpdateAlert(NSString *title, NSString *message) {
    if (!title && !message) return NO;
    NSString *combined = [[title stringByAppendingString:@" "] stringByAppendingString:message ?: @""];
    NSArray *keywords = @[
        @"update", @"Update", @"UPDATE",
        @"обновите", @"Обновите", @"ОБНОВИТЕ",
        @"new version", @"newer version",
        @"устаревшая", @"outdated",
        @"продолжить работу", @"continue working",
        @"app store", @"App Store",
        @"обновл", @"Обновл"
    ];
    for (NSString *kw in keywords) {
        if ([combined rangeOfString:kw options:NSCaseInsensitiveSearch].location != NSNotFound) {
            return YES;
        }
    }
    return NO;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
%hook UIAlertView

- (void)show {
    NSDictionary *prefs = loadPrefs();
    if (prefBool(prefs, @"blockUpdates", YES) && prefBool(prefs, @"enabled", YES)) {
        if (isUpdateAlert(self.title, self.message)) {
            writeLog([NSString stringWithFormat:@"BLOCKED update alert: %@", self.title]);
            return;
        }
    }
    %orig;
}

%end
#pragma clang diagnostic pop

%hook UIAlertController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    NSDictionary *prefs = loadPrefs();
    if (prefBool(prefs, @"blockUpdates", YES) && prefBool(prefs, @"enabled", YES)) {
        if (isUpdateAlert(self.title, self.message)) {
            writeLog([NSString stringWithFormat:@"BLOCKED update sheet: %@", self.title]);
            [self dismissViewControllerAnimated:NO completion:nil];
        }
    }
}

%end

#pragma mark - 6. Блокировка App Store

%hook UIApplication

- (BOOL)openURL:(NSURL *)url {
    NSDictionary *prefs = loadPrefs();
    if (prefBool(prefs, @"blockAppStore", YES) && prefBool(prefs, @"enabled", YES)) {
        if (url) {
            NSString *abs = [url absoluteString];
            NSString *scheme = [url scheme];
            if ([scheme isEqualToString:@"itms-apps"] ||
                [scheme isEqualToString:@"itms"] ||
                [abs rangeOfString:@"itunes.apple.com"].location != NSNotFound ||
                [abs rangeOfString:@"apps.apple.com"].location != NSNotFound ||
                [abs rangeOfString:@"id686449807"].location != NSNotFound) {
                writeLog(@"BLOCKED App Store URL");
                return NO;
            }
        }
    }
    return %orig;
}

%end

#pragma mark - 7. Runtime hook для SecTrustEvaluateWithAnchors (iOS 10+)

typedef OSStatus (*SecTrustEvaluateWithAnchorsType)(SecTrustRef, CFArrayRef, SecTrustResultType *);
static SecTrustEvaluateWithAnchorsType orig_secTrustEvalAnchors = NULL;

static OSStatus replaced_secTrustEvalAnchors(SecTrustRef trust, CFArrayRef anchors, SecTrustResultType *result) {
    if (result) *result = kSecTrustResultProceed;
    return errSecSuccess;
}

#pragma mark - Constructor

%ctor {
    ensureLogDir();
    [@"" writeToFile:logPath() atomically:YES encoding:NSUTF8StringEncoding error:nil];
    
    NSDictionary *prefs = loadPrefs();
    BOOL enabled = prefBool(prefs, @"enabled", YES);
    
    writeLog(@"=== Telegram Fix v2.1 LOADED ===");
    writeLog([NSString stringWithFormat:@"Bundle: %@", [[NSBundle mainBundle] bundleIdentifier]]);
    
    NSString *realVer = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    writeLog([NSString stringWithFormat:@"Real app version: %@", realVer]);
    
    if (enabled) {
        NSString *appVer = prefString(prefs, @"spoofAppVersion", @"11.10.1");
        NSString *buildVer = prefString(prefs, @"spoofBundleVersion", @"4652");
        NSString *iosVer = prefString(prefs, @"spoofiOSVersion", @"26.4");
        NSString *device = prefString(prefs, @"spoofDevice", @"iPhone12,1");
        writeLog([NSString stringWithFormat:@"Spoofing: TG %@(%@) / iOS %@ / %@", appVer, buildVer, iosVer, device]);
    } else {
        writeLog(@"Tweak DISABLED in settings");
    }
    
    if (prefBool(prefs, @"sslBypass", YES)) {
        writeLog(@"SecTrustEvaluate: HOOKED");
        writeLog(@"SecTrustSetPolicies: HOOKED");
        
        void *sym = dlsym(RTLD_DEFAULT, "SecTrustEvaluateWithAnchors");
        if (sym) {
            MSHookFunction(sym, (void *)replaced_secTrustEvalAnchors, (void **)&orig_secTrustEvalAnchors);
            writeLog(@"SecTrustEvaluateWithAnchors: HOOKED");
        }
    }
    
    writeLog(@"=== ALL HOOKS ACTIVE ===");
}
