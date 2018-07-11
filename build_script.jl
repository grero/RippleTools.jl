Pkg.update()
try
    Pg.rm("RippleTools")
    Pkg.clone(pwd())
catch LoadError
end
Pkg.build("RippleTools")
