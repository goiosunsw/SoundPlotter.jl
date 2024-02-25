using PortAudio
using SampledSignals

    

function audioLoop(n; framesize=1024)#buffer::CircularBuffer)
    stream = PortAudioStream(1, 0)
    r = SampleBuf(zeros(Float32,n), samplerate(stream))
    ntot = 0
    while ntot < n
        try
            # cancel with Ctrl-C
            # s = read(stream, framesize)
            read!(stream, r, framesize)
            ntot += framesize
        catch e
            #println(e)
            throw(e)
        end
    end
    close(stream)
    r
end

function play(s::T) where T <: SampleBuf
    stream = PortAudioStream(0,1)
    write(stream, s)
end

r = audioLoop(48000)
display(r)
play(r)
sleep(1)
