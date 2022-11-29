const std = @import("std");
const c = @import("../../c.zig");
const zupnp = @import("../../lib.zig");
const xml = @import("xml");

const logger = std.log.scoped(.@"zupnp.upnp.device.action");

pub const ActionRequest = struct {
    allocator: std.mem.Allocator,
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

    pub fn getActionRequest(self: *const ActionRequest) xml.Document {
        return xml.Document.init(c.mutate(*xml.c.IXML_Document, c.UpnpActionRequest_get_ActionRequest(self.handle)));
    }

    pub fn getClientAddress(self: *const ActionRequest) zupnp.util.ClientAddress {
        return zupnp.util.ClientAddress.fromSockaddStorage(c.UpnpActionRequest_get_CtrlPtIPAddr(self.handle));
    }
};

pub const ActionResult = struct {
    action_result: ?xml.Document, // DO NOT DEINIT! Once passed to UpnpActionRequest_set_ActionResult, it'll get automatically free'd.
    err_code: c_int,

    pub fn createResult(service_type: [:0]const u8, arguments: anytype) !ActionResult {
        const action_name = @TypeOf(arguments).action_name;
        var doc: ?*c.IXML_Document = null;
        inline for (@typeInfo(@TypeOf(arguments)).Struct.fields) |field| {
            const key = field.name ++ "\x00";
            const value: [:0]const u8 = @field(arguments, field.name);
            if (c.is_error(c.UpnpAddToActionResponse(&doc, action_name, service_type.ptr, key, value.ptr))) |err| {
                logger.err("Cannot create response: {s}", .{err});
                return zupnp.Error;
            }
        }
        return ActionResult {
            .action_result = xml.Document.init(c.mutate(*xml.c.IXML_Document, doc.?)),
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
