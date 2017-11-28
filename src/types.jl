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

function BasicHeader(ff::IOStream)
    bytes = read(ff, sizeof(BasicHeader))
    unsafe_load(convert(Ptr{BasicHeader}, pointer(bytes)))
end

get_filtype(hh::BasicHeader) = unsafe_string(pointer(convert(Array{UInt8, 1}, hh.filetype_id)),length(hh.filetype_id))
