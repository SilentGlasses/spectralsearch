vim9script

# spectral_search.vim - Core implementation of Spectral Search plugin
# Maintainer: SilentGlasses
# Version:    1.1
# License:    VIM License

# Internal variables
var spectral_matches: list<number> = []
var last_search_pattern: string = ''
var has_term_colors: bool = false
var highlight_groups: list<string> = []

# Heatmap visualization variables
var heatmap_enabled: bool = false
var heatmap_buffer: number = -1
var heatmap_window: number = -1
var heatmap_match_density: list<number> = []
var heatmap_width: number = 2
var heatmap_segments: number = 40
var heatmap_gradient_colors: list<string> = []
var heatmap_highlight_groups: list<string> = []
var heatmap_debounce_timer: number = -1
var heatmap_match_positions: dict<list<number>> = {}
var heatmap_last_buffer: number = -1
var heatmap_max_density: number = 0
var heatmap_needs_update: bool = false

# Minimap visualization variables
var minimap_enabled: bool = false
var minimap_buffer: number = -1
var minimap_window: number = -1
var minimap_width: number = 20
var minimap_highlight_matches: bool = true
var minimap_match_highlights: list<number> = []
var minimap_content_timer: number = -1
var minimap_scroll_ratio: float = 1.0
var minimap_last_top_line: number = 0
var minimap_last_buffer: number = -1

# Initialization
export def Initialize(): void
    try
        # Check for terminal color support
        has_term_colors = has('termguicolors') && &termguicolors
        if !has_term_colors
            echo "Spectral Search: Limited color support detected. Using fallback colors."
        endif

        # Create initial highlight groups
        CreateHighlightGroups()

        # Set last search pattern to current search
        last_search_pattern = @/

        # Initialize heatmap setting from global value
        if exists('g:spectral_search_heatmap')
            heatmap_enabled = g:spectral_search_heatmap
        endif
        
        # Initialize heatmap width from global value
        if exists('g:spectral_search_heatmap_width')
            heatmap_width = g:spectral_search_heatmap_width
        endif
        
        # Initialize heatmap segments from global value
        if exists('g:spectral_search_heatmap_segments')
            heatmap_segments = g:spectral_search_heatmap_segments
        endif
        
        # Create heatmap highlight groups
        CreateHeatmapHighlightGroups()
        
        # Initialize minimap setting from global value
        if exists('g:spectral_minimap_enabled')
            minimap_enabled = g:spectral_minimap_enabled
        endif
        
        # Initialize minimap width from global value
        if exists('g:spectral_minimap_width')
            minimap_width = g:spectral_minimap_width
        endif
        
        # Initialize minimap highlight matches setting from global value
        if exists('g:spectral_minimap_highlight_matches')
            minimap_highlight_matches = g:spectral_minimap_highlight_matches
        endif

        echo "Spectral Search initialized."
    catch
        echohl ErrorMsg
        echom "Error during initialization: " .. v:exception
        echohl None
    endtry
enddef

# Toggle spectral search on/off
export def Toggle(): void
    g:spectral_search_enabled = !g:spectral_search_enabled

    if g:spectral_search_enabled
        ApplyHighlights()
        echo "Spectral Search enabled"
    else
        ClearHighlights()
        echo "Spectral Search disabled"
    endif
enddef

# Set the gradient style
export def SetGradient(gradient: string): void
    if gradient != 'heat' && gradient != 'rainbow'
        echo "Invalid gradient style. Use 'heat' or 'rainbow'."
        return
    endif

    g:spectral_search_gradient = gradient
    if g:spectral_search_enabled
        # Re-apply with new gradient
        ClearHighlights()
        CreateHighlightGroups()
        ApplyHighlights()
        echo "Spectral Search gradient set to " .. gradient
    endif
enddef

# Create highlight groups for spectral highlighting
export def CreateHighlightGroups(): void
    # Clear previous highlight groups
    for group in highlight_groups
        execute 'highlight clear ' .. group
    endfor
    highlight_groups = []

    # Number of highlight groups to create
    var num_groups = 5

    # Generate highlight groups
    for i in range(num_groups)
        var group_name = 'SpectralSearch' .. i
        var color = printf('#%02X%02X%02X', i * 50, 255 - (i * 50), 128)
        execute 'highlight ' .. group_name .. ' guibg=' .. color
        add(highlight_groups, group_name)
    endfor
enddef

# Create highlight groups for heatmap visualization
export def CreateHeatmapHighlightGroups(): void
    # Clear previous heatmap highlight groups
    for group in heatmap_highlight_groups
        execute 'highlight clear ' .. group
    endfor
    heatmap_highlight_groups = []
    heatmap_gradient_colors = []
    
    # Number of highlight groups to create for heatmap
    var num_groups = 10
    
    # Generate highlight groups based on current gradient setting
    var gradient = exists('g:spectral_search_gradient') ? g:spectral_search_gradient : 'heat'
    
    for i in range(num_groups)
        var group_name = 'SpectralHeatmap' .. i
        var color = ''
        var intensity = i * (1.0 / (num_groups - 1))
        
        if gradient == 'heat'
            # Blue -> Green -> Yellow -> Red gradient
            if intensity < 0.33
                # Blue to Green (0.0 - 0.33)
                var normalized = intensity * 3.0
                color = printf('#%02X%02X%02X', 
                    float2nr(normalized * 255), 
                    float2nr(normalized * 255), 
                    float2nr((1.0 - normalized) * 255))
            elseif intensity < 0.66
                # Green to Yellow (0.33 - 0.66)
                var normalized = (intensity - 0.33) * 3.0
                color = printf('#%02X%02X%02X', 
                    float2nr(normalized * 255 + (1.0 - normalized) * 0), 
                    float2nr(255), 
                    float2nr(0))
            else
                # Yellow to Red (0.66 - 1.0)
                var normalized = (intensity - 0.66) * 3.0
                color = printf('#%02X%02X%02X', 
                    float2nr(255), 
                    float2nr((1.0 - normalized) * 255), 
                    float2nr(0))
            endif
        else
            # Rainbow gradient (ROYGBIV)
            if intensity < 0.166
                # Red to Orange
                var normalized = intensity * 6.0
                color = printf('#%02X%02X%02X', 255, float2nr(normalized * 127), 0)
            elseif intensity < 0.332
                # Orange to Yellow
                var normalized = (intensity - 0.166) * 6.0
                color = printf('#%02X%02X%02X', 255, float2nr(127 + normalized * 128), 0)
            elseif intensity < 0.498
                # Yellow to Green
                var normalized = (intensity - 0.332) * 6.0
                color = printf('#%02X%02X%02X', float2nr((1.0 - normalized) * 255), 255, 0)
            elseif intensity < 0.664
                # Green to Blue
                var normalized = (intensity - 0.498) * 6.0
                color = printf('#%02X%02X%02X', 0, float2nr((1.0 - normalized) * 255), float2nr(normalized * 255))
            elseif intensity < 0.83
                # Blue to Indigo
                var normalized = (intensity - 0.664) * 6.0
                color = printf('#%02X%02X%02X', float2nr(normalized * 75), 0, 255)
            else
                # Indigo to Violet
                var normalized = (intensity - 0.83) * 6.0
                color = printf('#%02X%02X%02X', float2nr(75 + normalized * 180), 0, float2nr(255 - normalized * 55))
            endif
        endif
        
        # Add color to list for later use
        add(heatmap_gradient_colors, color)
        
        # Create the highlight group
        if has_term_colors
            execute 'highlight ' .. group_name .. ' guibg=' .. color
        else
            # Fallback for terminals without true color support
            var term_color = i < 5 ? i + 1 : i - 4
            execute 'highlight ' .. group_name .. ' ctermbg=' .. term_color
        endif
        
        add(heatmap_highlight_groups, group_name)
    endfor
enddef

# Apply spectral highlights to search results
export def ApplyHighlights(): void
    try
        # Clear existing highlights
        ClearHighlights()

        # Get the current search pattern
        var pattern = @/
        if pattern == ''
            return  # No search pattern
        endif

        # Save the pattern for later updates
        last_search_pattern = pattern

        # Apply highlights for matches
        var match_id = matchadd('Search', pattern)
        add(spectral_matches, match_id)
        
        # Update heatmap if enabled
        if heatmap_enabled
            UpdateHeatmapVisualization(pattern)
        endif
        
        # Update minimap if enabled
        if minimap_enabled && minimap_highlight_matches
            UpdateMinimapHighlights(pattern)
        endif
    catch
        echohl ErrorMsg
        echom "Error applying highlights: " .. v:exception
        echohl None
    endtry
enddef

# Clear all spectral highlights
export def ClearHighlights(): void
    try
        for id in spectral_matches
            call matchdelete(id)
        endfor
        spectral_matches = []
    catch
        echohl ErrorMsg
        echom "Error clearing highlights: " .. v:exception
        echohl None
    endtry
enddef
# Calculate match density for current buffer and search pattern
def CalculateMatchDensity(pattern: string): dict<any>
    var result = {
        'density': repeat([0], heatmap_segments),
        'max_density': 0,
        'total_matches': 0,
        'positions': {}
    }
    
    if pattern == ''
        return result
    endif
    
    try
        # Get current buffer and line count
        var buf_nr = bufnr('%')
        var line_count = line('$')
        if line_count < 1
            return result
        endif
        
        # Calculate segment size (how many lines per segment)
        var segment_size = (line_count * 1.0) / heatmap_segments
        
        # Initialize line-match positions dictionary
        var line_matches: dict<list<number>> = {}
        
        # Save current position and search settings
        var save_cursor = getcurpos()
        var save_wrapscan = &wrapscan
        var save_ignorecase = &ignorecase
        var save_smartcase = &smartcase
        
        # Set search options for consistency
        set nowrapscan
        
        # Move to start of buffer to begin search
        cursor(1, 1)
        
        # Find all matches in the buffer
        var total_matches = 0
        var match_pos = searchpos(pattern, 'W')
        
        while match_pos[0] > 0
            var line_nr = match_pos[0]
            var col_nr = match_pos[1]
            
            # Initialize line entry if needed
            if !has_key(line_matches, string(line_nr))
                line_matches[string(line_nr)] = []
            endif
            
            # Add match column to line
            add(line_matches[string(line_nr)], col_nr)
            
            # Increment total matches
            total_matches += 1
            
            # Calculate segment index for this match
            var segment_idx = float2nr((line_nr - 1) / segment_size)
            if segment_idx >= heatmap_segments
                segment_idx = heatmap_segments - 1
            endif
            
            # Increment density for segment
            result.density[segment_idx] += 1
            
            # Find next match
            match_pos = searchpos(pattern, 'W')
        endwhile
        
        # Restore search settings
        let &wrapscan = save_wrapscan
        let &ignorecase = save_ignorecase
        let &smartcase = save_smartcase
        
        # Restore cursor position
        setpos('.', save_cursor)
        
        # Set total matches
        result.total_matches = total_matches
        
        # Set match positions
        result.positions = line_matches
        
        # Find max density
        var max_density = 0
        for density in result.density
            if density > max_density
                max_density = density
            endif
        endfor
        
        result.max_density = max_density
        
        return result
    catch
        # Restore cursor position in case of error
        if exists('save_cursor')
            setpos('.', save_cursor)
        endif
        
        # Restore search settings in case of error
        if exists('save_wrapscan')
            let &wrapscan = save_wrapscan
        endif
        if exists('save_ignorecase')
            let &ignorecase = save_ignorecase
        endif
        if exists('save_smartcase')
            let &smartcase = save_smartcase
        endif
        
        echohl ErrorMsg
        echom "Error calculating match density: " .. v:exception
        echohl None
        return result
    endtry
enddef

# Update the heatmap visualization
export def UpdateHeatmapVisualization(pattern: string): void
    # Cancel any pending updates
    if heatmap_debounce_timer != -1
        timer_stop(heatmap_debounce_timer)
        heatmap_debounce_timer = -1
    endif
    
    # Schedule update with debounce (100ms)
    heatmap_debounce_timer = timer_start(100, (timer_id) => {
        heatmap_debounce_timer = -1
        DoUpdateHeatmap(pattern)
    })
enddef

# Perform the actual heatmap update
def DoUpdateHeatmap(pattern: string): void
    try
        # Current buffer
        var buf_nr = bufnr('%')
        heatmap_last_buffer = buf_nr
        
        # Calculate match density
        var density_result = CalculateMatchDensity(pattern)
        heatmap_match_density = density_result.density
        heatmap_match_positions = density_result.positions
        heatmap_max_density = density_result.max_density
        
        # Check if heatmap window already exists
        if heatmap_buffer != -1 && heatmap_window != -1 && bufexists(heatmap_buffer) && win_id2win(heatmap_window) > 0
            # Update existing heatmap
            RenderHeatmap()
        else
            # Create new heatmap
            CreateHeatmapWindow()
        endif
    catch
        echohl ErrorMsg
        echom "Error updating heatmap: " .. v:exception
        echohl None
    endtry
enddef

# Create the heatmap window
def CreateHeatmapWindow(): void
    try
        # Close existing heatmap if it exists
        CloseHeatmapWindow()
        
        # Create new buffer for heatmap
        heatmap_buffer = bufadd('SpectralHeatmap')
        bufload(heatmap_buffer)
        
        # Set buffer options
        setbufvar(heatmap_buffer, '&buftype', 'nofile')
        setbufvar(heatmap_buffer, '&bufhidden', 'hide')
        setbufvar(heatmap_buffer, '&swapfile', 0)
        setbufvar(heatmap_buffer, '&modifiable', 1)
        setbufvar(heatmap_buffer, '&buflisted', 0)
        
        # Create window for heatmap at the far right
        var opts = {
            'relative': 'win',
            'win': winnr(),
            'width': heatmap_width,
            'height': &lines - &cmdheight - 1, # Account for command line
            'col': &columns - heatmap_width,
            'row': 0,
            'anchor': 'NE',
            'style': 'minimal',
            'focusable': 0,
            'zindex': 50,
        }
        
        # Create the floating window
        heatmap_window = popup_create(heatmap_buffer, opts)
        
        # Set window options
        win_execute(heatmap_window, 'setlocal nonumber norelativenumber signcolumn=no colorcolumn= nocursorline nocursorcolumn')
        
        # Initial render
        RenderHeatmap()
    catch
        echohl ErrorMsg
        echom "Error creating heatmap window: " .. v:exception
        echohl None
    endtry
enddef

# Render the heatmap content
def RenderHeatmap(): void
    if heatmap_buffer == -1 || !bufexists(heatmap_buffer)
        return
    endif
    
    try
        # Get buffer dimensions
        var buf_height = &lines - &cmdheight - 1
        if buf_height < 1
            return
        endif
        
        # Calculate how many lines each segment represents
        var lines_per_segment = (buf_height * 1.0) / heatmap_segments
        if lines_per_segment < 0.1
            lines_per_segment = 0.1
        endif
        
        # Prepare content
        var content = []
        var match add(content, '')
        
        # Create heatmap content
        for i in range(heatmap_segments)
            var density = heatmap_match_density[i]
            var highlight_idx = 0
            
            # Calculate normalized density and highlight index
            if heatmap_max_density > 0
                var normalized_density = (density * 1.0) / heatmap_max_density
                highlight_idx = float2nr(normalized_density * (len(heatmap_highlight_groups) - 1))
                if highlight_idx >= len(heatmap_highlight_groups)
                    highlight_idx = len(heatmap_highlight_groups) - 1
                endif
            endif
            
            # Calculate number of lines for this segment
            var lines_count = float2nr(lines_per_segment + 0.5)
            if lines_count < 1
                lines_count = 1
            endif
            
            # Add segment lines with appropriate highlight
            var highlight_group = heatmap_highlight_groups[highlight_idx]
            var segment_line = repeat(' ', heatmap_width)
            
            # Add lines with highlight command
            for j in range(lines_count)
                add(content, segment_line)
                if density > 0
                    # Build match command for highlighting
                    var line_nr = len(content)
                    var match_cmd = 'syn match ' .. highlight_group .. ' /\%' .. line_nr .. 'l.*/'
                    match match_cmd
                endif
            endfor
        endfor
        
        # Clear buffer
        deletebufline(heatmap_buffer, 1, '$')
        
        # Set buffer content
        setbufline(heatmap_buffer, 1, content)
    catch
        echohl ErrorMsg
        echom "Error rendering heatmap: " .. v:exception
        echohl None
    endtry
enddef

# Close the heatmap window and cleanup
def CloseHeatmapWindow(): void
    try
        # Close popup window if it exists
        if heatmap_window != -1 && win_id2win(heatmap_window) > 0
            popup_close(heatmap_window)
        endif
        
        # Clean up buffer if it exists
        if heatmap_buffer != -1 && bufexists(heatmap_buffer)
            execute 'bwipeout! ' .. heatmap_buffer
        endif
        
        # Reset variables
        heatmap_window = -1
        heatmap_buffer = -1
    catch
        echohl ErrorMsg
        echom "Error closing heatmap window: " .. v:exception
        echohl None
    endtry
enddef

# Toggle heatmap visualization on/off
export def ToggleHeatmap(): void
    heatmap_enabled = !heatmap_enabled
    g:spectral_search_heatmap = heatmap_enabled
    
    if heatmap_enabled
        # Create and update heatmap
        if last_search_pattern != ''
            UpdateHeatmapVisualization(last_search_pattern)
        endif
        echo "Spectral Search Heatmap enabled"
    else
        # Close heatmap window
        CloseHeatmapWindow()
        echo "Spectral Search Heatmap disabled"
    endif
enddef

# Set heatmap width
export def SetHeatmapWidth(width: number): void
    if width < 1 || width > 10
        echo "Invalid heatmap width. Use a value between 1 and 10."
        return
    endif
    
    heatmap_width = width
    g:spectral_search_heatmap_width = width
    
    if heatmap_enabled && last_search_pattern != ''
        # Update heatmap with new width
        CloseHeatmapWindow()
        UpdateHeatmapVisualization(last_search_pattern)
    endif
    
    echo "Heatmap width set to " .. width
enddef

# Set heatmap segments
export def SetHeatmapSegments(segments: number): void
    if segments < 10 || segments > 100
        echo "Invalid heatmap segments. Use a value between 10 and 100."
        return
    endif
    
    heatmap_segments = segments
    g:spectral_search_heatmap_segments = segments
    
    if heatmap_enabled && last_search_pattern != ''
        # Update heatmap with new segments
        UpdateHeatmapVisualization(last_search_pattern)
    endif
    
    echo "Heatmap segments set to " .. segments
enddef

# Generate status line information for heatmap
export def GetHeatmapStatusline(): string
    if !heatmap_enabled || heatmap_max_density == 0
        return ''
    endif
    
    # Use Unicode block characters to show density in status line
    var blocks = ['▁', '▂', '▃', '▄', '▅', '▆', '▇', '█']
    var segment_count = min([10, heatmap_segments])  # Use at most 10 segments for statusline
    var segment_size = heatmap_segments / segment_count
    
    var result = ' '
    
    for i in range(segment_count)
        var start_idx = i * segment_size
        var end_idx = start_idx + segment_size
        if end_idx > heatmap_segments
            end_idx = heatmap_segments
        endif
        
        # Calculate average density for this segment
        var sum = 0
        var count = 0
        for j in range(start_idx, end_idx - 1)
            sum += heatmap_match_density[j]
            count += 1
        endfor
        
        var avg_density = count > 0 ? sum / count : 0
        
        # Calculate block index based on density
        var normalized = heatmap_max_density > 0 ? (avg_density * 1.0) / heatmap_max_density : 0
        var block_idx = float2nr(normalized * (len(blocks) - 1))
        if block_idx >= len(blocks)
            block_idx = len(blocks) - 1
        endif
        
        # Add block character
        result ..= blocks[block_idx]
    endfor
    
    return result
enddef

export def ShowInfo(): void
    echo "Spectral Search Information:"
    echo "  Enabled:     " .. (g:spectral_search_enabled ? "Yes" : "No")
    echo "  Matches:     " .. len(spectral_matches)
    echo "  Heatmap:     " .. (heatmap_enabled ? "Enabled" : "Disabled")
    if heatmap_enabled
        echo "  Heatmap Width: " .. heatmap_width
        echo "  Heatmap Segments: " .. heatmap_segments
        echo "  Max Density: " .. heatmap_max_density
    endif
    echo "  Minimap:     " .. (minimap_enabled ? "Enabled" : "Disabled")
    if minimap_enabled
        echo "  Minimap Width: " .. minimap_width
        echo "  Minimap Highlights: " .. (minimap_highlight_matches ? "Enabled" : "Disabled")
    endif
enddef

# Create the minimap window
export def CreateMinimapWindow(): void
    try
        # Close existing minimap if it exists
        CloseMinimapWindow()
        
        # Create new buffer for minimap
        minimap_buffer = bufadd('SpectralMinimap')
        bufload(minimap_buffer)
        
        # Set buffer options
        setbufvar(minimap_buffer, '&buftype', 'nofile')
        setbufvar(minimap_buffer, '&bufhidden', 'hide')
        setbufvar(minimap_buffer, '&swapfile', 0)
        setbufvar(minimap_buffer, '&modifiable', 1)
        setbufvar(minimap_buffer, '&buflisted', 0)
        setbufvar(minimap_buffer, '&list', 0)
        setbufvar(minimap_buffer, '&wrap', 0)
        
        # Calculate position for minimap - place at right side
        var width = minimap_width
        var height = &lines - &cmdheight - 1
        
        # Create split window for minimap
        var cur_win = win_getid()
        execute 'silent! vertical botright ' .. width .. 'split'
        execute 'buffer ' .. minimap_buffer
        minimap_window = win_getid()
        
        # Add special highlight for minimap text
        execute 'highlight SpectralMinimapText guifg=#555555 ctermfg=8'
        win_execute(minimap_window, 'syntax match SpectralMinimapText /.*/')
        
        # Set window options
        win_execute(minimap_window, 'setlocal nonumber norelativenumber signcolumn=no colorcolumn=' ..
            ' nocursorline nocursorcolumn nofoldenable foldcolumn=0 nolist nowrap')
        
        # Reduce character size if possible
        win_execute(minimap_window, 'setlocal winminwidth=1')
        
        # Return to original window
        win_gotoid(cur_win)
        
        # Enable scrollbind between windows
        var main_win_view = winsaveview()
        win_execute(minimap_window, 'setlocal scrollbind')
        win_execute(cur_win, 'setlocal scrollbind')
        win_execute(cur_win, 'syncbind')
        
        # Update minimap content initially
        UpdateMinimapContent()
        
        # Update highlights if matches should be shown
        if minimap_highlight_matches && last_search_pattern != ''
            UpdateMinimapHighlights(last_search_pattern)
        endif
        
        # Set up autocmd to update minimap when main buffer changes
        augroup SpectralMinimap
            autocmd!
            autocmd CursorMoved,CursorMovedI * call spectral_search#UpdateMinimapScroll()
            autocmd BufEnter * call spectral_search#CheckMinimapBuffer()
            autocmd TextChanged,TextChangedI * call spectral_search#UpdateMinimapContent()
            autocmd VimResized * call spectral_search#ResizeMinimap()
            autocmd WinEnter,WinLeave * call spectral_search#UpdateMinimapFocus()
            autocmd ColorScheme * call spectral_search#UpdateMinimapColors()
        augroup END
        
        echo "Spectral Search Minimap created"
    catch
        echohl ErrorMsg
        echom "Error creating minimap window: " .. v:exception
        echohl None
    endtry
enddef

# Close the minimap window and cleanup
export def CloseMinimapWindow(): void
    try
        # Disable scrollbind in main window
        for winid in range(1, winnr('$'))
            win_execute(win_getid(winid), 'setlocal noscrollbind')
        endfor
        
        # Remove autocmds
        autocmd! SpectralMinimap
        
        # Close minimap window if it exists
        if minimap_window != -1
            if win_id2win(minimap_window) > 0
                win_execute(minimap_window, 'close!')
            endif
            minimap_window = -1
        endif
        
        # Clean up buffer if it exists
        if minimap_buffer != -1 && bufexists(minimap_buffer)
            execute 'bwipeout! ' .. minimap_buffer
            minimap_buffer = -1
        endif
        
        # Clean up highlights
        ClearMinimapHighlights()
        
        # Reset scroll status
        minimap_last_top_line = 0
    catch
        echohl ErrorMsg
        echom "Error closing minimap window: " .. v:exception
        echohl None
    endtry
enddef

# Check if minimap needs to be recreated for current buffer
export def CheckMinimapBuffer(): void
    if !minimap_enabled
        return
    endif

    try
        var cur_buf = bufnr('%')
        if cur_buf != minimap_buffer && cur_buf != minimap_last_buffer
            minimap_last_buffer = cur_buf
            
            # Only recreate for normal buffers
            var buftype = getbufvar(cur_buf, '&buftype')
            if buftype == ''
                # Add a short delay to allow buffer to settle
                if minimap_content_timer != -1
                    timer_stop(minimap_content_timer)
                endif
                
                minimap_content_timer = timer_start(100, (timer_id) => {
                    minimap_content_timer = -1
                    
                    # Close and recreate the minimap
                    CloseMinimapWindow()
                    CreateMinimapWindow()
                })
            endif
        endif
    catch
        echohl ErrorMsg
        echom "Error checking minimap buffer: " .. v:exception
        echohl None
    endtry
enddef

# Update scrolling of minimap to match main window
export def UpdateMinimapScroll(): void
    if !minimap_enabled || minimap_window == -1 || win_id2win(minimap_window) == 0
        return
    endif
    
    try
        # Update is only needed if scrollbind isn't working properly
        # This is a backup to ensure proper scrolling
        var curr_view = winsaveview()
        var top_line = curr_view.topline
        
        # Only update if significant change
        if abs(top_line - minimap_last_top_line) > 3
            minimap_last_top_line = top_line
            
            # Force scroll sync
            win_execute(minimap_window, 'normal! zt')
            win_execute(win_getid(), 'syncbind')
        endif
    catch
        # Silently ignore scroll errors
    endtry
enddef

# Update minimap focus styling
export def UpdateMinimapFocus(): void
    if !minimap_enabled || minimap_window == -1 || win_id2win(minimap_window) == 0
        return
    endif
    
    try
        # Check if minimap window is active
        var cur_win = win_getid()
        if cur_win == minimap_window
            # Minimap is active, give focus to main window
            for winid in range(1, winnr('$'))
                if win_getid(winid) != minimap_window
                    win_gotoid(win_getid(winid))
                    break
                endif
            endfor
        endif
    catch
        # Silently ignore focus errors
    endtry
enddef

# Update minimap colors after colorscheme change
export def UpdateMinimapColors(): void
    if !minimap_enabled
        return
    endif
    
    try
        # Recreate highlight groups
        CreateHighlightGroups()
        
        # Re-apply highlights if needed
        if minimap_highlight_matches && last_search_pattern != ''
            UpdateMinimapHighlights(last_search_pattern)
        endif
        
        # Update minimap text color
        execute 'highlight SpectralMinimapText guifg=#555555 ctermfg=8'
    catch
        # Silently ignore color update errors
    endtry
enddef

# Update the minimap content
export def UpdateMinimapContent(): void
    if !minimap_enabled || minimap_buffer == -1 || !bufexists(minimap_buffer)
        return
    endif
    
    # Cancel any pending updates
    if minimap_content_timer != -1
        timer_stop(minimap_content_timer)
        minimap_content_timer = -1
    endif
    
    # Schedule update with debounce (200ms)
    minimap_content_timer = timer_start(200, (timer_id) => {
        minimap_content_timer = -1
        DoUpdateMinimapContent()
    })
enddef

# Perform the actual minimap content update
def DoUpdateMinimapContent(): void
    if !minimap_enabled || minimap_buffer == -1 || !bufexists(minimap_buffer)
        return
    endif
    
    try
        # Get current buffer
        var cur_buf = bufnr('%')
        var content = getbufline(cur_buf, 1, '$')
        
        # Process content to make it compact for minimap
        var minimap_content = []
        
        # Setting for minimap content density
        var max_line_length = 100  # Truncate very long lines
        
        # Process each line to create minimap representation
        for line in content
            # Skip empty lines in compact mode or just add an empty line
            if line =~ '^\s*$'
                add(minimap_content, '')
                continue
            endif
            
            # Compress whitespace to maximize information density
            var processed = substitute(line, '\s\+', ' ', 'g')
            
            # Truncate line if too long
            if strchars(processed) > max_line_length
                processed = strcharpart(processed, 0, max_line_length)
            endif
            
            add(minimap_content, processed)
        endfor
        
        # Temporarily make buffer modifiable
        var was_modifiable = getbufvar(minimap_buffer, '&modifiable')
        setbufvar(minimap_buffer, '&modifiable', 1)
        
        # Update buffer contents
        deletebufline(minimap_buffer, 1, '$')
        setbufline(minimap_buffer, 1, minimap_content)
        
        # Restore modifiable state
        setbufvar(minimap_buffer, '&modifiable', was_modifiable)
        
        # Re-apply highlights if needed
        if minimap_highlight_matches && last_search_pattern != ''
            UpdateMinimapHighlights(last_search_pattern)
        endif
    catch
        echohl ErrorMsg
        echom "Error updating minimap content: " .. v:exception
        echohl None
    endtry
enddef

# Update minimap highlighting to show search matches
export def UpdateMinimapHighlights(pattern: string): void
    if !minimap_enabled || !minimap_highlight_matches || minimap_buffer == -1
        return
    endif
    
    try
        # Clear existing highlights
        ClearMinimapHighlights()
        
        # Get match positions if not already calculated
        if empty(heatmap_match_positions) && pattern != ''
            var density_result = CalculateMatchDensity(pattern)
            heatmap_match_positions = density_result.positions
        endif
        
        # No matches to highlight
        if empty(heatmap_match_positions)
            return
        endif
        
        # Calculate how many highlight groups we have
        var num_spectral_groups = len(highlight_groups)
        if num_spectral_groups == 0
            return
        endif
        
        # Iterate through match positions and highlight them
        var match_count = 0
        var max_matches = exists('g:spectral_search_max_matches') ? g:spectral_search_max_matches : 100
        
        # Sort lines for better spectral distribution
        var line_keys = keys(heatmap_match_positions)
        sort(line_keys, 'n')
        
        for line_nr in line_keys
            var columns = heatmap_match_positions[line_nr]
            
            # Skip if no columns or line number is not valid
            if len(columns) == 0 || str2nr(line_nr) < 1
                continue
            endif
            
            # Calculate highlight group based on match count
            var idx = min([float2nr(match_count * 1.0 / max_matches * num_spectral_groups), num_spectral_groups - 1])
            var highlight_group = highlight_groups[idx]
            
            # Create match for line
            var match_id = matchaddpos(highlight_group, [[str2nr(line_nr), 1]])
            add(minimap_match_highlights, match_id)
            
            # Increment match count
            match_count += 1
            
            # Stop if we hit the limit
            if match_count >= max_matches
                break
            endif
        endfor
    catch
        echohl ErrorMsg
        echom "Error updating minimap highlights: " .. v:exception
        echohl None
    endtry
enddef

# Clear all minimap highlights
export def ClearMinimapHighlights(): void
    try
        for id in minimap_match_highlights
            matchdelete(id)
        endfor
        minimap_match_highlights = []
    catch
        # Silently ignore errors when clearing highlights
    endtry
enddef

# Toggle minimap visualization on/off
export def ToggleMinimap(): void
    minimap_enabled = !minimap_enabled
    g:spectral_minimap_enabled = minimap_enabled
    
    if minimap_enabled
        # Create minimap window
        CreateMinimapWindow()
        echo "Spectral Search Minimap enabled"
    else
        # Close minimap window
        CloseMinimapWindow()
        echo "Spectral Search Minimap disabled"
    endif
enddef

# Set minimap width
export def SetMinimapWidth(width: number): void
    if width < 5 || width > 40
        echo "Invalid minimap width. Use a value between 5 and 40."
        return
    endif
    
    minimap_width = width
    g:spectral_minimap_width = width
    
    if minimap_enabled
        # Update minimap with new width
        CloseMinimapWindow()
        CreateMinimapWindow()
    endif
    
    echo "Minimap width set to " .. width
enddef

# Toggle minimap match highlighting
export def ToggleMinimapHighlights(): void
    minimap_highlight_matches = !minimap_highlight_matches
    g:spectral_minimap_highlight_matches = minimap_highlight_matches
    
    if minimap_enabled
        if minimap_highlight_matches && last_search_pattern != ''
            # Apply highlights
            UpdateMinimapHighlights(last_search_pattern)
            echo "Minimap highlights enabled"
        else
            # Clear highlights
            ClearMinimapHighlights()
            echo "Minimap highlights disabled"
        endif
    endif
enddef

# Handle window resize for minimap
export def ResizeMinimap(): void
    if !minimap_enabled || minimap_window == -1 || win_id2win(minimap_window) == 0
        return
    endif
    
    try
        # Get current dimensions
        var height = &lines - &cmdheight - 1
        
        # Adjust minimap height
        win_execute(minimap_window, 'resize ' .. height)
        
        # Force update of content to match new size
        UpdateMinimapContent()
    catch
        echohl ErrorMsg
        echom "Error resizing minimap: " .. v:exception
        echohl None
    endtry
enddef

# Generate status line information for minimap
export def GetMinimapStatusline(): string
    if !minimap_enabled
        return ''
    endif
    
    var result = ' [minimap] '
    
    # Add match count
    var matches = 0
    for positions in values(heatmap_match_positions)
        matches += len(positions)
    endfor
    
    if matches > 0
        result ..= matches .. ' matches'
    endif
    
    return result
enddef
