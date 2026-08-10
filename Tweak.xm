/**
 * Telegram Fix v2.0 for iOS 9
 * Для Telegram 5.x на iOS 9.3.6
 * 
 * 1. Полный обход SSL/TLS проверки сертификатов
 * 2. Подмена версии приложения (избегает блокировки сервером)
 * 3. Подмена версии системы
 * 4. Блокировка диалогов "обновите приложение"
 * 5. Блокировка перехода в App Store
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

#pragma mark - Конфигурация

static NSString *const kSpoofAppVersion = @"11.10.1";
static NSString *const kSpoofBundleVersion = @"4652";
static NSString *const kSpoofSystemVersion = @"26.4";
static NSString *const kSpoofDeviceModel = @"iPhone12,1";

#pragma mark - 1. Подмена версии приложения

%hook NSBundle

- (id)objectForInfoDictionaryKey:(NSString *)key {
    id orig = %orig;
    if ([key isEqualToString:@"CFBundleShortVersionString"]) {
        return kSpoofAppVersion;
    }
    if ([key isEqualToString:@"CFBundleVersion"]) {
        return kSpoofBundleVersion;
    }
    return orig;
}

- (NSDictionary *)infoDictionary {
    NSDictionary *raw = %orig;
    NSMutableDictionary *orig = [raw mutableCopy];
    if (orig) {
        orig[@"CFBundleShortVersionString"] = kSpoofAppVersion;
        orig[@"CFBundleVersion"] = kSpoofBundleVersion;
    }
    return orig;
}

%end

#pragma mark - 2. Подмена версии системы

%hook UIDevice

- (NSString *)systemVersion {
    return kSpoofSystemVersion;
}

- (NSString *)model {
    return kSpoofDeviceModel;
}

- (NSString *)machine {
    return kSpoofDeviceModel;
}

- (NSString *)localizedModel {
    return @"iPhone";
}

%end

#pragma mark - 3. SSL bypass (системные функции, точно есть на iOS 9)

%hookf(OSStatus, SecTrustEvaluate, SecTrustRef trust, SecTrustResultType *result) {
    if (result) {
        *result = kSecTrustResultProceed;
    }
    return errSecSuccess;
}

%hookf(OSStatus, SecTrustSetPolicies, SecTrustRef trust, CFTypeRef policies) {
    return errSecSuccess;
}

#pragma mark - 4. NSURLConnection SSL bypass

%hook NSURLConnection

+ (BOOL)allowsAnyHTTPSCertificateForHost:(NSString *)host {
    return YES;
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
    if (isUpdateAlert(self.title, self.message)) {
        writeLog([NSString stringWithFormat:@"BLOCKED update alert: %@", self.title]);
        return;
    }
    %orig;
}

%end
#pragma clang diagnostic pop

%hook UIAlertController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (isUpdateAlert(self.title, self.message)) {
        writeLog([NSString stringWithFormat:@"BLOCKED update sheet: %@", self.title]);
        [self dismissViewControllerAnimated:NO completion:nil];
    }
}

%end

#pragma mark - 6. Блокировка App Store

%hook UIApplication

- (BOOL)openURL:(NSURL *)url {
    if (url) {
        NSString *abs = [url absoluteString];
        NSString *scheme = [url scheme];
        if ([scheme isEqualToString:@"itms-apps"] ||
            [scheme isEqualToString:@"itms"] ||
            [abs rangeOfString:@"itunes.apple.com"].location != NSNotFound ||
            [abs rangeOfString:@"apps.apple.com"].location != NSNotFound ||
            [abs rangeOfString:@"id686449807"].location != NSNotFound) {
            writeLog([NSString stringWithFormat:@"BLOCKED App Store URL"]);
            return NO;
        }
    }
    return %orig;
}

%end

#pragma mark - 7. Runtime hook для SecTrustEvaluateWithAnchors (iOS 10+)
// Безопасно: если функции нет, просто пропускаем

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
    
    writeLog(@"=== Telegram Fix v2.0 LOADED ===");
    writeLog([NSString stringWithFormat:@"Bundle: %@", [[NSBundle mainBundle] bundleIdentifier]]);
    
    NSString *realVer = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    writeLog([NSString stringWithFormat:@"Real app version: %@", realVer]);
    writeLog([NSString stringWithFormat:@"Spoofing to: TG %@ / iOS %@ / %@", kSpoofAppVersion, kSpoofSystemVersion, kSpoofDeviceModel]);
    
    writeLog(@"SecTrustEvaluate: HOOKED");
    writeLog(@"SecTrustSetPolicies: HOOKED");
    
    // Безопасный хук SecTrustEvaluateWithAnchors (если есть)
    void *sym = dlsym(RTLD_DEFAULT, "SecTrustEvaluateWithAnchors");
    if (sym) {
        MSHookFunction(sym, (void *)replaced_secTrustEvalAnchors, (void **)&orig_secTrustEvalAnchors);
        writeLog(@"SecTrustEvaluateWithAnchors: HOOKED via MSHookFunction");
    } else {
        writeLog(@"SecTrustEvaluateWithAnchors: not present (iOS < 10)");
    }
    
    writeLog(@"=== ALL HOOKS ACTIVE ===");
}
