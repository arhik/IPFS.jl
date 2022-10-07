using ProtoBuf

using MultiFormats
using Base58

using DataStructures

include(joinpath(@__DIR__, "src/protos/ipld_pb.jl"))
include(joinpath(@__DIR__, "src/protos/unixfsV1_pb.jl"))

path = joinpath(@__DIR__, "src/test.pdf")

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

function fsEncode(size, blocksizes)
	io = IOBuffer()
	e = ProtoEncoder(io)
	unixfsDict = ProtoBuf.default_values(unixfsV1_pb.Data) |> pairs |> OrderedDict
	unixfsDict[Symbol("#Type")] = unixfsV1_pb.var"Data.DataType".File # TODO abstract this
	unixfsDict[:filesize] = size
	unixfsDict[:blocksizes] = blocksizes
	# unixfsDict[:fanout] = length(blocksizes)
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

function nodeEncode(links::Vector{ipld_pb.PBLink}, data)
	io = IOBuffer()
	e = ProtoEncoder(io)
	encode(e, ipld_pb.PBNode(links, data))
	seekstart(io)
	take!(io)
end


function linkEncode(blk::Vector{UInt8}; idx=0, binary=false)
	io = IOBuffer()
	e = ProtoEncoder(io)
	cid = base58encode(blk)
	# encode(e, cid)
	# wrappedCID = cidWrap(cid; binary=binary)
	encode(e, ipld_pb.PBLink(
		cid,
		"Links/$idx",
		2^18
	))
	# ipld_pb.PBLink(
		# cid,
		# "Links/$idx",
		# length(blk)
	# )
	seekstart(io)
	take!(io)
end

function fsDecode()
	io = IOBuffer()
	d = ProtoDecoder(io)
	a = decode(d, ipld_pb.PBNode)
	return a
end

blockHashed = []
blockSizes = UInt64[]
links = ipld_pb.PBLink[]


for (idx, block) in enumerate(Base.Iterators.partition(pdfBytes, 2^18))
	fsBytes = fsEncode(block |> collect)
	nodeBytes = nodeEncode(fsBytes)
	hash = multiHash(:sha2_256, nodeBytes)
	wrappedmultiHash = hashWrap(:sha2_256, hash)
	push!(blockHashed, wrappedmultiHash)
	push!(blockSizes, length(block))
	push!(links, ipld_pb.PBLink(wrappedmultiHash, "Links/$idx", length(block)))
end

for hash in blockHashed
	@info hash |> bytes2hex |> uppercase
end

for link in links
	@info link.Hash |> base58encode |> String
end

fsBytes = fsEncode(length(pdfBytes), blockSizes)
nodeBytes = nodeEncode(links, fsBytes)
hash = multiHash(:sha2_256, nodeBytes)
wrappedHash = hashWrap(:sha2_256, hash)
base58encode(wrappedHash) .|> Char |> String
