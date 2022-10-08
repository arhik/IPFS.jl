using ProtoBuf

using MultiFormats
using Base58

using DataStructures

include(joinpath(@__DIR__, "src/protos/ipldv1/ipldv1.jl"))
include(joinpath(@__DIR__, "src/protos/unixfsv1/unixfsv1.jl"))

path = joinpath(@__DIR__, "src/test.pdf")

pdfBytes = read(path)

unixfsNTuple = ProtoBuf.default_values(unixfsV1.Data)

unixfsV1.Data

abstract type AbstractUnixFS end

struct UnixFSV1 <: AbstractUnixFS
	internal::unixfsV1.Data
end

# struct UnixFSV2 <: AbstractUnixFS
	# internal::unixfsV2.Data
# end

UnixFSv1(unixfsNTuple::NamedTuple) = UnixFSV1(
	unixfsV1.Data(
		unixfsNTuple...
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
	unixfsDict = ProtoBuf.default_values(unixfsV1.Data) |> pairs |> OrderedDict
	unixfsDict[:ByteData] = blk
	unixfsDict[Symbol("#Type")] = unixfsV1.var"Data.DataType".File # TODO abstract this
	unixfsDict[:filesize] = length(blk)
	# unixfsDict[:mode] = 0x000001a4 # TODO abstract this
	fs = UnixFSv1(unixfsDict |> NamedTuple)
	encode(e, getfield(fs, :internal))
	seekstart(io)
	take!(io)
end

function fsEncode(fsize, blocksizes)
	io = IOBuffer()
	e = ProtoEncoder(io)
	unixfsDict = ProtoBuf.default_values(unixfsV1.Data) |> pairs |> OrderedDict
	unixfsDict[Symbol("#Type")] = unixfsV1.var"Data.DataType".File # TODO abstract this
	# unixfsDict[:Data] = b".pdf"
	unixfsDict[:filesize] = fsize
	unixfsDict[:blocksizes] = blocksizes
	# unixfsDict[:fanout] = length(blocksizes)
	# unixfsDict[:mode] = 0x000001a4 # TODO abstract this
	fs = UnixFSv1(unixfsDict |> NamedTuple)
	encode(e, getfield(fs, :internal))
	seekstart(io)
	take!(io)
end

function nodeEncode(blk::Vector{UInt8})
	io = IOBuffer()
	e = ProtoEncoder(io)
	encode(e, ipldv1.PBNode([], blk))
	seekstart(io)
	take!(io)
end

function nodeEncode(links::Vector{ipldv1.PBLink}, data)
	io = IOBuffer()
	e = ProtoEncoder(io)
	encode(e, ipldv1.PBNode(links, data))
	seekstart(io)
	take!(io)
end


# function linkEncode(blk::Vector{UInt8}; idx=0, binary=false)
	# io = IOBuffer()
	# e = ProtoEncoder(io)
	# cid = base58encode(blk)
	# # encode(e, cid)
	# # wrappedCID = cidWrap(cid; binary=binary)
	# encode(e, ipldv1.PBLink(
		# cid,
		# "Links/$idx",
		# 2^18
	# ))
	# # ipldv1.PBLink(
		# # cid,
		# # "Links/$idx",
		# # length(blk)
	# # )
	# seekstart(io)
	# take!(io)
# end


function fsDecode()
	io = IOBuffer()
	d = ProtoDecoder(io)
	a = decode(d, ipldv1.PBNode)
	return a
end

blockHashed = []
blockSizes = UInt64[]
links = ipldv1.PBLink[]


for (idx, block) in enumerate(Base.Iterators.partition(pdfBytes, 2^18))
	fsBytes = fsEncode(block |> collect)
	nodeBytes = nodeEncode(fsBytes)
	hash = multiHash(:sha2_256, nodeBytes)
	wrappedmultiHash = hashWrap(:sha2_256, hash)
	push!(blockHashed, wrappedmultiHash)
	push!(blockSizes, length(block))
	push!(links, ipldv1.PBLink(wrappedmultiHash, "", length(nodeBytes)))
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


function inspect(cmd::Cmd)
	out = Pipe()
	err = Pipe()

	process  = run(pipeline(ignorestatus(cmd), stdout=out, stderr=err))
	close(out.in)
	close(err.in)
	(
		stdout = read(out),
		stderr = String(read(err)),
		code = process.exitcode
	)
end


function linkEncode(link::ipldv1.PBLink)
	io = IOBuffer()
	e = ProtoEncoder(io)
	data = encode(e, link)
	return take!(io)
end	


function nodeDecode(buf::Vector{UInt8})
	io = IOBuffer()
	write(io, buf)
	seekstart(io)
	d = ProtoDecoder(io)
	decode(d, ipldv1.PBNode)
end

retObj = inspect(`ipfs block get QmaaWTJN7N4GfAEDx4Xqh32aFHbjYUvaHQY8huue2F7sHg`)

upstream = nodeDecode(retObj.stdout)

downstream = nodeDecode(nodeBytes)

function dataDecode(buf::Vector{UInt8})
	io = IOBuffer()
	write(io, buf)
	seekstart(io)
	d = ProtoDecoder(io)
	decode(d, unixfsV1.Data)
end

data = dataDecode(upstream.Data)

data2 = dataDecode(fsBytes)
