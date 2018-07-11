Pkg.update()
try
    Pkg.clone(pwd())
catch LoadError
end
Pkg.build("RippleTools")
