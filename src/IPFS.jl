module IPFS

using ProtoBuf

protojl("ipld.proto", ".", "protos")
protojl("unixfsV1.proto", ".", "protos")

end # module IPFS
