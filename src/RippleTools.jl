module RippleTools
using PyCall
using StaticArrays
@pyimport pyns
const NSFile = pyns.nsfile[:NSFile]
const EntityType = pyns.nsentity[:EntityType]
using FileIO
FileIO.add_format(format"NEV", "NEURALEV", ".nev")
FileIO.add_format(format"NSX", "NEURALCD", [".ns$i" for i in 1:10])
FileIO.add_loader(format"NSX", :RippleTools)

include("types.jl")

function load(ff::File{format"NSX"})
    open(ff) do f
        dd = DataPacket(f.io)
    end
end

bit_order = [4, 5, 7, 1, 10, 12, 13, 15]
function get_rawdata(fname,channel="all")
    f = NSFile(fname)
    analog_entities = f[:get_entities](EntityType[:analog])
    data = Dict{Int64,Array{Float64,1}}()
    for entity in analog_entities
        _info = entity[:get_analog_info]()
        _einfo = entity[:get_entity_info]()
        tt, _ch = split(_einfo[1])
        ch = parse(Int64,_ch)
        if channel == "all" || ((ch in channel) && (tt == "raw"))
            if _info[1] > 1000  # sampling rate
                data[ch] = entity[:get_analog_data]()
            end
        end
    end
    data
end

function extract_markers(fname)
    f = NSFile(fname)
    event_entities = f[:get_entities](EntityType[:event])
    strobes = UInt16[]
    timestamps = Float64[]
    for entity in event_entities
        for i in 1:entity[:item_count]
            dd = entity[:get_event_data](i-1)
            push!(strobes,dd[2][1])
            push!(timestamps, dd[1])
        end
    end
    strobes, timestamps
end

parse_strobe(strobe::UInt16) = bin(strobe, 16)[bit_order]

end# module
