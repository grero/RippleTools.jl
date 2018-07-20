function load(ff::File{format"NEV"}) 
    open(ff) do f
        event_packets = Vector{EventDataPacket}(0)
        spike_packets = Vector{SpikeDataPacket}(0)
        stim_packets = Vector{StimDataPacket}(0)
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
        seek(fio, header.nbytes)
        while !eof(fio)
            packet = get_packet!(fio, header, wf_type)
            tp = typeof(packet)
            if tp <: EventDataPacket
                push!(event_packets, packet)
            elseif tp < SpikeDataPacet
                push!(spike_packets, packet)
            elseif tp <: StimDataPacket
                push!(stim_packets, packet)
            end
        end
        event_packets, spike_packets, stim_packets
    end
end
