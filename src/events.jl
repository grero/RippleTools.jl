function load(ff::File{format"NEV"}) 
    open(ff) do f
        fio = f.io
        header = BasicNEVHeader(fio)  
        #grap the extended headers
        wave_headers = WaveEventHeader[]
        filter_headers = FilterEventHeader[]
        label_headers = LabelEventHeader[]
        dig_label_headers = DigitalLabelEventHeader[]
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
        event_packets = EventDataPacket{Ne}[]
        spike_packets = SpikeDataPacket{wf_type,N}[]
        stim_packets = StimDataPacket{wf_type,N}[]
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
