module RippleTools
using StaticArrays
using FileIO
using Dates

try
    FileIO.add_format(format"NEV", "NEURALEV", ".nev")
    FileIO.add_format(format"NSX", "NEURALCD", [".ns$i" for i in 1:10])
    FileIO.add_loader(format"NSX", :RippleTools)
    FileIO.add_loader(format"NEV", :RippleTools)
    FileIO.add_format(format"NFX", "NEUCDFLT", [".nf$i" for i in 1:10])
    FileIO.add_loader(format"NFX", :RippleTools)
catch ee
end

include("types.jl")
include("events.jl")

function load(ff::File{format"NSX"})
    open(ff) do f
        hh = BasicHeader2(f.io)
        nchannels = Int(hh.nchannels)
        eheaders = Vector{ExtendedHeader}(undef, nchannels)
        for c in 1:nchannels
            eheaders[c] = ExtendedHeader(f.io)
        end
        seek(f.io, hh.nbytes)
        dd = DataPacket(f.io, hh.nchannels)
        NSXFile(hh,eheaders,dd)
    end
end

function load(ff::File{format"NFX"})
    open(ff) do f
        header = NFXBasicHeader(f.io)
        nchannels = Int(header.nchannels)
        eheaders = Vector{NFXExtendedHeader}(nchannels)
        for c in 1:nchannels
            eheaders[c] = get_header(f.io, NFXExtendedHeader)
        end
        seek(f.io, header.nbytes)
        dd = NFXDataPacket(f.io, header.nchannels)
        NFXFile(header,eheaders,dd)
    end
end

bit_order = [4, 5, 7, 1, 10, 12, 13, 15]

function extract_markers(fname)
    header = open(fname,"r") do ff
        read(ff, BasicNEVHeader)
    end
    fs = header.resolution_timestamps
    pp = FileIO.load(fname)
    markers = String[]
    timestamps = Float64[]
    for p in pp.event_packets
        if p.reason == 0x01  # strobe
            push!(markers, parse_strobe(p.parallel))
            push!(timestamps, p.timestamp/fs)
        end
    end
    markers, timestamps
end

parse_strobe(strobe::UInt16) = string(strobe, base=2,pad=16)[bit_order]

end# module
