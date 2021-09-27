// TODO testing this is not very useful because pupnp first fills up its internal buffer inside the endpoint before returning content to the client.
// Testing true chunked requests is more useful.
// One notable thing to watch out for is when a program tries to exit before a ClientResponse gets closed.
// In that case, the program will never exit!
