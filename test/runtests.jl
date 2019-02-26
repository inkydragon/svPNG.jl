using Test

# This is not a module yet.
include("../src/svPNG.jl")
svpng = svPNG.svpng

#=
    使用 svpng()
=#
open("svPNG-1.png", "w") do io
    img = Array{UInt8,1}()
    w = 256
    h = 256
    alpha = false
    
    for y in 0:(w-1)
        for x in 0:(h-1)
            append!(img, UInt8(x))   # R
            append!(img, UInt8(y))   # G
            append!(img, UInt8(128)) # B
        end
    end
    svpng(io, w, h, img, alpha)
end;

open("svPNG-big.png", "w") do io
    img = Array{UInt8,1}()
    w = 2560
    h = 1280
    alpha = false

    for y in 0:(w-1)
        for x in 0:(h-1)
            append!(img, UInt8(x%256))   # R
            append!(img, UInt8(y%256))   # G
            append!(img, UInt8(128))     # B
            if alpha
                append!(img, UInt8(128))
            end
        end
    end
    svpng(io, w, h, img, alpha)
end;
