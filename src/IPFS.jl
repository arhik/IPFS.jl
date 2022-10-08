module IPFS

using ProtoBuf

protojl("ipld.proto", @__DIR__, "$(@__DIR__)/protos")

protojl("unixfsV1.proto", @__DIR__, "$(@__DIR__)/protos")

end # module IPFS
