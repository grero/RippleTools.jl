struct BasicHeader
    filetype_id::SVector{8, UInt8}
    filespec::SVector{2, UInt8}
    nbytes::UInt32
    label::SVector{16, UInt8}
    comments::SVector{200, UInt8}
    createapp::SVector{52, UInt8}
    processor_timestamp::UInt32
    period::UInt32
    time_resolution::UInt32
    time_origin::SVector{8, UInt16}
    nchannels::UInt32
end

struct BasicHeader2
    filetype_id::String
    filespec::SVector{2, UInt8}
    nbytes::UInt32
    label::String
    comments::String
    createapp::String
    processor_timestamp::UInt32
    period::UInt32
    time_resolution::UInt32
    time_period::DateTime
    nchannels::UInt32
end

function BasicHeader2(ff::IOStream)
    bytes = read(ff, sizeof(BasicHeader))
    offset = 1
    filetype_id = unsafe_string(pointer(bytes),8)
    offset += 8
    filespec = SVector{2,UInt8}(bytes[offset:offset+1])
    offset += 2
    nbytes = reinterpret(UInt32, bytes[offset:offset+3])[1]
    offset += 4
    label = unsafe_string(pointer(bytes, 15),16)
    offset += 16
    comment = unsafe_string(pointer(bytes, offset),200)
    offset += 200
    createapp = unsafe_string(pointer(bytes, offset), 52)
    offset += 52
    processor_timestamp = reinterpret(UInt32, bytes[offset:offset+3])[1]
    offset += 4
    period = reinterpret(UInt32, bytes[offset:offset+3])[1]
    offset += 4
    time_resolution = reinterpret(UInt32, bytes[offset:offset+3])[1]
    offset += 4
    tqq = reinterpret(UInt16, bytes[offset:offset+15])
    offset += 16
    time_period = DateTime(tqq[1], tqq[2], tqq[4], tqq[5], tqq[6], tqq[7], tqq[8])
    nchannels = reinterpret(UInt32, bytes[offset:offset+3])[1]
    BasicHeader2(filetype_id, filespec, nbytes, label, comment, createapp, processor_timestamp,period,time_resolution, time_period, nchannels)
end

function BasicHeader(ff::IOStream)
    bytes = read(ff, sizeof(BasicHeader))
    unsafe_load(convert(Ptr{BasicHeader}, pointer(bytes)))
end

get_filtype(hh::BasicHeader) = unsafe_string(pointer(convert(Array{UInt8, 1}, hh.filetype_id)),length(hh.filetype_id))
