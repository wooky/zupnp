const network = @import("network");
const serve = @import("serve");

pub const HttpServer = struct {

};

pub const UdpServer = struct {
    sock: network.Socket,

    fn init() !UdpServer {
        const sock = try network.Socket.create(.ipv4, .udp);
        errdefer sock.close();
        try sock.bindToPort(1900);
        try sock.enablePortReuse(true);
        try sock.joinMulticastGroup(.{
            .interface = network.Address.IPv4.any,
            .group = network.Address.IPv4.init(239, 255, 255, 250),
        });

        return UdpServer {
            .sock = sock,
        };
    }

    fn deinit(self: *UdpServer) void {
        self.sock.close();
    }
};
