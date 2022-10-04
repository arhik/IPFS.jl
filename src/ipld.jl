using ProtoBuf

using MultiFormats

include("protos/ipld_pb.jl")

path = "test.pdf"

pdfBytes = read(path)

blockHashed = []

for block in Base.Iterators.partition(pdfBytes, 2^18)
	io = IOBuffer()
	e = ProtoEncoder(io)
	encode(e, ipld_pb.PBNode([], block))
	seekstart(io)
	bytes = read(io)
	hash = multiHash(:sha2_256, bytes)
	push!(blockHashed, hashWrap(:sha2_256, hash))
end

# d = ProtoDecoder(io);
# 
# a = decode(d, ipld_pb.PBNode)

