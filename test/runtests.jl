using CSV
using FileIO
using RippleTools
using Test

@testset "NEV loading" begin
    tdir = tempdir()
    cd(tdir) do
        if !isfile("sample_data_set.nev")
            download("https://s3-us-west-2.amazonaws.com/rippleneuro/downloads/Ripple_Sample_Data_Set_v1.zip", "Ripple_Sample_Data_Set_v1.zip")
            run(`ls`)
            run(`unzip Ripple_Sample_Data_Set_v1.zip`)
        end
        @testset "Test header" begin
            header = open("sample_data_set.nev") do ff
                read(ff, RippleTools.BasicNEVHeader)
            end
            appname = unsafe_string(pointer(Vector(header.createap)))
            @test appname == "Trellis[1.9.0.313]"
            comments = unsafe_string(pointer(Vector(header.comments)))
            @test comments == ""
            @test Vector(header.time_origin) == [2018,3,5,2,21,53,41,625]
            @test header.processor_timestamp == 34198620
            @test header.n_extended_headers == 165
            @test header.resolution_timestamps == 0x00007530
        end
        @testset "Test packet" begin
			pp = RippleTools.load(FileIO.File(FileIO.format"NEV", "sample_data_set.nev"))
            @test typeof(pp.event_packets[1]) <: RippleTools.EventDataPacket{94}
            qq = filter(p->p.reason==0x04, pp.event_packets)
            @test length(qq) == 218
            qv = filter(p->p.sma[2] == 32767, qq)
            @test length(qv) == 109

            @test typeof(pp.spike_packets[1].waveform) <: RippleTools.SVector{52,Int16}
            stim_factors = [ff.stim_digit_factor for ff in pp.wave_headers]
            amp_factors = [ff.digit_factor for ff in pp.wave_headers]
            stim_factor = stim_factors[findfirst(x->x>0, stim_factors)]
            amp_factor =  amp_factors[findfirst(x->x>0, amp_factors)]
            @test amp_factor == 200  # nV
            idx = findfirst(p->p.timestamp==201, pp.spike_packets)
            @test pp.spike_packets[idx].waveform == Int16[12, 27, 0, -41, -7, 0, 41, 116, 91, 167, 267, 268, 247, 151, -69, -412, -763, -920, -881, -680, -402, -52, 305, 541, 653, 649, 595, 502, 338, 215, 162, 81, -24, -118, -32, -33, -19, -54, -82, -83, -106, -96, -56, -73, -55, -41, -31, -6, -62, -84, -3, -43]
            #redundant test, but just to make comparison with Neuroshare easier
            @test pp.spike_packets[idx].waveform[1:2].*amp_factor*1e-3 ≈ [2.4,5.4]
        end
    end
end

@testset "Markers" begin
    tdir = tempdir()
    cd(tdir) do
        if !isfile("w7_13.nev")
            download("http://cortex.nus.edu.sg/testdata/w7_13.nev","w7_13.nev")
        end
        if !isfile("event_markers.csv")
            download("http://cortex.nus.edu.sg/testdata/event_markers.csv","event_markers.csv")
        end
        markers,timestamps = RippleTools.extract_markers("w7_13.nev")
        _ddf = CSV.File("event_markers.csv", types=[String,Float64])
		@test markers == _ddf.columns[1]
		@test timestamps ≈ _ddf.columns[2]
    end
end



@testset "RawData" begin
    tdir = tempdir()
    cd(tdir) do
        if !isfile("w3_27_test7.ns5")
            download("http://cortex.nus.edu.sg/testdata/w3_27_test7.ns5","w3_27_test7.ns5")
        end
		dd = RippleTools.load(FileIO.File(FileIO.format"NSX", "w3_27_test7.ns5"))
        #@show dd.extended_headers
        #amp_factors = [ff.digit_factor for ff in dd.wave_headers]
        #@show amp_factors
        @test dd.header.filetype_id == "NEURALCD"
        @test dd.data.npoints == 0x000dd220
        @test dd.data.timestamp == 0x00000000
        @test size(dd.data.data) == (158, 905760)
        @test dd.data.data[1,1:10] == Int16[1689, 1715, 1723, 1663, 1670, 1692, 1661, 1693, 1724, 1695]
        min_digital_value = dd.extended_headers[1].min_digital_value
        max_digital_value = dd.extended_headers[1].max_digital_value
        min_analog_value = dd.extended_headers[1].min_analog_value
        max_analog_value = dd.extended_headers[1].max_analog_value
        q = (float.(dd.data.data[1,1:10]) .- float(min_digital_value))./(float(max_digital_value) - float(min_digital_value))
        q .= (float(max_analog_value) .- float(min_analog_value))*q .+ float(min_analog_value)
        @test q[1] ≈ 422.2113406781227
        @test q[2] ≈ 428.7107455671867
        @test q[3] ≈ 430.71056245613
        @test q[4] ≈ 415.71193578905513
        @test q[5] ≈ 417.46177556688235

		@testset "Stream" begin
			pp = RippleTools.DataPacketStreamer(open("w3_27_test7.ns5"), true)
            io = IOBuffer()
            show(io,pp)
            ss = String(take!(io))
            @test ss == "DataPacketStreamer:\n\tnchannels: 158\n\tndatapoints: 905760\n"
            @test RippleTools.low_cutoff(pp, 1) == 7500.0
            @test RippleTools.high_cutoff(pp, 1) == 0.3
			@test pp.offset == 10751
			@test pp.nchannels == 158
			@test pp.npoints == 0x000dd220
			@test pp.position == 0
			@test pp.offset == 10751
			@test pp.nchannels == 158
			@test pp.npoints == 0x000dd220
			@test pp.position == 0
			@test position(pp.io) == 10751
			data1 = read(pp, 100)
			@test pp.position == 100
			data2 = read(pp, 100)
			@test pp.position == 200
			seek(pp, 0)
			@test pp.position == 0
			@test position(pp.io) == 10751
			data3 = read(pp, 200)
			@test cat(data1,data2, dims=2) == data3

            #loading channel
            seek(pp, 0)
            channeldata = RippleTools.readchannel(pp, 31)
            @test length(channeldata) == pp.npoints
            seek(pp,0)
            alldata = RippleTools.read(pp, pp.npoints)
            @test alldata[31,:] ≈ channeldata
			close(pp)
		end
    end
end
