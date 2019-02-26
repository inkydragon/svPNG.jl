# refactoring using closure & nested function

function svpng(io::IO, w::UInt32, h::UInt32, img, alpha::Bool)
    t = [
        0x00000000, 0x1db71064, 0x3b6e20c8, 0x26d930ac, 
        0x76dc4190, 0x6b6b51f4, 0x4db26158, 0x5005713c, 
        0xedb88320, 0xf00f9344, 0xd6d6a3e8, 0xcb61b38c, 
        0x9b64c2b0, 0x86d3d2d4, 0xa00ae278, 0xbdbdf21c 
    ] # CRC32 Table
    
    a = UInt32(1)   # ADLER-a
    b = UInt32(0)   # ADLER-b
    c = ~UInt32(0)  # CRC
    p = UInt32(w * (alpha ? 4 : 3) + 1) # pitch
    # @info "" a b p
    
#=  function define begin =#
    SVPNG_PUT(b::UInt8) = write(io, b)
    SVPNG_PUT(b::UInt32) = SVPNG_PUT(UInt8(b))
    
    SVPNG_U8A(ua::Base.CodeUnits{UInt8,String}) = 
        for b in ua
            SVPNG_PUT(b)
        end
    
    function SVPNG_U32(u::UInt32)
        SVPNG_PUT( u >> 24)
        SVPNG_PUT((u >> 16) & 0xFF)
        SVPNG_PUT((u >> 8 ) & 0xFF)
        SVPNG_PUT( u & 0xFF)
    end
    
    function SVPNG_U8C(u::UInt8)::UInt32
        SVPNG_PUT(u)
        c = c ⊻ (u)
        c = (c >> 4) ⊻ t[c & 0x0F+1]
        c = (c >> 4) ⊻ t[c & 0x0F+1]
    end
    SVPNG_U8C(u::Union{T, Bool} where {T<:Integer})::UInt32 = 
        SVPNG_U8C(UInt8(u))
    
    function SVPNG_U8AC(ua::Base.CodeUnits{UInt8,String})
        for b in ua
            SVPNG_U8C(b)
        end
    end
    
    function SVPNG_U16LC(u::UInt32)
        SVPNG_U8C(u & 0xFF)
        SVPNG_U8C((u >> 8) & 0xFF)
    end
    # SVPNG_U16LC(u::UInt32) = 
    #     SVPNG_U16LC(UInt16(u))
    
    function SVPNG_U32C(u::UInt32)
        SVPNG_U8C( u >> 24)
        SVPNG_U8C((u >> 16) & 0xFF)
        SVPNG_U8C((u >> 8 ) & 0xFF)
        SVPNG_U8C( u & 0xFF)
    end
    
    function SVPNG_U8ADLER(u::UInt8)
        SVPNG_U8C(u)
        a = (a + u) % 0xFFF1
        b = (b + a) % 0xFFF1
    end
    SVPNG_U8ADLER(u::T) where {T<:Integer} = SVPNG_U8ADLER(UInt8(u))
    
    function SVPNG_BEGIN(s::Base.CodeUnits{UInt8,String}, l::UInt32)
        SVPNG_U32(l)
        ~zero(UInt32)
        SVPNG_U8AC(s)
    end
    SVPNG_BEGIN(s::Base.CodeUnits{UInt8,String}, l::T) where {T <: Integer} = 
        SVPNG_BEGIN(s, UInt32(l))
    
    SVPNG_END(c::UInt32) = SVPNG_U32(~c)
#=  function define end =#
    
    #= 1-Magic Number =#
    SVPNG_U8A(b"\x89PNG\r\n\32\n")  # Magic
    
    #= 2-IHDR chunk Begin =#
    SVPNG_BEGIN(b"IHDR", 13)    # IHDR chunk { (total 13 bytes)
    SVPNG_U32C(w)               #   Width  (4 bytes)
    SVPNG_U32C(h)               #   Height (4 bytes)
    SVPNG_U8C(8)                #   Depth = 8 (1 bytes)
    color = alpha ? 6 : 2 
    SVPNG_U8C(color)            #   Color = with/without alpha 
                                #     (1 bytes)
    SVPNG_U8AC(b"\0\0\0")       #   Compression = 
                                #     Deflate, 
                                #     Filter=No, 
                                #     Interlace=No 
                                #     (3 bytes)
    SVPNG_END(c);               # } # IHDR END
    #= IHDR chunk End =# 
    
    #= 3-IDAT chunk Begin =#
    IDAT_len = 2 + h*(5+p) + 4 
    SVPNG_BEGIN(b"IDAT", IDAT_len)  # IDAT chunk {
    SVPNG_U8AC(b"\x78\1")           #   Deflate block begin 
                                    #     (2 bytes)
    for y in 1:h #   Each horizontal line makes a block for simplicity
        SVPNG_U8C(y == h);          #   1 for the last block, 
                                    #       0 for others (1 byte) 
        SVPNG_U16LC(p);             #   LEN: Size of block in little endian
        SVPNG_U16LC(~p);            #   NLEN: and its 1's complemen
                                    #     (4 bytes) 
        
        SVPNG_U8ADLER(0);           #   No filter prefix
        for pix in view(img, ( (y-1)*(p-1)+1 ):( y*(p-1) ) )
            SVPNG_U8ADLER(pix)      #   Image pixel data
        end
    end
    SVPNG_U32C((b << 16) | a);      #   Deflate block end with adler (4 bytes) 
    SVPNG_END(c);                   # } # IDAT END
    #= IDAT chunk End =# 
    
    #= 4-IEND chunk =#
    SVPNG_BEGIN(b"IEND", 0); SVPNG_END(c) # IEND chunk {}
end # svpng function end
svpng(io::IO, w::T, h::T, img) where {T<:Integer} = 
    svpng(io, w, h, img, false)
svpng(io::IO, w::T, h::T, img, alpha::Bool) where {T<:Integer} =
    svpng(io, UInt32(w), UInt32(h), img, alpha)

open("svPNG-nest-1.png", "w") do io
    img = Array{UInt8,1}()
    w = 256
    h = 256
    alpha = false
    
    for y in 0:(w-1)
        for x in 0:(h-1)
            append!(img, UInt8(x))   # R
            append!(img, UInt8(y))   # G
            append!(img, UInt8(128)) # B
            # append!(img, UInt8((x+y)%256)) # B
        end
    end
    svpng(io, w, h, img, alpha)
end;
