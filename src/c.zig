pub usingnamespace @cImport({
    @cInclude("upnp/upnp.h");
    @cInclude("upnp/upnptools.h");
});

pub fn is_error(err: c_int) ?[:0]const u8 {
    if (err == UPNP_E_SUCCESS) {
        return null;
    }
    return @import("std").mem.sliceTo(UpnpGetErrorMessage(err), 0);
}

pub fn mutate(comptime To: type, from: anytype) To {
    return @intToPtr(To, @ptrToInt(from));
}

pub fn mutateCallback(
    comptime InstanceType: type,
    comptime callback_fn_name: []const u8,
    comptime EndpointType: type
) ?EndpointType {
    if (!@hasDecl(InstanceType, callback_fn_name)) {
        return null;
    }

    const callback_fn = @field(InstanceType, callback_fn_name);
    const callback_fn_info = @typeInfo(@TypeOf(callback_fn)).Fn;
    const endpoint_type_info = @typeInfo(EndpointType).Fn;
    if (callback_fn_info.return_type.? != endpoint_type_info.return_type.?) {
        @compileError("Wrong callback return type");
    }
    if (callback_fn_info.args.len != endpoint_type_info.args.len) {
        @compileError("Callback has wrong number of arguments");
    }
    inline for (callback_fn_info.args) |arg, i| {
        if (i == 0 and arg.arg_type != *InstanceType) {
            @compileError("Argument 1 has wrong type");
        }
        if (i > 0 and arg.arg_type.? != endpoint_type_info.args[i].arg_type.?) {
            @compileError("Argument " ++ i + 1 ++ " has wrong type");
        }
    }

    return mutate(EndpointType, callback_fn);
}
