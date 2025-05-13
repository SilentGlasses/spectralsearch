vim9script

# spectral-search.vim - Enhance Vim search with spectral highlighting
# Maintainer:   SilentGlasses
# Version:      1.0
# License:      VIM License

# Prevent loading the plugin multiple times
if exists('g:loaded_spectral_search')
    finish
endif

# Ensure Vim version is compatible
if v:version < 901
    echom "Spectral Search requires Vim 8 or higher"
    finish
endif

# Check for required features
if !has('syntax')
    echom "Spectral Search requires Vim with +syntax support"
    finish
endif

if !has('extra_search')
    echom "Spectral Search requires Vim with +extra_search support"
    finish
endif

# Mark plugin as loaded
g:loaded_spectral_search = 1

# Global configuration variables with defaults
if !exists('g:spectral_search_enabled')
    g:spectral_search_enabled = 1
endif

if !exists('g:spectral_search_gradient')
    g:spectral_search_gradient = 'heat'
endif

if !exists('g:spectral_search_intensity')
    g:spectral_search_intensity = 'medium'
endif

if !exists('g:spectral_search_max_matches')
    g:spectral_search_max_matches = 100
endif

# Heatmap configuration variables
if !exists('g:spectral_search_heatmap')
    g:spectral_search_heatmap = 0  # Disabled by default
endif

if !exists('g:spectral_search_heatmap_width')
    g:spectral_search_heatmap_width = 2  # Default width in characters
endif

if !exists('g:spectral_search_heatmap_segments')
    g:spectral_search_heatmap_segments = 40  # Default density segments
endif

if !exists('g:spectral_search_heatmap_auto_scroll')
    g:spectral_search_heatmap_auto_scroll = 1  # Enable scroll synchronization by default
endif

# Set up status line integration function
def g:SpectralSearchStatusline(): string
    return spectral_search#Statusline()
enddef

# Define plugin commands
command! SpectralSearchToggle call spectral_search#Toggle()
command! -nargs=1 -complete=customlist,spectral_search#GradientComplete 
    \ SpectralSearchGradient call spectral_search#SetGradient(<f-args>)
command! -nargs=1 -complete=customlist,spectral_search#IntensityComplete 
    \ SpectralSearchIntensity call spectral_search#SetIntensity(<f-args>)
command! SpectralSearchClear call spectral_search#ClearHighlights()
command! SpectralSearchInfo call spectral_search#ShowInfo()

# Heatmap visualization commands
command! SpectralSearchHeatmapToggle call spectral_search#ToggleHeatmap()
command! -nargs=1 -complete=customlist,spectral_search#WidthComplete 
    \ SpectralSearchHeatmapWidth call spectral_search#SetHeatmapWidth(<f-args>)
command! -nargs=1 -complete=customlist,spectral_search#SegmentsComplete 
    \ SpectralSearchHeatmapSegments call spectral_search#SetHeatmapSegments(<f-args>)
command! SpectralSearchHeatmapRefresh call spectral_search#UpdateHeatmapVisualization(@/)

# Create augroup for search events
augroup SpectralSearch
    autocmd!
    
    # Search handling
    autocmd CmdlineEnter [/?] autocmd SpectralSearch CmdlineLeave [/?] ++once 
        \ call spectral_search#ApplySpectralHighlights()
    autocmd TextChanged,TextChangedI * 
        \ if g:spectral_search_enabled | call spectral_search#UpdateHighlights() | endif
    autocmd ColorScheme * 
        \ if g:spectral_search_enabled | call spectral_search#ReapplyHighlights() | endif
    
    # Ensure proper window cleanup
    autocmd VimLeave * call spectral_search#ClearHighlights()
    
    # Window handling for heatmap
    autocmd VimResized * 
        \ if exists('g:spectral_search_heatmap') && g:spectral_search_heatmap | 
        \   call spectral_search#UpdateHeatmapVisualization(@/) | 
        \ endif
    
    # Buffer events for heatmap
    autocmd BufWinEnter,WinEnter * 
        \ if exists('g:spectral_search_heatmap') && g:spectral_search_heatmap | 
        \   call spectral_search#UpdateHeatmapVisualization(@/) | 
        \ endif
    
    # Scroll synchronization
    autocmd CursorMoved,CursorMovedI * 
        \ if exists('g:spectral_search_heatmap') && g:spectral_search_heatmap && 
        \   g:spectral_search_heatmap_auto_scroll | 
        \   call spectral_search#SyncHeatmapScroll() | 
        \ endif
    
    # Window management
    autocmd WinLeave * 
        \ if exists('g:spectral_search_heatmap') && g:spectral_search_heatmap | 
        \   call spectral_search#SyncHeatmapScroll() | 
        \ endif
augroup END

# Initialize the plugin
call spectral_search#Initialize()

# Ensure visibility of heatmap window initially if enabled
if g:spectral_search_heatmap && @/ != ''
    # Use proper vim9script lambda syntax
    timer_start(100, function(timer: number): void
        try
            if g:spectral_search_heatmap
                spectral_search#UpdateHeatmapVisualization(@/)
            endif
        catch
            # Silently handle errors during startup
        endtry
    endfunction)
endif
