using RippleTools
using FileIO
using Base.Test

#@testset "Basic loading" begin
#    tdir = tempdir()
#    cd(tdir) do
#        #download the data file
#        download("http://cortex.nus.edu.sg/testdata/w3_27_test7.ns5","w3_27_test7.ns5")
#        dd = FileIO.load("w3_27_test7.ns5")
#        @test dd.header == 0x01
#        @test dd.npoints == 0x000dd220
#        @test dd.timestamp == 0x00000000
#        @test size(dd.data) == (158, 905760)
#        @test hash(dd.data) == 0xa1c770be80a4b6b8
#    end
#end

@testset "NEV loading" begin
    tdir = tempdir()
    cd(tdir) do
        if !isfile("sample_data_set.nev")
            download("https://s3-us-west-2.amazonaws.com/rippleneuro/downloads/Ripple_Sample_Data_Set_v1.zip", "Ripple_Sample_Data_Set_v1.zip")
            run(`ls`)
            run(`unzip Ripple_Sample_Data_Set_v1.zip`)
        end
        pp = load("sample_data_set.nev")
    end
end

