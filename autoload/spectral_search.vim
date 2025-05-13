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

# Show plugin information
export def ShowInfo(): void
    echo "Spectral Search Information:"
    echo "  Enabled:     " .. (g:spectral_search_enabled ? "Yes" : "No")
    echo "  Matches:     " .. len(spectral_matches)
    echo "  Heatmap:     " .. (heatmap_enabled ? "Enabled" : "Disabled")
enddef
