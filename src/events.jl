function load(ff::File{format"NEV"}) 
    open(ff) do f
        fio = f.io
        header = BasicNEVHeader(fio)  
        #grap the extended headers
        eheaders = Vector{AbstractNEVHeader}(header.n_extended_headers)
        wf_type = Int16
        for i in 1:length(eheaders) 
            eh = get_eheader(fio)
            if eh == nothing
                continue
            end
            eheaders[i] = eh
            if typeof(eheaders[i]) <: WaveEventHeader
                wf_type = get_wftype(eheaders[i])
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
        NEVFile(header, event_packets, spike_packets, stim_packets)
    end
end
