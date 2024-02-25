using PortAudio
using DataStructures

struct RecBuffer
    n::Int64
    pos::Int64
    buffer::Vector{T} where T <: AbstractFloat
end

function RecBuffer(n)
    r = RecBuffer(n, 0, zeros(Float32, n))
    r
end
    
function record!(s::Vector{T}, r::RecBuffer) where  T <: AbstractFloat
    ns = length(s)
    r[r.pos:(r.pos+ns)] .= s
end

function audioLoop()#buffer::CircularBuffer)
    stream = PortAudioStream(1, 0)
    r = RecBuffer(48000)
    while r.pos < r.n 
        try
            # cancel with Ctrl-C
            s = read(stream, 1024)
            record!(Vector(s[:,1]), r) 
        catch e
            #println(e)
            throw(e)
        end
    end
    close(stream)
    r
end

function play(r::RecBuffer)
    s = r.buffer
    stream = PortAudio(0,1)
    write(stream, s)
end

r = audioLoop()
play(r)
sleep(1)
