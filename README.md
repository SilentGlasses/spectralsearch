# Spectral Search

> Enhance Vim's native search with spectral gradient highlighting

Spectral Search is a Vim plugin that visually enhances the native `/` and `?` search commands by highlighting matches using color gradients. Instead of all matches appearing in the same color, each match is highlighted with a color from a spectral gradient, making it easier to visually distinguish between multiple occurrences.


## Features

- Enhances native Vim search commands (`/` and `?`) with spectral highlighting
- Offers two gradient styles:
  - **Heat Map**: Blue → Green → Yellow → Red (default)
  - **Rainbow**: Red → Orange → Yellow → Green → Blue → Indigo → Violet
- Three intensity levels: low, medium (default), and high
- Works in terminal Vim (requires true color support for best results)
- Fallback to basic terminal colors when true colors aren't available
- Status line integration to show search status
- **Heatmap visualization** showing match density throughout the file
  - Optional sidebar visualization
  - Compact statusline integration
  - Color gradient matching search style
- Preserves all native search behaviors
- Compatible with standard Vim 9.1+ (not Neovim-specific)
- Written in pure Vimscript (Vim9script)

## Requirements

- Vim 9.1 or higher
- Vim compiled with `+vim9script`, `+syntax`, and `+extra_search` features
- Terminal with true color support recommended (but not required)

## Installation

### Using Vim's native package manager (Vim 8+)

```bash
git clone https://github.com/SilentGlasses/spectral-search.git ~/.vim/pack/plugins/start/spectral-search
vim -c "helptags ~/.vim/pack/plugins/start/spectral-search/doc" -c "q"
```

### Using plug.vim

Add to your `~/.vimrc`:

```vim
Plug 'SilentGlasses/spectral-search'
```

Then run `:PlugInstall`

### Using Vundle

Add to your `~/.vimrc`:

```vim
Plugin 'SilentGlasses/spectral-search'
```

Then run `:PluginInstall`

### Using dein.vim

Add to your configuration:

```vim
call dein#add('yourname/spectral-search')
```

## Basic Usage

Spectral Search works automatically once installed. Simply use Vim's standard search commands:

- Press `/` to search forward
- Press `?` to search backward
- Press `n` to go to the next match
- Press `N` to go to the previous match

All matches will be highlighted with a spectral gradient. Early matches start at one end of the spectrum (blue in heat map mode) and later matches transition to the other end (red in heat map mode).

### Commands

- `:SpectralSearchToggle` - Toggle spectral search on/off
- `:SpectralSearchGradient [heat|rainbow]` - Change the gradient style
- `:SpectralSearchIntensity [low|medium|high]` - Change the color intensity
- `:SpectralSearchClear` - Clear all spectral highlights
- `:SpectralSearchInfo` - Show current settings and status
- `:SpectralSearchHeatmapToggle` - Toggle the heatmap visualization
- `:SpectralSearchHeatmapWidth [1-10]` - Set the width of the heatmap sidebar
- `:SpectralSearchHeatmapSegments [10-100]` - Set the number of segments in the heatmap

## Configuration

Add any of these settings to your `~/.vimrc` to customize the default behavior:

```vim
" Enable/disable the plugin (default: 1 - enabled)
let g:spectral_search_enabled = 1

" Set the default gradient style (default: 'heat')
" Options: 'heat', 'rainbow'
let g:spectral_search_gradient = 'heat'

" Set the default intensity (default: 'medium')
" Options: 'low', 'medium', 'high'
let g:spectral_search_intensity = 'medium'

" Set the maximum number of matches to highlight (default: 100)
let g:spectral_search_max_matches = 100

" Enable/disable heatmap visualization (default: 0 - disabled)
let g:spectral_search_heatmap = 0

" Set the width of the heatmap sidebar (default: 2)
let g:spectral_search_heatmap_width = 2

" Set the number of segments in the heatmap (default: 40)
let g:spectral_search_heatmap_segments = 40
```

## Key Mappings

You might want to add some convenient key mappings to your `~/.vimrc`:

```vim
" Toggle spectral search on/off
nnoremap <leader>st :SpectralSearchToggle<CR>

" Switch to heat map gradient
nnoremap <leader>sh :SpectralSearchGradient heat<CR>

" Switch to rainbow gradient
nnoremap <leader>sr :SpectralSearchGradient rainbow<CR>

" Cycle through intensity levels
nnoremap <leader>si :execute "SpectralSearchIntensity " . 
    \ (g:spectral_search_intensity == 'low' ? 'medium' : 
    \ (g:spectral_search_intensity == 'medium' ? 'high' : 'low'))<CR>
```

## Heatmap Visualization

Spectral Search includes a powerful heatmap visualization that shows the density of matches throughout your file. This feature helps you quickly identify "hot spots" where matches are concentrated.

The heatmap can be displayed in two ways:
1. As a sidebar on the right side of the window
2. As a compact representation in the status line

### Using the Heatmap

Enable/disable the heatmap:
```vim
:SpectralSearchHeatmapToggle
```

Adjust the sidebar width (1-10 characters):
```vim
:SpectralSearchHeatmapWidth 3
```

Change the number of segments (10-100, controls granularity):
```vim
:SpectralSearchHeatmapSegments 50
```

### Heatmap Status Line Integration

When the heatmap is enabled, the status line integration automatically includes a compact visualization using Unicode block characters. The height of each block represents the density of matches in that part of the file.

Example status line configuration with heatmap:
```vim
set statusline+=%{g:SpectralSearchStatusline()}
```

### Heatmap Tips

- The heatmap uses the same color palette as your main search for consistency
- A width of 2-3 characters works well for most terminals
- For large files, consider increasing the segment count for better detail
- Unicode block characters (▁▂▃▄▅▆▇█) show the density in the status line
- You can toggle the heatmap on only when needed for complex searches

Using with incsearch:
- Spectral Search works great with Vim's `incsearch` option, showing the
  gradient highlighting as you type your search pattern

### For standard status line

```vim
set statusline+=\ %{g:SpectralSearchStatusline()}
```

### For lightline.vim

```vim
let g:lightline = {
  \ 'active': {
  \   'right': [ [ 'lineinfo' ],
  \              [ 'percent', 'spectral_search' ],
  \              [ 'fileformat', 'fileencoding', 'filetype' ] ]
  \ },
  \ 'component_function': {
  \   'spectral_search': 'g:SpectralSearchStatusline',
  \ }
  \ }
```

### For vim-airline

```vim
let g:airline_section_z = airline#section#create(['%3p%%', 'linenr', 'maxlinenr', 'colnr', '%{g:SpectralSearchStatusline()}'])
```

## Terminal Compatibility

For the best experience, your terminal should support true colors. Add this to your `~/.vimrc`:

```vim
if has('termguicolors')
  set termguicolors
endif
```

If your terminal doesn't support true colors, Spectral Search will automatically fall back to a limited color palette.

## Troubleshooting

### Colors don't appear or look wrong

- Ensure your terminal supports true colors
- Add `set termguicolors` to your vimrc
- If your terminal doesn't support true colors, the plugin will use a fallback color scheme

### Plugin doesn't work

- Check Vim version with `:version` (must be 9.1+)
- Ensure Vim has `+vim9script`, `+syntax`, and `+extra_search` features
- Run `:SpectralSearchInfo` to check the plugin status

### Performance issues with large files

- Reduce `g:spectral_search_max_matches` to limit the number of highlighted matches
- Use `:SpectralSearchToggle` to temporarily disable the plugin when not needed
- Ensure you're using a specific search pattern to limit matches
- If using heatmap visualization, reduce the segment count with `:SpectralSearchHeatmapSegments 20`

### Heatmap issues

- If the heatmap window displays incorrectly, try closing it (`:SpectralSearchHeatmapToggle`) and reopening
- For rendering issues in the statusline, ensure your terminal supports Unicode block characters
- If colors don't appear correctly, try enabling `termguicolors` or adjust your terminal settings

## License

Released under the Vim license. See `:help license` in Vim or [LICENSE](LICENSE) file.

---

For more detailed information, see the documentation with `:help spectral-search` inside Vim.

