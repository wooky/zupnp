# API Redesign
## zupnp.ZUPnP
* server: zupnp.web.Server
* init(allocator: *Allocator, config: Config) !zupnp.ZUPnP
* deinit(self) void
* createDevice(self, T: type) !*T
* registerDevice(self, device: *type) !void

### zupnp.ZUPnP.Config
* if_name: ?[]const u8 = null
* port: u16 = 0

## zupnp.web.Server
* pub static_root_dir: ?[:0]const u8 = null
* endpoints: ArrayList(Endpoint)
* init(allocator: *Allocator) zupnp.web.Server
* deinit(self) void
* createEndpoint(self, T: type, destination: []const u8) !*T
* start(self) !void
* stop(self) void
* static methods from existing zupnp.web.Endpoint

### zupnp.web.Server.Endpoint
* instance: *c_void
* deinitFn: ?fn(instance: *c_void) void
* getFn: ?fn(*c_void, *const zupnp.web.Request) zupnp.web.Response
* postFn: ?fn(*c_void, *const zupnp.web.Request) zupnp.web.Response

## zupnp.web.Request
Fill as needed

## zupnp.web.Response
Fill as needed

## zupnp.upnp.Action
* allocator: *Allocator
* request: *c.UpnpActionRequest
* getServiceId(self) ?[:0]const u8
* getActionName(self) ?[:0]const u8
* parseRequest(self, T: type) !T
* setResult(self, result: type) !void
* setErrorCode(self, code: c_int) !void

# Abstract File Requirements
## Endpoint
* init(allocator: *Allocator) !@Self
* deinit(instance: *c_void) void (optional)
* get(instance: *c_void, request: *zupnp.web.Request) zupnp.web.Response (optional)
* post(instance: *c_void, request: *zupnp.web.Request) zupnp.web.Response (optional)

## Device
* pub schema: (any struct)
* init(allocator: *Allocator) !@Self
* deinit(instance: *c_void) void (optional)
* handleAction(instance: *c_void, action: *zupnp.upnp.Action) !void (optional)
