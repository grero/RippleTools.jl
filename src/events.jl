function load(ff::File{format"NEV"}) 
    open(ff) do f
        fio = f.io
        header = BasicNEVHeader(fio)  
        #grap the extended headers
        wave_headers = Vector{WaveEventHeader}(0)
        filter_headers = Vector{FilterEventHeader}(0)
        label_headers = Vector{LabelEventHeader}(0)
        dig_label_headers = Vector{DigitalLabelEventHeader}(0)
        wf_type = Int16
        for i in 1:header.n_extended_headers
            eh = get_eheader(fio)
            if eh == nothing
                continue
            end
            if typeof(eh) <: WaveEventHeader
                wf_type = get_wftype(eh)
                push!(wave_headers, eh)
            elseif typeof(eh) <: FilterEventHeader
                push!(filter_headers, eh)
            elseif typeof(eh) <: LabelEventHeader
                push!(label_headers, eh)
            elseif typeof(eh) <: DigitalLabelEventHeader
                push!(dig_label_headers, eh)
            end
        end
        Ne = header.nbytes_packets-18
        N = div(header.nbytes_packets-8, sizeof(wf_type))
        event_packets = Vector{EventDataPacket{Ne}}(0)
        spike_packets = Vector{SpikeDataPacket{wf_type,N}}(0)
        stim_packets = Vector{StimDataPacket{wf_type,N}}(0)
        seek(fio, header.nbytes)
        while !eof(fio)
            packet = get_packet!(fio, header, wf_type)
            tp = typeof(packet)
            if tp <: EventDataPacket
                push!(event_packets, packet)
            elseif tp <: SpikeDataPacket
                push!(spike_packets, packet)
            elseif tp <: StimDataPacket
                push!(stim_packets, packet)
            end
        end
        NEVFile(header, wave_headers, filter_headers, label_headers, dig_label_headers, event_packets, spike_packets, stim_packets)
    end
end
