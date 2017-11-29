import Base.sizeof

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

struct ExtendedHeader
    electrode_id::UInt16
    electode_label::String
    frontend_id::UInt8
    frontend_pin::UInt8
    min_digital_value::Int16
    max_digitial_value::Int16
    min_analog_value::Int16
    max_analog_value::Int16
    units::String
    highpass_cutoff::UInt32
    highpass_order::UInt32
    highpass_type::UInt16
    lowpass_cutoff::UInt32
    lowpass_order::UInt32
    lowpass_type::UInt16
end

Base.sizeof(::Type{ExtendedHeader}) = 66

function ExtendedHeader(ff::IOStream)
    bytes = read(ff, sizeof(ExtendedHeader))
    offset = 1
    electrode_id = reinterpret(UInt16, bytes[offset:offset+1])[1]
    offset += 2
    electrode_label = unsafe_string(pointer(bytes, offset), 16)
    offset += 16
    frontend_id = bytes[offset]
    offset += 1
    frontend_pin = bytes[offset]
    offset += 1
    min_digital_value = reinterpret(Int16, bytes[offset:offset+1])[1]
    offset += 2
    max_digital_value = reinterpret(Int16, bytes[offset:offset+1])[1]
    offset += 2
    min_analog_value = reinterpret(Int16, bytes[offset:offset+1])[1]
    offset += 2
    max_analog_value = reinterpret(Int16, bytes[offset:offset+1])[1]
    offset += 2
    units = unsafe_string(pointer(bytes, offset),16)
    offset += 16
    highpass_cutoff = reinterpret(UInt32, bytes[offset:offset+3])[1]
    offset += 4
    highpass_order = reinterpret(UInt32, bytes[offset:offset+3])[1]
    offset += 4
    highpass_type = reinterpret(UInt16, bytes[offset:offset+3])[1]
    offset += 2
    lowpass_cutoff = reinterpret(UInt32, bytes[offset:offset+3])[1]
    offset += 4
    lowpass_order = reinterpret(UInt32, bytes[offset:offset+3])[1]
    offset += 4
    lowpass_type = reinterpret(UInt16, bytes[offset:offset+3])[1]
    offset += 2
    ExtendedHeader(electrode_id, electrode_label, frontend_id, frontend_pin, min_digital_value, max_digital_value, min_analog_value, max_analog_value, units, highpass_cutoff, highpass_order, highpass_type, lowpass_cutoff, lowpass_order, lowpass_type)
end

function BasicHeader(ff::IOStream)
    bytes = read(ff, sizeof(BasicHeader))
    unsafe_load(convert(Ptr{BasicHeader}, pointer(bytes)))
end

get_filtype(hh::BasicHeader) = unsafe_string(pointer(convert(Array{UInt8, 1}, hh.filetype_id)),length(hh.filetype_id))
