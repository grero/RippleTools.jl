using RippleTools
using FileIO
using CSV
using Base.Test

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
        end
        @testset "Test packet" begin
            pp = load("sample_data_set.nev")
            @test typeof(pp.event_packets[1]) <: RippleTools.EventDataPacket{94}
            qq = filter(p->p.reason==0x04, pp.event_packets)
            @test length(qq) == 218
            qv = filter(p->p.sma[2] == 32767, qq)
            @test length(qv) == 109

            @test typeof(pp.spike_packets[1].waveform) <: RippleTools.SVector{52,Int16}
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
        _ddf = CSV.read("event_markers.csv", types=[String,Float64])
        @test markers == _ddf[:words]
        @test timestamps ≈ _ddf[:timestamps]
    end
end



@testset "RawData" begin
    tdir = tempdir()
    cd(tdir) do
        if !isfile("w3_27_test7.ns5")
            download("http://cortex.nus.edu.sg/testdata/w3_27_test7.ns5","w3_27_test7.ns5")
        end
        dd = FileIO.load("w3_27_test7.ns5")
        @test dd.header == 0x01
        @test dd.npoints == 0x000dd220
        @test dd.timestamp == 0x00000000
        @test size(dd.data) == (158, 905760)
        @test hash(dd.data) == 0xa1c770be80a4b6b8
    end
end
