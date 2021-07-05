const std = @import("std");
const c = @import("../../c.zig");
const zupnp = @import("../../lib.zig");

const logger = std.log.scoped(.@"zupnp.upnp.device.action");

pub fn ActionFunction(comptime T: type) type {
    return fn(*T, ActionRequest) anyerror!ActionResult;
}

pub const ActionRequest = struct {
    handle: *const c.UpnpActionRequest,

    pub fn getDeviceUdn(self: *const ActionRequest) [:0]const u8 {
        return c.UpnpActionRequest_get_DevUDN_cstr(self.handle)[0..c.UpnpActionRequest_get_DevUDN_Length(self.handle):0];
    }

    pub fn getServiceId(self: *const ActionRequest) [:0]const u8 {
        return c.UpnpActionRequest_get_ServiceID_cstr(self.handle)[0..c.UpnpActionRequest_get_ServiceID_Length(self.handle):0];
    }

    pub fn getActionName(self: *const ActionRequest) [:0]const u8 {
        return c.UpnpActionRequest_get_ActionName_cstr(self.handle)[0..c.UpnpActionRequest_get_ActionName_Length(self.handle):0];
    }

    pub fn getActionRequest(self: *const ActionRequest) zupnp.xml.Document {
        return zupnp.xml.Document.init(c.UpnpActionRequest_get_ActionRequest(self.handle));
    }
};

pub const ActionResult = struct {
    action_result: ?zupnp.xml.Document, // DO NOT DEINIT! Used by ActionRequest when returning to client.
    err_code: c_int,

    pub fn createResult(action_name: [:0]const u8, service_type: [:0]const u8, arguments: anytype) !ActionResult {
        var doc: ?*c.IXML_Document = null;
        inline for (@typeInfo(@TypeOf(arguments)).Struct.fields) |field| {
            comptime const key = field.name ++ "\x00";
            const value: [:0]const u8 = @field(arguments, field.name);
            if (c.is_error(c.UpnpAddToActionResponse(&doc, action_name, service_type, key, value))) |err| {
                logger.err("Cannot create response: {s}", .{err});
                return zupnp.Error;
            }
        }
        return ActionResult {
            .action_result = zupnp.xml.Document.init(doc.?),
            .err_code = 0,
        };
    }

    pub fn createError(err_code: c_int) ActionResult {
        return .{
            .action_result = null,
            .err_code = err_code,
        };
    }
};