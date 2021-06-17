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
* getFn: ?fn(*c_void, *const zupnp.web.Request) zupnp.web.Response
* postFn: ?fn(*c_void, *const zupnp.web.Request) bool

## [X] zupnp.web.Request
* allocator: *Allocator
* filename: [:0]const u8

## [X] zupnp.web.Response (union)
* NotFound: void
* Forbidden: void
* Chunked: TODO callback to get chunked contents
* OK: ```struct {
    contents: [:0]const u8,
    content_type: [:0]const u8,
    extra_headers: TODO,
  }```

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
