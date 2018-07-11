using RippleTools
using FileIO
using Base.Test

@testset "Basic loading" begin
    tdir = tempdir()
    cd(tdir) do
        #download the data file
        download("http://cortex.nus.edu.sg/testdata/w3_27_test7.ns5","w3_27_test7.ns5")
        dd = FileIO.load("w3_27_test7.ns5")
        @test dd.header == 0x01
        @test dd.npoints == 0x000dd220
        @test dd.timestamp == 0x00000000
        @test size(dd.data) == (158, 905760)
        @test hash(dd.data) == 0xa1c770be80a4b6b8
    end
end

