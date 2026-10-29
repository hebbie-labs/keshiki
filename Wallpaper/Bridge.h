// The private pieces of macOS's wallpaper system the extension talks to. None of this is public API; the protocol
// shapes follow Phosphene (MIT, github.com/kageroumado/phosphene), which worked them out.

#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <bsm/libbsm.h>

@interface NSXPCConnection (KeshikiCallerIdentity)
@property (nonatomic, readonly) audit_token_t auditToken;
@end

/// A layer tree that another process (the WallpaperAgent) shows.
@interface CAContext : NSObject
@property (readonly) unsigned int contextId;
@property (retain) CALayer *layer;
+ (id)remoteContextWithOptions:(id)options;
@end

/// What the extension may call on the WallpaperAgent.
@protocol WallpaperExtensionProxyXPCProtocol <NSObject>
- (void)pingWithId:(id _Nullable)anId;
- (void)updateSettingsViewModels:(id _Nullable)models reply:(void (^ _Nonnull)(NSError * _Nullable))reply;
- (void)requestReadOnlyAccessTo:(id _Nullable)url reply:(void (^ _Nonnull)(id _Nullable))reply;
- (void)invalidateSnapshotsWithReply:(void (^ _Nonnull)(NSError * _Nullable))reply;
@end

/// What the WallpaperAgent calls on the extension. Every method must exist, even the ones we don't use.
@protocol WallpaperExtensionXPCProtocol <NSObject>
- (void)acquireWithId:(id _Nullable)anId request:(id _Nullable)request reply:(void (^ _Nonnull)(id _Nullable, NSError * _Nullable))reply;
- (void)updateWithId:(id _Nullable)anId request:(id _Nullable)request reply:(void (^ _Nonnull)(NSError * _Nullable))reply;
- (void)invalidateWithId:(id _Nullable)anId reply:(void (^ _Nonnull)(NSError * _Nullable))reply;
- (void)snapshotWithId:(id _Nullable)anId reply:(void (^ _Nonnull)(id _Nullable, NSError * _Nullable))reply;
- (void)provideSettingsViewModelsWithContentTypes:(id _Nullable)types reply:(void (^ _Nonnull)(id _Nullable, NSError * _Nullable))reply;
- (void)addChoiceRequestWithChoiceRequest:(id _Nullable)request onBehalfOfProcess:(id _Nullable)process reply:(void (^ _Nonnull)(id _Nullable, NSError * _Nullable))reply;
- (void)removeChoiceRequestWithChoiceRequest:(id _Nullable)request reply:(void (^ _Nonnull)(NSError * _Nullable))reply;
- (void)selectedChoicesDidChangeFor:(id _Nullable)anId reply:(void (^ _Nonnull)(NSError * _Nullable))reply;
- (void)invokeContextMenuActionWithMenuItemID:(id _Nullable)menuItemID groupItemID:(id _Nullable)groupItemID reply:(void (^ _Nonnull)(NSError * _Nullable))reply;
- (void)isChoiceDownloadedWith:(id _Nullable)choiceID reply:(void (^ _Nonnull)(NSNumber * _Nullable, NSError * _Nullable))reply;
- (id _Nullable)downloadWithChoiceID:(id _Nullable)choiceID reply:(void (^ _Nonnull)(NSError * _Nullable))reply;
- (void)pauseDownloadFor:(id _Nullable)choiceID reply:(void (^ _Nonnull)(NSError * _Nullable))reply;
- (void)cancelDownloadFor:(id _Nullable)choiceID reply:(void (^ _Nonnull)(NSError * _Nullable))reply;
- (void)resumeDownloadFor:(id _Nullable)choiceID reply:(void (^ _Nonnull)(NSError * _Nullable))reply;
- (void)removeDownloadFor:(id _Nullable)choiceID reply:(void (^ _Nonnull)(NSError * _Nullable))reply;
- (void)migrateSelectedChoiceFor:(id _Nullable)anId reply:(void (^ _Nonnull)(id _Nullable, NSError * _Nullable))reply;
- (void)migrateFrom:(id _Nullable)from to:(id _Nullable)to reply:(void (^ _Nonnull)(NSError * _Nullable))reply;
- (void)skipShuffledContentWithId:(id _Nullable)anId reply:(void (^ _Nonnull)(NSError * _Nullable))reply;
- (void)canSkipShuffledContentWithId:(id _Nullable)anId reply:(void (^ _Nonnull)(BOOL, NSError * _Nullable))reply;
- (void)handleDebugRequestFor:(id _Nullable)request reply:(void (^ _Nonnull)(id _Nullable, NSError * _Nullable))reply;
- (void)handleNotificationWithNamed:(id _Nullable)name reply:(void (^ _Nonnull)(NSError * _Nullable))reply;
@end
