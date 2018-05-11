syntax = "proto3";

package {{ app_name }};

service {{ app_name }} {
    rpc Ping (Null) returns (Pong) {}
    rpc Error (Null) returns (Null) {}

    // Define API here below
}

message Null {}
message Pong {
    string pong = 1;
}

// Define message structures here below
