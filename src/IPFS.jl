module IPFS

using ProtoBuf

include(joinpath(@__DIR__, "src/jlProtos/ipldv1/ipldv1.jl"))
include(joinpath(@__DIR__, "src/jlProtos/unixfsv1/unixfsv1.jl"))
include(joinpath(@__DIR__, "src/jlProtos/bitswap/bitswap.jl"))

end # module IPFS
