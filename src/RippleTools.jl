module RippleTools
using StaticArrays
using FileIO

try
    FileIO.add_format(format"NEV", "NEURALEV", ".nev")
    FileIO.add_format(format"NSX", "NEURALCD", [".ns$i" for i in 1:10])
    FileIO.add_loader(format"NSX", :RippleTools)
    FileIO.add_loader(format"NEV", :RippleTools)
catch ee
end

include("types.jl")
include("events.jl")

function load(ff::File{format"NSX"})
    open(ff) do f
        dd = DataPacket(f.io)
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
    for p in pp[1]
        if p.reason == 0x01  # strobe
            push!(markers, parse_strobe(p.parallel))
            push!(timestamps, p.timestamp/fs)
        end
    end
    markers, timestamps
end

parse_strobe(strobe::UInt16) = bin(strobe, 16)[bit_order]

end# module
