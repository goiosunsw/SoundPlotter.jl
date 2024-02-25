using CImGui
using CImGui.ImGuiGLFWBackend
using CImGui.ImGuiGLFWBackend.LibCImGui
using CImGui.ImGuiGLFWBackend.LibGLFW
using CImGui.ImGuiOpenGLBackend
using CImGui.ImGuiOpenGLBackend.ModernGL
# using CImGui.ImGuiGLFWBackend.GLFW
using CImGui.CSyntax
using CImGui.CSyntax.CStatic

nPlot = 100

mutable struct GuiData
    plotterOn::Bool
    plotY::Vector{Float64}
    fps::Float64
    axisColor::Vector{Float64}
    lineColor::Vector{Float64}
end

function GuiData(plotY::Vector{Float64})
    GuiData(true, plotY, 0.0, [1.0,1.0,1.0,1.0], [0.7,0.7,0.0,1.0])
end    
    
function PlotterWindow(guidata::GuiData)
    col32 = CImGui.ColorConvertFloat4ToU32(ImVec4(guidata.lineColor...))
    axcol32 = CImGui.ColorConvertFloat4ToU32(ImVec4(guidata.axisColor...))
    th = @cstatic th = Cfloat(1.0)
    if CImGui.Begin("Plotter")
        draw_list = CImGui.GetWindowDrawList()
        canvas_pos = CImGui.GetCursorScreenPos()
        canvas_size = CImGui.GetContentRegionAvail()
        img_width = trunc(Int, canvas_size.x)
        img_height = trunc(Int, canvas_size.y)
        n = length(guidata.plotY)
        x = ((1:n).-1).*(img_width/n)
        zero_pos = img_height ÷ 2

        CImGui.AddLine(draw_list, ImVec2(canvas_pos.x,canvas_pos.y+zero_pos), 
                                    ImVec2(canvas_pos.x+img_width,canvas_pos.y+zero_pos), axcol32, th)

        y = trunc.(Int, guidata.plotY * img_height)

        for i in axes(y[1:end-1],1)
            # println(x[i],", ",y[i])
            CImGui.AddLine(draw_list, ImVec2(canvas_pos.x+x[i],canvas_pos.y+y[i]), 
            ImVec2(canvas_pos.x+x[i+1],canvas_pos.y+y[i+1]), col32, th)
        end
        #CImGui.PopClipRect(draw_list)

    end
end

function ControlWindow(guidata::GuiData)
    if CImGui.Begin("Control")
        CImGui.Text("Frames per second $(guidata.fps)")
        CImGui.Button("Button") && (guidata.plotterOn = ! guidata.plotterOn)
        CImGui.End()
    end
end

function GuiWindow()
    global nPlot
    ydata = zeros(Float64, nPlot)
    guidata = GuiData(
                      ydata
                      )

    glfwDefaultWindowHints()
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3)
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 2)
    if Sys.isapple()
        glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE) # 3.2+ only
        glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE) # required on Mac
    end


    # create window
    window = glfwCreateWindow(1280, 720, "Demo", C_NULL, C_NULL)
    @assert window != C_NULL
    glfwMakeContextCurrent(window)
    glfwSwapInterval(1)  # enable vsync

    # create OpenGL and GLFW context
    window_ctx = ImGuiGLFWBackend.create_context(window)
    gl_ctx = ImGuiOpenGLBackend.create_context()

    # setup Dear ImGui context
    ctx = CImGui.CreateContext()

    # enable docking and multi-viewport
    io = CImGui.GetIO()
    io.ConfigFlags = unsafe_load(io.ConfigFlags) | CImGui.ImGuiConfigFlags_DockingEnable
    io.ConfigFlags = unsafe_load(io.ConfigFlags) | CImGui.ImGuiConfigFlags_ViewportsEnable

    # scale
    io.FontGlobalScale = 2

    # setup Dear ImGui style
    CImGui.StyleColorsDark()
    # CImGui.StyleColorsClassic()
    # CImGui.StyleColorsLight()

    # When viewports are enabled we tweak WindowRounding/WindowBg so platform windows can look identical to regular ones.
    style = Ptr{ImGuiStyle}(CImGui.GetStyle())

    # create texture for image drawing
    #img_width, img_height = 256, 256
    # image_id = ImGuiOpenGLBackend.ImGui_ImplOpenGL3_CreateImageTexture(img_width, img_height)

    # setup Platform/Renderer bindings
    ImGuiGLFWBackend.init(window_ctx)
    ImGuiOpenGLBackend.init(gl_ctx)

    try
        clear_color = Cfloat[0.45, 0.55, 0.60, 1.00]
        t1 = time()
        while glfwWindowShouldClose(window) == 0
            glfwPollEvents()
            # start the Dear ImGui frame
            ImGuiOpenGLBackend.new_frame(gl_ctx)
            ImGuiGLFWBackend.new_frame(window_ctx)
            CImGui.NewFrame()
            guidata.fps = 0
            try
                t2 = time()
                guidata.fps = trunc(Int,1/(t2-t1))
                t1=t2
            catch e
                if !( e isa InexactError)
                    throw(e)
                end
            end

            guidata.plotY = rand(Float64, nPlot)

            ControlWindow(guidata)
            if (guidata.plotterOn)
                PlotterWindow(guidata)
            end
            # show image example

            # rendering
            CImGui.Render()
            glfwMakeContextCurrent(window)

            width, height = Ref{Cint}(), Ref{Cint}() #! need helper fcn
            glfwGetFramebufferSize(window, width, height)
            display_w = width[]
            display_h = height[]

            glViewport(0, 0, display_w, display_h)
            glClearColor(clear_color...)
            glClear(GL_COLOR_BUFFER_BIT)
            ImGuiOpenGLBackend.render(gl_ctx)

            if unsafe_load(igGetIO().ConfigFlags) & ImGuiConfigFlags_ViewportsEnable == ImGuiConfigFlags_ViewportsEnable
                backup_current_context = glfwGetCurrentContext()
                igUpdatePlatformWindows()
                GC.@preserve gl_ctx igRenderPlatformWindowsDefault(C_NULL, pointer_from_objref(gl_ctx))
                glfwMakeContextCurrent(backup_current_context)
            end

            glfwSwapBuffers(window)
        end
    catch e
        @error "Error in renderloop!" exception=e
        Base.show_backtrace(stderr, catch_backtrace())
    finally
        ImGuiOpenGLBackend.shutdown(gl_ctx)
        ImGuiGLFWBackend.shutdown(window_ctx)
        CImGui.DestroyContext(ctx)
        glfwDestroyWindow(window)
    end
end

GuiWindow()