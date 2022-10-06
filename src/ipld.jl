using ProtoBuf

using MultiFormats

using DataStructures

include(joinpath(@__DIR__, "protos/ipld_pb.jl"))
include(joinpath(@__DIR__, "protos/unixfsV1_pb.jl"))

path = "test.pdf"

pdfBytes = read(path)

unixfsNTuple = ProtoBuf.default_values(unixfsV1_pb.Data)

unixfsV1_pb.Data

abstract type AbstractUnixFS end

struct UnixFSV1 <: AbstractUnixFS
	internal::unixfsV1_pb.Data
end

# struct UnixFSV2 <: AbstractUnixFS
	# internal::unixfsV2_pb.Data
# end

UnixFSv1(tuple::NamedTuple) = UnixFSV1(
	unixfsV1_pb.Data(
		tuple...
	)
)

function Base.getproperty(fs::AbstractUnixFS, property::Symbol)
	internal = Base.getfield(fs, :internal)
	Base.getfield(internal, property)
end

function Base.setproperty!(fs::AbstractUnixFS, property::Symbol, val)
	internal = Base.getfield(fs, :internal)
	Base.setfield!(internal, property, val)
end

function fsEncode(blk::Vector{UInt8})
	io = IOBuffer()
	e = ProtoEncoder(io)
	unixfsDict = ProtoBuf.default_values(unixfsV1_pb.Data) |> pairs |> OrderedDict
	unixfsDict[:Data] = blk
	unixfsDict[Symbol("#Type")] = unixfsV1_pb.var"Data.DataType".File # TODO abstract this
	unixfsDict[:filesize] = length(blk)
	# unixfsDict[:mode] = 0x000001a4 # TODO abstract this
	fs = UnixFSv1(unixfsDict |> NamedTuple)
	encode(e, getfield(fs, :internal))
	seekstart(io)
	take!(io)
end

function fsEncode(blk::Vector{UInt8}, size, blocksizes)
	io = IOBuffer()
	e = ProtoEncoder(io)
	unixfsDict = ProtoBuf.default_values(unixfsV1_pb.Data) |> pairs |> OrderedDict
	unixfsDict[Symbol("#Type")] = unixfsV1_pb.var"Data.DataType".File # TODO abstract this
	unixfsDict[:filesize] = size
	unixfsDict[:blocksizes] = blocksizes
	unixfsDict[:mode] = 0x000001a4 # TODO abstract this
	fs = UnixFSv1(unixfsDict |> NamedTuple)
	encode(e, getfield(fs, :internal))
	seekstart(io)
	take!(io)
end

function nodeEncode(blk::Vector{UInt8})
	io = IOBuffer()
	e = ProtoEncoder(io)
	encode(e, ipld_pb.PBNode([], blk))
	seekstart(io)
	take!(io)
end

function linkEncode(blk::Vector{UInt8})

function fsDecode()
	io = IOBuffer()
	d = ProtoDecoder(io)
	a = decode(d, ipld_pb.PBNode)
	return a
end

blockHashed = []
blockSizes = UInt64[]

for (idx, block) in enumerate(Base.Iterators.partition(pdfBytes, 2^18))
	fsBytes = fsEncode(block |> collect)
	nodeBytes = nodeEncode(fsBytes)
	hash = multiHash(:sha2_256, nodeBytes)
	push!(blockHashed, hashWrap(:sha2_256, hash))
	push!(blockSizes, length(block))
	push!()
end



fsBytes = fsEncode(vcat(blockHashed...), length(pdfBytes), blockSizes)
nodeBytes = nodeEncode(fsBytes)
hash = multiHash(:sha2_256, nodeBytes)
hashWrap(:sha2_256, hash)
