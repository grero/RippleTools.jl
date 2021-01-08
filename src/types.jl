import Base:sizeof,read

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

function BasicHeader2(ff::IO)
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
    electrode_label::String
    frontend_id::UInt8
    frontend_pin::UInt8
    min_digital_value::Int16
    max_digital_value::Int16
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

low_cutoff(header::ExtendedHeader) = header.lowpass_cutoff/1000.0
high_cutoff(header::ExtendedHeader) = header.highpass_cutoff/1000.0

Base.sizeof(::Type{ExtendedHeader}) = 66

function ExtendedHeader(ff::IOStream)
    read(ff, ExtendedHeader)
end

function Base.read(ff::IO, ::Type{ExtendedHeader})
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

struct DataPacket
    header::UInt8
    timestamp::UInt32
    npoints::UInt32
    data::Array{Int16,2}
end

mutable struct DataPacketStreamer
	io::IO
	offset::UInt64
	position::UInt64
    header::UInt8
    headers::Vector{ExtendedHeader}
    timestamp::UInt32
	npoints::UInt32
	nchannels::UInt16
	ownstream::Bool
end

function Base.show(io::IO, packet::DataPacketStreamer)
    print(io, "DataPacketStreamer:\n")
    print(io, "\tnchannels: $(packet.nchannels)\n")
    print(io, "\tndatapoints: $(packet.npoints)\n")
end

low_cutoff(packet, channel::Int) = low_cutoff(packet.headers[channel])
high_cutoff(packet, channel::Int) = high_cutoff(packet.headers[channel])

function DataPacketStreamer(io::IO, ownstream::Bool)
    seek(io,0)
    hh = BasicHeader2(io)
    headers = Vector{ExtendedHeader}(undef, hh.nchannels)
    for ch in 1:hh.nchannels
        headers[ch] = read(io, ExtendedHeader)
    end
	seek(io, hh.nbytes)
    header = read(io, UInt8)
    timestamp = read(io, UInt32)
    npoints = read(io, UInt32)
	offset = position(io)
    ichs = UInt16(hh.nchannels)
    inpoints = Int64(npoints)
	DataPacketStreamer(io, offset, 0, header, headers, timestamp, npoints, ichs, ownstream)
end

function Base.read(reader::DataPacketStreamer, npoints::Int64)
    data = fill(zero(Int16), reader.nchannels, npoints)
	data = read!(reader, data)
end

function Base.read!(reader::DataPacketStreamer, data::Matrix{Int16})
	read!(reader.io, data)
	npoints = size(data,2)
	reader.position += npoints
	data
end

"""
Seek the stream in units of a full data point, i.e. by number of channels
"""
function Base.seek(reader::DataPacketStreamer, pos)
	if 0 <= pos < reader.npoints
		seek(reader.io, reader.offset + pos*reader.nchannels*2)
		reader.position = pos
	end
end

Base.eof(reader::DataPacketStreamer) = eof(reader.io)

function Base.close(reader::DataPacketStreamer)
	reader.ownstream && close(reader.io)
end

struct NSXFile
    header::BasicHeader2
    extended_headers::Vector{ExtendedHeader}
    data::DataPacket
end

function DataPacket(ff::IOStream)
    #rewind the file
    seek(ff,0)
    #get the basic header
    hh = BasicHeader2(ff)
    seek(ff, hh.nbytes)
    DataPacket(ff, hh.nchannels)
end

function DataPacket(ff::IOStream, nchannels::T) where T <: Integer
    header = read(ff, UInt8)
    timestamp = read(ff, UInt32)
    npoints = read(ff, UInt32)
    ichs = Int64(nchannels)
    inpoints = Int64(npoints)
    #rdata = Mmap.mmap(ff, Vector{UInt8}, sizeof(Int16)*ichs*inpoints,position(ff))
    #data = UnalignedVector{Int16}(rdata)
    data = fill(zero(Int16), ichs, inpoints)
    data = read!(ff, data)
    DataPacket(header, timestamp, npoints, data)
end

function DataPacket_slow(ff::IOStream, channel::Int, nchannels::Int)
    header = read(ff, UInt8)
    timestamp = read(ff, UInt32)
    npoints = read(ff, UInt32)
    #read the data for the specified channel
    data = zeros(Int16, npoints)
    for i in 0:npoints-1
        seek(ff, 2*(i*nchannels + channel-1))
        data[i+1] = read(ff, Int16)
    end
    DataPacket(header, timestamp, npoints, data)
end

function BasicHeader(ff::IOStream)
    bytes = read(ff, sizeof(BasicHeader))
    unsafe_load(convert(Ptr{BasicHeader}, pointer(bytes)))
end

get_filtype(hh::BasicHeader) = unsafe_string(pointer(convert(Array{UInt8, 1}, hh.filetype_id)),length(hh.filetype_id))

abstract type AbstractNEVHeader end

struct BasicNEVHeader <: AbstractNEVHeader
    filetype_id::SVector{8,UInt8}
    filespec::SVector{2,UInt8}
    flags::UInt16
    nbytes::UInt32  #total bytes in headers
    nbytes_packets::UInt32
    resolution_timestamps::UInt32
    resolution_samples::UInt32
    time_origin::SVector{8, UInt16}
    createap::SVector{32,UInt8}
    comments::SVector{200, UInt8}
    reserved::SVector{52, UInt8}
    processor_timestamp::UInt32
    n_extended_headers::UInt32
end

function BasicNEVHeader(ff::IO)
    bytes = read(ff, sizeof(BasicNEVHeader))
    unsafe_load(convert(Ptr{BasicNEVHeader}, pointer(bytes)))
end

function Base.read(io::IO, ::Type{T}) where T <: AbstractNEVHeader
    bytes = read(io, get_size(T))
    unsafe_load(convert(Ptr{T}, pointer(bytes)))
end

abstract type AbstractNEVExtendedHeader <: AbstractNEVHeader end

struct WaveEventHeader <: AbstractNEVExtendedHeader
    packet_id::SVector{8,UInt8}
    electrode_id::UInt16
    frontend_id::UInt8
    frontend_pin::UInt8
    digit_factor::UInt16
    energy_threshold::UInt16
    high_threshold::Int16
    low_threshold::Int16
    sorted_units::UInt8
    bytes_sample::UInt8
    stim_digit_factor::Float32
    padding::SVector{6,UInt8}
end

struct FilterEventHeader <: AbstractNEVExtendedHeader
    packet_id::SVector{8,UInt8}
    electrode_id::UInt16
    highpass_freq::UInt32
    highpass_order::UInt32
    highpass_type::UInt16
    lowpass_freq::UInt32
    lowpass_order::UInt32
    lowpas_type::UInt16
    padding::SVector{2,UInt8}
end

struct LabelEventHeader <: AbstractNEVExtendedHeader
    packet_id::SVector{8, UInt8}
    electrode_id::UInt16
    label::SVector{16, UInt8}
    reserved::SVector{6, UInt8}
end

struct DigitalLabelEventHeader <: AbstractNEVExtendedHeader
    packet_id::SVector{8,UInt8}
    label::SVector{16, UInt8}
    mode::UInt8
    reserved::SVector{7, UInt8}
end

function header_type(h::T) where T <: AbstractNEVExtendedHeader
    unsafe_string(pointer(convert(Vector{UInt8},h.packet_id)))
end

abstract type AbstractNEVDataPacket end

struct EventDataPacket{N} <: AbstractNEVDataPacket
    timestamp::UInt32
    packet_id::UInt16
    reason::UInt8
    reserved::UInt8
    parallel::UInt16
    sma::SVector{4, Int16}
    padding::SVector{N,UInt8}
end

struct SpikeDataPacket{T<:Integer, N} <: AbstractNEVDataPacket
    timestamp::UInt32
    packet_id::UInt16
    unit::UInt8
    reserved::UInt8
    waveform::SVector{N,T}
end

struct StimDataPacket{T<:Integer, N} <: AbstractNEVDataPacket
    timestamp::UInt32
    packed_id::UInt16
    reserved::UInt16
    waveform::SVector{N,T}
end

struct NEVFile{N1,N2, N3, T2,T3}
    header::BasicNEVHeader
    wave_headers::Vector{WaveEventHeader}
    filter_headers::Vector{FilterEventHeader}
    label_headers::Vector{LabelEventHeader}
    dig_label_headers::Vector{DigitalLabelEventHeader}
    event_packets::Vector{EventDataPacket{N1}}
    spike_packets::Vector{SpikeDataPacket{T2,N2}}
    stim_packets::Vector{StimDataPacket{T3,N3}}
end

function Base.read(ff, ::Type{TT}, header::BasicNEVHeader) where TT <: AbstractNEVDataPacket
    bytes = read(ff, header.nbytes_packets)
    unsafe_load(convert(Ptr{TT}, pointer(bytes)))
end

function get_packet!(io::IOStream, header::BasicNEVHeader, wf_type::DataType)
    pos = position(io)
    timestamp = read(io, UInt32)
    packet_id = read(io, UInt16)
    #reset and read the appropriate packet
    seek(io,pos) 
    Ne = header.nbytes_packets-18
    N = div(header.nbytes_packets-8, sizeof(wf_type))
    if packet_id == 0
        return read(io, EventDataPacket{Ne}, header)
    elseif 1 <= packet_id <= 512
        return read(io, SpikeDataPacket{wf_type, N}, header)
    elseif 5121 <= packet_id <= 5632
        return read(io, StimDataPacket{wf_type, N}, header)
    end
end

function get_eheader(io::IOStream)
    pos = position(io)
    packet_id = read!(io, Vector{UInt8}(undef, 8))
    seek(io, pos)
    etype = unsafe_string(pointer(packet_id))
    if etype == "NEUEVWAV"
        return read(io, WaveEventHeader)
    elseif etype == "NEUEVFLT"
        return read(io, FilterEventHeader)
    elseif etype == "NEUEVLBL"
        return read(io, LabelEventHeader)
    elseif etype == "DIGLABEL"
        return read(io, DigitalLabelEventHeader)
    else
        return nothing
    end
end

function get_wftype(header::WaveEventHeader)
    nb = header.bytes_sample
    T = Int8
    if nb == 2 
        T = Int16
    elseif 2 < nb <= 4
        T = Int32
    elseif nb > 4
        T = Int64
    end
    T
end

function get_time(header::BasicNEVHeader)
    tt = header.time_origin
    DateTime(tt[1], tt[2], tt[4], tt[5], tt[6], tt[7], tt[8])
end

struct NFXBasicHeader
    filetype_id::SVector{8,UInt8}
    filespec::SVector{2,UInt8}
    nbytes::UInt32
    label::SVector{16,UInt8}
    comments::SVector{200,UInt8}
    createapp::SVector{52,UInt8}
    processor_timestamp::UInt32
    period::UInt32
    resolution_timestamps::UInt32
    time_origin::SVector{8,UInt16}
    nchannels::UInt32
end

function NFXBasicHeader(ff::IO)
    args = Any[]
    for f in fieldnames(NFXBasicHeader)
        ft = fieldtype(NFXBasicHeader, f)
        push!(args, read(ff,ft)) 
    end
    NFXBasicHeader(args...)
end

struct NFXExtendedHeader
    header_type::SVector{2, UInt8}
    electrode_id::UInt16
    electrode_label::SVector{16, UInt8}
    frontend_id::UInt8
    frontend_pin::UInt8
    min_digital_value::Int16
    max_digital_value::Int16
    min_analog_value::Int16
    max_analog_value::Int16
    units::SVector{16, UInt8}
    highpass_freq::UInt32
    highpass_order::UInt32
    highpass_type::UInt16
    lowpass_freq::UInt32
    lowpass_order::UInt32
    lowpass_type::UInt16
end

function get_label(hh::NFXExtendedHeader)
    unsafe_string(pointer(Vector(hh.electrode_label)))
end

function get_header(ff::IO, ::Type{T}) where T <: Union{NFXBasicHeader, NFXExtendedHeader}
    args = Any[]
    for f in fieldnames(T)
        ft = fieldtype(T, f)
        push!(args, read(ff,ft)) 
    end
    T(args...)
end

struct NFXDataPacket
    header::UInt8
    timestamp::UInt32
    npoints::UInt32
    data::Matrix{Float32}
end

function NFXDataPacket(ff::IOStream, nchannels::T) where T <: Integer
    header = read(ff, UInt8)
    timestamp = read(ff, UInt32)
    npoints = read(ff, UInt32)
    inpoints = Int64(npoints)
    inchs = Int64(nchannels)
    rdata = Mmap.mmap(ff, Vector{UInt8}, sizeof(Float32)*Int64(nchannels)*Int64(npoints))
    data = UnalignedVector{Float32}(rdata)
    NFXDataPacket(header, timestamp, npoints, reshape(data, inchs, inpoints))
end

struct NFXFile
    header::NFXBasicHeader
    eheaders::Vector{NFXExtendedHeader}
    data::NFXDataPacket
end

function get_size(::Type{T}) where T <: Union{AbstractNEVHeader, NFXBasicHeader, NFXExtendedHeader}
    ss = 0
    for f in fieldnames(T)
        ss += sizeof(fieldtype(T, f))
    end
    ss
end
