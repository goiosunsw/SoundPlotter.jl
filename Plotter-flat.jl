using CImGui
using CImGui.ImGuiGLFWBackend
using CImGui.ImGuiGLFWBackend.LibCImGui
using CImGui.ImGuiGLFWBackend.LibGLFW
using CImGui.ImGuiOpenGLBackend
using CImGui.ImGuiOpenGLBackend.ModernGL
# using CImGui.ImGuiGLFWBackend.GLFW
using CImGui.CSyntax
using CImGui.CSyntax.CStatic


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
    demo_open = true
    clear_color = Cfloat[0.45, 0.55, 0.60, 1.00]
    is_drawing = true
    color = @cstatic color = Cfloat[1.0,1.0,0.0,1.00]
    col32 = CImGui.ColorConvertFloat4ToU32(ImVec4(color...))
    th = @cstatic th = Cfloat(1.0)
    t1 = time()
    while glfwWindowShouldClose(window) == 0
        glfwPollEvents()
        # start the Dear ImGui frame
        ImGuiOpenGLBackend.new_frame(gl_ctx)
        ImGuiGLFWBackend.new_frame(window_ctx)
        CImGui.NewFrame()
        fps = 0
        try
            t2 = time()
            fps = trunc(Int,1/(t2-t1))
            t1=t2
        catch e
            if !( e isa InexactError)
                throw(e)
            end
        end


        if CImGui.Begin("Control")
            CImGui.Text("Frames per second $fps")
            #CImGui.SameLine()
            CImGui.Button("Button") && (is_drawing = ! is_drawing)
            CImGui.End()
        end

        # show image example
        if CImGui.Begin("Image Demo")
            draw_list = CImGui.GetWindowDrawList()
            canvas_pos = CImGui.GetCursorScreenPos()
            canvas_size = CImGui.GetContentRegionAvail()
            img_width = trunc(Int, canvas_size.x)
            img_height = trunc(Int, canvas_size.y)
            x = 1:img_width
            zero_pos = img_height ÷ 2
            # image = rand(GLubyte, 4, img_width, img_height)
            # image = zones(GLubyte, 4, img_width, img_height)
            # ImGuiOpenGLBackend.ImGui_ImplOpenGL3_UpdateImageTexture(image_id, image, img_width, img_height)
            # CImGui.Image(Ptr{Cvoid}(image_id), CImGui.ImVec2(img_width, img_height))
            # CImGui.End()
            #CImGui.PushClipRectFullScreen(draw_list)
            CImGui.AddLine(draw_list, ImVec2(canvas_pos.x,canvas_pos.y+zero_pos), 
                                        ImVec2(canvas_pos.x+img_width,canvas_pos.y+zero_pos), col32, th)

            if is_drawing
                y = trunc.(Int, rand(img_width)*img_height)

                for i in axes(y[1:end-1],1)
                    # println(x[i],", ",y[i])
                    CImGui.AddLine(draw_list, ImVec2(canvas_pos.x+x[i],canvas_pos.y+y[i]), 
                    ImVec2(canvas_pos.x+x[i+1],canvas_pos.y+y[i+1]), col32, th)
                end
                #CImGui.PopClipRect(draw_list)

            end
        end

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