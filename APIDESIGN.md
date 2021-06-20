# API Redesign
## [ ] zupnp.ZUPnP
* pub server: zupnp.web.Server
* pub device_manager: zupnp.upnp.DeviceManager
* init(allocator: *Allocator, config: Config) !zupnp.ZUPnP
* deinit(self) void

### [X] zupnp.ZUPnP.Config
* if_name: ?[]const u8 = null
* port: u16 = 0

## [X] zupnp.web.Server
* pub static_root_dir: ?[:0]const u8 = null
* endpoints: ArrayList(Endpoint)
* init(allocator: *Allocator) zupnp.web.Server
* deinit(self) void
* createEndpoint(self, T: type, config: type, destination: [:0]const u8) !*T
* start(self) !void
* stop(self) void
* static methods from existing zupnp.web.Endpoint

### [X] zupnp.web.Server.Endpoint
* instance: *c_void
* allocator: *Allocator
* deinitFn: ?fn(instance: *c_void) void
* getFn: ?fn(*c_void, *const zupnp.web.ServerRequest) zupnp.web.ServerResponse
* postFn: ?fn(*c_void, *const zupnp.web.ServerRequest) bool

## [X] zupnp.web.ServerRequest
* allocator: *Allocator
* filename: [:0]const u8

## [X] zupnp.web.ServerResponse (union)
* NotFound: void
* Forbidden: void
* Chunked: TODO callback to get chunked contents
* Contents: zupnp.web.HttpContents

## [X] zupnp.web.Client
* pub timeout: ?c_int = null
* pub keepalive: bool = false
* handle: ?*c_void = null
* init() zupnp.web.Client
* deinit(self) void
* request(self, allocator: *Allocator, method: zupnp.web.Method, url: [:0]const u8, request: zupnp.web.HttpContents) !zupnp.web.ClientResponse
* chunkedRequest(self, method: zupnp.web.Method, url: [:0]const u8, request: zupnp.web.HttpContents) !zupnp.web.ChunkedClientResponse
* close(self) void

## [X] zupnp.web.Method (enum)
* PUT = 0
* DELETE = 1
* GET = 2
* HEAD = 3
* POST = 4

## [X] zupnp.web.HttpContents
* headers: [][]const u8 = [_] {}
* content_type: ?[:0]const u8 = null
* contents: []const u8 = ""

## [X] zupnp.web.ClientResponse
* http_status: c_int
* content_type: [:0]const u8
* contents: [:0]const u8

# [X] zupnp.web.ChunkedClientResponse
* pub http_status: c_int
* pub content_type: [:0]const u8
* pub content_length: isize
* handle: *c_void
* keepalive: bool
* readChunk(self, buf: []u8) !bool
* cancel(self) void

## [ ] zupnp.upnp.DeviceManager
* devices: std.AutoHashMap(*c_void, Device)
* init(allocator: *Allocator) @Self
* deinit(self) void
* create(self, T: type) !*T
* register(self, device: *type) !void

### [ ] zupnp.upnp.DeviceManager.Device
* handle: *c.UpnpDevice_Handle
* deinitFn: ?fn(*c_void) void
* handleActionFn: ?fn(*c_void, *zupnp.upnp.Action) !void

## [ ] zupnp.upnp.Action
* allocator: *Allocator
* request: *c.UpnpActionRequest
* getServiceId(self) ?[:0]const u8
* getActionName(self) ?[:0]const u8
* parseRequest(self, T: type) !T
* setResult(self, result: type) !void
* setErrorCode(self, code: c_int) !void

# Abstract File Requirements
## Endpoint
* prepare(self, config: type) !void (optional)
* deinit(instance: *c_void) void (optional)
* get(instance: *c_void, request: *const zupnp.web.Request) zupnp.web.Response (optional)
* post(instance: *c_void, request: *const zupnp.web.Request) bool (optional)

## Device
* pub schema: (any struct)
* init(allocator: *Allocator) !@Self
* deinit(instance: *c_void) void (optional)
* handleAction(instance: *c_void, action: *zupnp.upnp.Action) !void (optional)
