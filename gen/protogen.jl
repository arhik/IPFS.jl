using ProtoBuf

protojl("../src/protos/ipld.proto", @__DIR__, "$(@__DIR__)/../src/jlprotos")
protojl("../src/protos/unixfsV1.proto", @__DIR__, "$(@__DIR__)/../src/jlprotos")
protojl("../src/protos/bitswap.proto", @__DIR__, "$(@__DIR__)/../src/jlprotos")
