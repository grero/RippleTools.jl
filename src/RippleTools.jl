module RippleTools
using PyCall
@pyimport pyns
const NSFile = pyns.nsfile[:NSFile]
const EntityType = pyns.nsentity[:EntityType]

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

end# module
