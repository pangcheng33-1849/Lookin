//
//  LKMCPServerRuntime.m
//  Lookin
//
//  Created by Codex on 2026/2/23.
//

#import "LKMCPServerRuntime.h"
#import "LKMCPToolRouter.h"
#import "LKMCPError.h"
#import <arpa/inet.h>
#import <errno.h>
#import <fcntl.h>
#import <netinet/in.h>
#import <string.h>
#import <sys/socket.h>
#import <sys/time.h>
#import <unistd.h>

static NSString * const kLKMCPHTTPMethodPOST = @"POST";
static NSString * const kLKMCPHTTPMethodGET = @"GET";
static NSString * const kLKMCPHTTPPathMCP = @"/mcp";
static NSUInteger const kLKMCPMaxHTTPRequestBytes = 2 * 1024 * 1024; // 2MB guard
static NSUInteger const kLKMCPPortFallbackCount = 20;
static NSString * const kLKMCPProtocolVersion = @"2025-06-18";
static NSString * const kLKMCPJSONRPCVersion = @"2.0";
#define LKMCPRuntimeLog(fmt, ...) NSLog((@"[LookinMCP][Runtime] " fmt), ##__VA_ARGS__)

static BOOL LKMCPShouldRetrySocketRead(void) {
    return errno == EINTR || errno == EAGAIN || errno == EWOULDBLOCK;
}

@interface LKMCPServerRuntime ()

@property(nonatomic, assign, readwrite, getter=isRunning) BOOL running;
@property(nonatomic, assign, readwrite) NSUInteger listeningPort;
@property(nonatomic, strong, readwrite) LKMCPToolRouter *toolRouter;
@property(nonatomic, assign) int listenSocketFD;
@property(nonatomic, strong) dispatch_source_t acceptSource;
@property(nonatomic, strong) dispatch_queue_t serverQueue;
@property(nonatomic, copy) NSString *authorizationToken;
@property(nonatomic, copy) NSString *clientProtocolVersion;
@property(nonatomic, assign) BOOL clientDidInitialize;

@end

@implementation LKMCPServerRuntime

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    static LKMCPServerRuntime *instance = nil;
    dispatch_once(&onceToken,^{
        instance = [[super allocWithZone:NULL] init];
    });
    return instance;
}

+ (id)allocWithZone:(struct _NSZone *)zone {
    return [self sharedInstance];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _toolRouter = [[LKMCPToolRouter alloc] initWithContextService:nil codeInfoService:nil];
        _serverQueue = dispatch_queue_create("com.lookin.mcp.server", DISPATCH_QUEUE_SERIAL);
        _listenSocketFD = -1;
        _clientProtocolVersion = kLKMCPProtocolVersion;
        _clientDidInitialize = NO;
    }
    return self;
}

- (BOOL)startWithPort:(NSUInteger)port error:(NSError *__autoreleasing  _Nullable *)error {
    if (self.running) {
        return YES;
    }
    if (port == 0) {
        if (error) {
            *error = [LKMCPError errorWithCode:LKMCPErrorCodeBadArgument
                                       message:@"Invalid MCP port."
                                   recoverable:YES
                                          hint:@"Use a valid loopback port."
                                     sessionId:nil];
        }
        return NO;
    }

    NSUInteger resolvedPort = 0;
    int listenFD = [self _createListenSocketWithPreferredPort:port resolvedPort:&resolvedPort error:error];
    if (listenFD < 0) {
        LKMCPRuntimeLog(@"failed to start at preferred port=%@ (bind failed)", @(port));
        return NO;
    }

    self.listenSocketFD = listenFD;
    self.listeningPort = resolvedPort;
    self.authorizationToken = [[NSUUID UUID] UUIDString];
    self.clientProtocolVersion = kLKMCPProtocolVersion;
    self.clientDidInitialize = NO;
    [self _startAcceptLoopWithSocketFD:listenFD];
    self.running = YES;
    LKMCPRuntimeLog(@"started, listeningPort=%@", @(resolvedPort));
    return YES;
}

- (void)stop {
    if (self.acceptSource) {
        dispatch_source_cancel(self.acceptSource);
        self.acceptSource = nil;
    } else if (self.listenSocketFD >= 0) {
        close(self.listenSocketFD);
    }
    self.listenSocketFD = -1;
    self.authorizationToken = nil;
    self.clientProtocolVersion = kLKMCPProtocolVersion;
    self.clientDidInitialize = NO;
    self.sessionId = nil;
    self.running = NO;
    self.listeningPort = 0;
    LKMCPRuntimeLog(@"stopped");
}

- (NSDictionary<NSString *,id> *)handleToolRequestWithName:(NSString *)toolName
                                                  arguments:(NSDictionary<NSString *,id> *)arguments
                                                      error:(NSError *__autoreleasing  _Nullable *)error {
    if (!self.running) {
        if (error) {
            *error = [LKMCPError errorWithCode:LKMCPErrorCodeNoSession
                                       message:@"MCP runtime is not running."
                                   recoverable:YES
                                          hint:@"Start MCP runtime first."
                                     sessionId:nil];
        }
        return nil;
    }
    NSDictionary<NSString *, id> *result = [self.toolRouter routeToolName:toolName arguments:arguments error:error];
    NSString *resolvedSessionId = [self _extractSessionIdFromToolResult:result];
    self.sessionId = resolvedSessionId;
    if (!result && error && *error) {
        LKMCPRuntimeLog(@"tool failed, name=%@, error=%@", toolName ?: @"", (*error).localizedDescription ?: @"");
    }
    return result;
}

#pragma mark - HTTP Runtime

- (int)_createListenSocketWithPreferredPort:(NSUInteger)preferredPort
                                 resolvedPort:(NSUInteger *)resolvedPort
                                        error:(NSError *__autoreleasing  _Nullable *)error {
    for (NSUInteger offset = 0; offset <= kLKMCPPortFallbackCount; offset++) {
        NSUInteger port = preferredPort + offset;
        int fd = [self _bindLoopbackSocketAtPort:port];
        if (fd >= 0) {
            if (resolvedPort) {
                *resolvedPort = port;
            }
            return fd;
        }
        if (errno != EADDRINUSE) {
            LKMCPRuntimeLog(@"bind failed at port=%@, errno=%d", @(port), errno);
            break;
        }
    }

    if (error) {
        *error = [LKMCPError errorWithCode:LKMCPErrorCodeBadArgument
                                   message:[NSString stringWithFormat:@"Failed to bind MCP loopback socket at port %@.", @(preferredPort)]
                               recoverable:YES
                                      hint:@"Check port availability and retry."
                                 sessionId:nil];
    }
    return -1;
}

- (int)_bindLoopbackSocketAtPort:(NSUInteger)port {
    int fd = socket(AF_INET, SOCK_STREAM, 0);
    if (fd < 0) {
        return -1;
    }

    int reuseAddr = 1;
    setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &reuseAddr, sizeof(reuseAddr));

    int currentFlags = fcntl(fd, F_GETFL, 0);
    if (currentFlags >= 0) {
        fcntl(fd, F_SETFL, currentFlags | O_NONBLOCK);
    }

    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_len = sizeof(addr);
    addr.sin_family = AF_INET;
    addr.sin_port = htons((in_port_t)port);
    addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);

    if (bind(fd, (struct sockaddr *)&addr, sizeof(addr)) != 0) {
        close(fd);
        return -1;
    }

    if (listen(fd, SOMAXCONN) != 0) {
        close(fd);
        return -1;
    }
    return fd;
}

- (void)_startAcceptLoopWithSocketFD:(int)socketFD {
    // Keep accept on serial queue; each accepted client is handled on utility queue.
    __weak typeof(self) weakSelf = self;
    self.acceptSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, (uintptr_t)socketFD, 0, self.serverQueue);
    dispatch_source_set_event_handler(self.acceptSource,^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        [strongSelf _acceptPendingClients];
    });
    dispatch_source_set_cancel_handler(self.acceptSource,^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        if (strongSelf.listenSocketFD >= 0) {
            close(strongSelf.listenSocketFD);
            strongSelf.listenSocketFD = -1;
        }
    });
    dispatch_resume(self.acceptSource);
}

- (void)_acceptPendingClients {
    while (YES) {
        int clientFD = accept(self.listenSocketFD, NULL, NULL);
        if (clientFD < 0) {
            if (errno == EAGAIN || errno == EWOULDBLOCK) {
                return;
            }
            return;
        }
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            [self _handleClientConnection:clientFD];
        });
    }
}

- (void)_handleClientConnection:(int)clientFD {
    @autoreleasepool {
        // Accepted sockets may inherit non-blocking mode from listen socket.
        // For this simple HTTP runtime we rely on SO_RCVTIMEO/SO_SNDTIMEO,
        // so switch client socket back to blocking mode to avoid transient EAGAIN.
        int clientFlags = fcntl(clientFD, F_GETFL, 0);
        if (clientFlags >= 0) {
            fcntl(clientFD, F_SETFL, clientFlags & ~O_NONBLOCK);
        }
        
        struct timeval timeout;
        timeout.tv_sec = 5;
        timeout.tv_usec = 0;
        setsockopt(clientFD, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));
        setsockopt(clientFD, SOL_SOCKET, SO_SNDTIMEO, &timeout, sizeof(timeout));

        NSError *readError = nil;
        NSDictionary<NSString *, id> *request = [self _readHTTPRequestFromSocket:clientFD error:&readError];
        if (!request) {
            NSDictionary *errorEnvelope = [self _errorEnvelopeWithError:readError ?: [LKMCPError errorWithCode:LKMCPErrorCodeBadArgument
                                                                                                         message:@"Invalid HTTP request."
                                                                                                     recoverable:YES
                                                                                                            hint:@"Use POST /mcp with JSON-RPC body."
                                                                                                       sessionId:nil]
                                                                sessionId:nil];
            [self _sendJSONPayload:errorEnvelope statusCode:400 socketFD:clientFD];
            close(clientFD);
            return;
        }

        NSString *method = request[@"method"];
        NSString *path = request[@"path"];
        NSDictionary<NSString *, NSString *> *headers = request[@"headers"];
        NSData *bodyData = request[@"body"];

        if (![path isEqualToString:kLKMCPHTTPPathMCP]) {
            NSDictionary *payload = @{
                @"error": @{
                    @"code": @404,
                    @"message": @"Not Found",
                    @"data": @{
                        @"code": LKMCPErrorCodeBadArgument,
                        @"message": @"Unsupported MCP endpoint.",
                        @"recoverable": @YES,
                        @"hint": @"Use POST /mcp.",
                        @"timestamp": [LKMCPError currentTimestampMs]
                    }
                }
            };
            [self _sendJSONPayload:payload statusCode:404 socketFD:clientFD];
            close(clientFD);
            return;
        }

        if ([method isEqualToString:kLKMCPHTTPMethodGET]) {
            NSDictionary *payload = @{
                @"error": @{
                    @"code": @405,
                    @"message": @"Method Not Allowed",
                    @"data": @{
                        @"code": LKMCPErrorCodeBadArgument,
                        @"message": @"GET is not supported by this MCP runtime.",
                        @"recoverable": @YES,
                        @"hint": @"Use POST /mcp with JSON-RPC body.",
                        @"timestamp": [LKMCPError currentTimestampMs]
                    }
                }
            };
            [self _sendJSONPayload:payload statusCode:405 socketFD:clientFD extraHeaders:@{
                @"MCP-Protocol-Version": kLKMCPProtocolVersion
            }];
            close(clientFD);
            return;
        }

        if (![method isEqualToString:kLKMCPHTTPMethodPOST]) {
            NSDictionary *payload = @{
                @"error": @{
                    @"code": @405,
                    @"message": @"Method Not Allowed",
                    @"data": @{
                        @"code": LKMCPErrorCodeBadArgument,
                        @"message": @"Unsupported HTTP method.",
                        @"recoverable": @YES,
                        @"hint": @"Use POST /mcp with JSON-RPC body.",
                        @"timestamp": [LKMCPError currentTimestampMs]
                    }
                }
            };
            [self _sendJSONPayload:payload statusCode:405 socketFD:clientFD extraHeaders:@{
                @"MCP-Protocol-Version": kLKMCPProtocolVersion
            }];
            close(clientFD);
            return;
        }

        // Optional token check, kept disabled for current local integration.

        NSError *jsonError = nil;
        id requestJSON = [NSJSONSerialization JSONObjectWithData:bodyData options:0 error:&jsonError];
        if (![requestJSON isKindOfClass:[NSDictionary class]] || jsonError) {
            NSError *parseError = [LKMCPError errorWithCode:LKMCPErrorCodeBadArgument
                                                    message:@"Request body must be JSON object."
                                                recoverable:YES
                                                       hint:@"Use JSON-RPC 2.0 payload, e.g. initialize/tools/call."
                                                  sessionId:nil];
            [self _sendJSONPayload:[self _errorEnvelopeWithError:parseError sessionId:nil] statusCode:400 socketFD:clientFD];
            close(clientFD);
            return;
        }

        NSDictionary *requestDict = (NSDictionary *)requestJSON;
        __block NSDictionary *responsePayload = nil;
        __block NSInteger statusCode = 200;
        __block NSDictionary<NSString *, NSString *> *extraHeaders = nil;
        dispatch_sync(dispatch_get_main_queue(), ^{
            responsePayload = [self _handleMCPRequestJSON:requestDict
                                                  headers:headers
                                               statusCode:&statusCode
                                             extraHeaders:&extraHeaders];
        });

        [self _sendJSONPayload:responsePayload ?: @{}
                     statusCode:statusCode
                       socketFD:clientFD
                   extraHeaders:extraHeaders];
        close(clientFD);
    }
}

- (NSDictionary<NSString *, id> *)_handleMCPRequestJSON:(NSDictionary<NSString *, id> *)requestJSON
                                                 headers:(NSDictionary<NSString *, NSString *> *)headers
                                              statusCode:(NSInteger *)statusCode
                                            extraHeaders:(NSDictionary<NSString *, NSString *> * __autoreleasing *)extraHeaders {
    NSMutableDictionary<NSString *, NSString *> *resolvedHeaders = [NSMutableDictionary dictionary];
    resolvedHeaders[@"MCP-Protocol-Version"] = kLKMCPProtocolVersion;
    if (self.sessionId.length > 0) {
        resolvedHeaders[@"Mcp-Session-Id"] = self.sessionId;
    }
    if (extraHeaders) {
        *extraHeaders = [resolvedHeaders copy];
    }

    return [self _handleJSONRPCRequest:requestJSON headers:headers statusCode:statusCode];
}

- (NSDictionary<NSString *, id> *)_handleJSONRPCRequest:(NSDictionary<NSString *, id> *)requestJSON
                                                headers:(NSDictionary<NSString *, NSString *> *)headers
                                             statusCode:(NSInteger *)statusCode {
    NSString *jsonrpc = [requestJSON[@"jsonrpc"] isKindOfClass:[NSString class]] ? requestJSON[@"jsonrpc"] : nil;
    id requestId = requestJSON[@"id"];
    BOOL hasRequestId = requestId != nil && requestId != [NSNull null];
    id responseId = hasRequestId ? requestId : [NSNull null];
    NSString *method = [requestJSON[@"method"] isKindOfClass:[NSString class]] ? requestJSON[@"method"] : nil;

    if (![jsonrpc isEqualToString:kLKMCPJSONRPCVersion] || method.length == 0) {
        if (statusCode) {
            *statusCode = 400;
        }
        return [self _jsonRPCErrorWithId:responseId
                                    code:-32600
                                 message:@"Invalid Request"
                                    data:@{
                                        @"hint": @"Use JSON-RPC 2.0 and include method."
                                    }];
    }

    NSString *requestedProtocolVersion = headers[@"mcp-protocol-version"];
    if (requestedProtocolVersion.length > 0 && ![requestedProtocolVersion isEqualToString:kLKMCPProtocolVersion]) {
        if (statusCode) {
            *statusCode = 400;
        }
        return [self _jsonRPCErrorWithId:responseId
                                    code:-32602
                                 message:@"Unsupported MCP protocol version."
                                    data:@{
                                        @"expected": kLKMCPProtocolVersion,
                                        @"received": requestedProtocolVersion
                                    }];
    }

    if ([method isEqualToString:@"initialize"]) {
        if (!hasRequestId) {
            if (statusCode) {
                *statusCode = 400;
            }
            return [self _jsonRPCErrorWithId:[NSNull null]
                                        code:-32600
                                     message:@"initialize must include request id."
                                        data:nil];
        }
        NSDictionary<NSString *, id> *params = [requestJSON[@"params"] isKindOfClass:[NSDictionary class]] ? requestJSON[@"params"] : @{};
        NSString *clientProtocolVersion = [params[@"protocolVersion"] isKindOfClass:[NSString class]] ? params[@"protocolVersion"] : nil;
        self.clientProtocolVersion = clientProtocolVersion.length > 0 ? clientProtocolVersion : kLKMCPProtocolVersion;
        self.clientDidInitialize = NO;
        NSDictionary<NSString *, id> *result = @{
            @"protocolVersion": kLKMCPProtocolVersion,
            @"capabilities": @{
                @"tools": @{
                    @"listChanged": @NO
                }
            },
            @"serverInfo": @{
                @"name": @"lookin-mcp",
                @"version": @"1.0.0"
            }
        };
        if (statusCode) {
            *statusCode = 200;
        }
        return [self _jsonRPCResultWithId:responseId result:result];
    }

    if ([method isEqualToString:@"notifications/initialized"]) {
        self.clientDidInitialize = YES;
        if (hasRequestId) {
            if (statusCode) {
                *statusCode = 200;
            }
            return [self _jsonRPCResultWithId:responseId result:[NSNull null]];
        }
        if (statusCode) {
            *statusCode = 202;
        }
        return @{};
    }

    if ([method isEqualToString:@"tools/list"]) {
        NSDictionary<NSString *, id> *result = @{
            @"tools": [self.toolRouter mcpToolDefinitions]
        };
        if (statusCode) {
            *statusCode = 200;
        }
        return [self _jsonRPCResultWithId:responseId result:result];
    }

    if ([method isEqualToString:@"tools/call"]) {
        NSDictionary<NSString *, id> *params = [requestJSON[@"params"] isKindOfClass:[NSDictionary class]] ? requestJSON[@"params"] : nil;
        if (!params) {
            if (statusCode) {
                *statusCode = 400;
            }
            return [self _jsonRPCErrorWithId:responseId
                                        code:-32602
                                     message:@"Invalid params"
                                        data:@{
                                            @"hint": @"params must be an object with name and arguments."
                                        }];
        }
        NSString *toolName = [params[@"name"] isKindOfClass:[NSString class]] ? params[@"name"] : nil;
        if (toolName.length == 0) {
            if (statusCode) {
                *statusCode = 400;
            }
            return [self _jsonRPCErrorWithId:responseId
                                        code:-32602
                                     message:@"Invalid params"
                                        data:@{
                                            @"hint": @"tools/call requires non-empty params.name."
                                        }];
        }

        id rawArguments = params[@"arguments"];
        NSDictionary<NSString *, id> *arguments = nil;
        if (!rawArguments || rawArguments == [NSNull null]) {
            arguments = @{};
        } else if ([rawArguments isKindOfClass:[NSDictionary class]]) {
            arguments = rawArguments;
        } else {
            if (statusCode) {
                *statusCode = 400;
            }
            return [self _jsonRPCErrorWithId:responseId
                                        code:-32602
                                     message:@"Invalid params"
                                        data:@{
                                            @"hint": @"params.arguments must be an object."
                                        }];
        }

        NSError *toolError = nil;
        NSDictionary<NSString *, id> *toolResult = [self handleToolRequestWithName:toolName arguments:arguments error:&toolError];
        NSDictionary<NSString *, id> *callResult = nil;
        if (toolResult) {
            NSString *toolSummaryText = [self _serializedJSONStringFromObject:toolResult] ?: @"{}";
            callResult = @{
                @"content": @[
                    @{
                        @"type": @"text",
                        @"text": toolSummaryText
                    }
                ],
                @"structuredContent": toolResult
            };
        } else {
            NSDictionary<NSString *, id> *errorData = [LKMCPError errorDataFromError:toolError
                                                                          defaultCode:LKMCPErrorCodeBadArgument
                                                                       defaultMessage:@"MCP tool call failed."
                                                                            sessionId:self.sessionId];
            NSString *errorText = [NSString stringWithFormat:@"Tool %@ failed: %@", toolName, errorData[@"message"] ?: @"Unknown error"];
            callResult = @{
                @"isError": @YES,
                @"content": @[
                    @{
                        @"type": @"text",
                        @"text": errorText
                    }
                ],
                @"structuredContent": @{
                    @"error": errorData
                }
            };
        }
        if (statusCode) {
            *statusCode = 200;
        }
        return [self _jsonRPCResultWithId:responseId result:callResult];
    }

    if ([method isEqualToString:@"ping"]) {
        if (statusCode) {
            *statusCode = 200;
        }
        return [self _jsonRPCResultWithId:responseId result:@{}];
    }

    if ([method hasPrefix:@"notifications/"] && !hasRequestId) {
        if (statusCode) {
            *statusCode = 202;
        }
        return @{};
    }

    if (statusCode) {
        *statusCode = 400;
    }
    return [self _jsonRPCErrorWithId:responseId
                                code:-32601
                             message:@"Method not found"
                                data:@{
                                    @"method": method ?: @""
                                }];
}

- (NSDictionary<NSString *, id> *)_jsonRPCResultWithId:(id)requestId
                                                 result:(id)result {
    id safeResult = result ?: [NSNull null];
    return @{
        @"jsonrpc": kLKMCPJSONRPCVersion,
        @"id": requestId ?: [NSNull null],
        @"result": safeResult
    };
}

- (NSDictionary<NSString *, id> *)_jsonRPCErrorWithId:(id)requestId
                                                  code:(NSInteger)code
                                               message:(NSString *)message
                                                  data:(NSDictionary<NSString *, id> * _Nullable)data {
    NSMutableDictionary<NSString *, id> *error = [NSMutableDictionary dictionary];
    error[@"code"] = @(code);
    error[@"message"] = message ?: @"Unknown JSON-RPC error";
    if (data.count > 0) {
        error[@"data"] = data;
    }
    return @{
        @"jsonrpc": kLKMCPJSONRPCVersion,
        @"id": requestId ?: [NSNull null],
        @"error": error
    };
}

- (NSString *)_serializedJSONStringFromObject:(id)object {
    if (!object) {
        return nil;
    }
    NSError *jsonError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:object options:0 error:&jsonError];
    if (!jsonData || jsonError) {
        return nil;
    }
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

- (NSDictionary<NSString *, id> *)_readHTTPRequestFromSocket:(int)socketFD
                                                        error:(NSError *__autoreleasing  _Nullable *)error {
    // Read in two phases: header first, then body by Content-Length.
    NSMutableData *buffer = [NSMutableData data];
    NSRange headerRange = NSMakeRange(NSNotFound, 0);

    while (headerRange.location == NSNotFound && buffer.length < kLKMCPMaxHTTPRequestBytes) {
        uint8_t chunk[2048];
        ssize_t bytesRead = recv(socketFD, chunk, sizeof(chunk), 0);
        if (bytesRead < 0) {
            if (LKMCPShouldRetrySocketRead()) {
                continue;
            }
            if (error) {
                *error = [LKMCPError errorWithCode:LKMCPErrorCodeBadArgument
                                           message:@"Failed to read HTTP request."
                                       recoverable:YES
                                              hint:@"Retry the MCP request."
                                         sessionId:nil];
            }
            return nil;
        }
        if (bytesRead == 0) {
            if (error) {
                *error = [LKMCPError errorWithCode:LKMCPErrorCodeBadArgument
                                           message:@"Failed to read HTTP request."
                                       recoverable:YES
                                              hint:@"Retry the MCP request."
                                         sessionId:nil];
            }
            return nil;
        }
        [buffer appendBytes:chunk length:(NSUInteger)bytesRead];
        headerRange = [buffer rangeOfData:[@"\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]
                                  options:0
                                    range:NSMakeRange(0, buffer.length)];
    }

    if (headerRange.location == NSNotFound) {
        if (error) {
            *error = [LKMCPError errorWithCode:LKMCPErrorCodeBadArgument
                                       message:@"HTTP request header is incomplete."
                                   recoverable:YES
                                          hint:@"Ensure request includes valid HTTP headers."
                                     sessionId:nil];
        }
        return nil;
    }

    NSData *headerData = [buffer subdataWithRange:NSMakeRange(0, headerRange.location)];
    NSString *headerText = [[NSString alloc] initWithData:headerData encoding:NSUTF8StringEncoding];
    if (headerText.length == 0) {
        if (error) {
            *error = [LKMCPError errorWithCode:LKMCPErrorCodeBadArgument
                                       message:@"HTTP header is empty."
                                   recoverable:YES
                                          hint:@"Use valid HTTP request format."
                                     sessionId:nil];
        }
        return nil;
    }

    NSArray<NSString *> *lines = [headerText componentsSeparatedByString:@"\r\n"];
    if (lines.count == 0) {
        return nil;
    }
    NSArray<NSString *> *requestLine = [lines.firstObject componentsSeparatedByString:@" "];
    if (requestLine.count < 2) {
        if (error) {
            *error = [LKMCPError errorWithCode:LKMCPErrorCodeBadArgument
                                       message:@"Invalid HTTP request line."
                                   recoverable:YES
                                          hint:@"Use 'POST /mcp HTTP/1.1'."
                                     sessionId:nil];
        }
        return nil;
    }

    NSMutableDictionary<NSString *, NSString *> *headers = [NSMutableDictionary dictionary];
    for (NSUInteger idx = 1; idx < lines.count; idx++) {
        NSString *line = lines[idx];
        NSRange colonRange = [line rangeOfString:@":"];
        if (colonRange.location == NSNotFound) {
            continue;
        }
        NSString *key = [[line substringToIndex:colonRange.location] lowercaseString];
        NSString *value = [[line substringFromIndex:colonRange.location + 1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (key.length > 0) {
            headers[key] = value ?: @"";
        }
    }

    NSUInteger contentLength = (NSUInteger)[headers[@"content-length"] integerValue];
    NSUInteger bodyStartIndex = headerRange.location + headerRange.length;
    while ((buffer.length - bodyStartIndex) < contentLength && buffer.length < kLKMCPMaxHTTPRequestBytes) {
        uint8_t chunk[2048];
        ssize_t bytesRead = recv(socketFD, chunk, sizeof(chunk), 0);
        if (bytesRead < 0) {
            if (LKMCPShouldRetrySocketRead()) {
                continue;
            }
            break;
        }
        if (bytesRead == 0) {
            break;
        }
        [buffer appendBytes:chunk length:(NSUInteger)bytesRead];
    }

    if ((buffer.length - bodyStartIndex) < contentLength) {
        if (error) {
            *error = [LKMCPError errorWithCode:LKMCPErrorCodeBadArgument
                                       message:@"HTTP body size is shorter than Content-Length."
                                   recoverable:YES
                                          hint:@"Ensure complete JSON body is sent."
                                     sessionId:nil];
        }
        return nil;
    }

    NSData *bodyData = [NSData data];
    if (contentLength > 0) {
        bodyData = [buffer subdataWithRange:NSMakeRange(bodyStartIndex, contentLength)];
    }

    return @{
        @"method": requestLine[0],
        @"path": requestLine[1],
        @"headers": headers,
        @"body": bodyData
    };
}

- (NSDictionary<NSString *, id> *)_errorEnvelopeWithError:(NSError *)error
                                                 sessionId:(NSString *)sessionId {
    NSDictionary<NSString *, id> *errorData = [LKMCPError errorDataFromError:error
                                                                 defaultCode:LKMCPErrorCodeBadArgument
                                                              defaultMessage:@"MCP tool call failed."
                                                                   sessionId:sessionId];
    return @{
        @"error": @{
            @"code": @-32000,
            @"message": errorData[@"message"] ?: @"MCP tool call failed.",
            @"data": errorData
        }
    };
}

- (void)_sendJSONPayload:(NSDictionary<NSString *, id> *)payload
               statusCode:(NSInteger)statusCode
                 socketFD:(int)socketFD {
    [self _sendJSONPayload:payload statusCode:statusCode socketFD:socketFD extraHeaders:nil];
}

- (void)_sendJSONPayload:(NSDictionary<NSString *, id> *)payload
              statusCode:(NSInteger)statusCode
                socketFD:(int)socketFD
            extraHeaders:(NSDictionary<NSString *, NSString *> * _Nullable)extraHeaders {
    NSError *jsonError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:payload ?: @{} options:0 error:&jsonError];
    if (!jsonData || jsonError) {
        jsonData = [@"{}" dataUsingEncoding:NSUTF8StringEncoding];
    }

    NSString *statusText = @"Bad Request";
    if (statusCode == 200) {
        statusText = @"OK";
    } else if (statusCode == 202) {
        statusText = @"Accepted";
    } else if (statusCode == 404) {
        statusText = @"Not Found";
    } else if (statusCode == 405) {
        statusText = @"Method Not Allowed";
    }

    NSMutableString *header = [NSMutableString stringWithFormat:
                               @"HTTP/1.1 %ld %@\r\n"
                               @"Content-Type: application/json; charset=utf-8\r\n"
                               @"Content-Length: %lu\r\n"
                               @"Connection: close\r\n",
                               (long)statusCode,
                               statusText,
                               (unsigned long)jsonData.length];
    [extraHeaders enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSString * _Nonnull obj, BOOL * _Nonnull stop) {
        if (key.length > 0 && obj.length > 0) {
            [header appendFormat:@"%@: %@\r\n", key, obj];
        }
    }];
    [header appendString:@"\r\n"];

    NSData *headerData = [header dataUsingEncoding:NSUTF8StringEncoding];
    [self _writeAllData:headerData toSocket:socketFD];
    [self _writeAllData:jsonData toSocket:socketFD];
}

- (NSString *)_extractSessionIdFromToolResult:(NSDictionary<NSString *, id> *)result {
    if (![result isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    NSString *directSessionId = [result[@"sessionId"] isKindOfClass:[NSString class]] ? result[@"sessionId"] : nil;
    if (directSessionId.length > 0) {
        return directSessionId;
    }
    NSDictionary *session = [result[@"session"] isKindOfClass:[NSDictionary class]] ? result[@"session"] : nil;
    NSString *nestedSessionId = [session[@"sessionId"] isKindOfClass:[NSString class]] ? session[@"sessionId"] : nil;
    if (nestedSessionId.length > 0) {
        return nestedSessionId;
    }
    return nil;
}

- (void)_writeAllData:(NSData *)data toSocket:(int)socketFD {
    const uint8_t *bytes = (const uint8_t *)data.bytes;
    NSUInteger left = data.length;
    while (left > 0) {
        ssize_t written = send(socketFD, bytes, left, 0);
        if (written <= 0) {
            return;
        }
        bytes += written;
        left -= (NSUInteger)written;
    }
}

@end
