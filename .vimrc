" NeoBundle ====================================================================
if has('vim_starting')
    set nocompatible
    filetype off
    set runtimepath+=/home/ansel/.vim/bundle/neobundle.vim/
endif
call neobundle#begin(expand('/home/ansel/.vim/bundle'))

" Let NeoBundle manage NeoBundle
NeoBundleFetch 'Shougo/neobundle.vim'

" vim Go -----------------------------------------------------------------------
NeoBundle 'fatih/vim-go'
let g:go_fmt_command = "goimports"

" Bundles ----------------------------------------------------------------------
NeoBundle 'jelera/vim-javascript-syntax'
NeoBundle 'mattn/emmet-vim'
NeoBundle 'osyo-manga/vim-over'
NeoBundle 'scrooloose/nerdcommenter'
NeoBundle 'tpope/vim-surround'
NeoBundle 'Raimondi/delimitMate'
NeoBundle 'digitaltoad/vim-jade'
NeoBundle 'scrooloose/syntastic'

" EasyMotion -------------------------------------------------------------------
NeoBundle 'Lokaltog/vim-easymotion'
let g:EasyMotion_smartcase = 1
nmap s <Plug>(easymotion-s2)
map <Leader>l <Plug>(easymotion-lineforward)
map <Leader>j <Plug>(easymotion-j)
map <Leader>k <Plug>(easymotion-k)
map <Leader>h <Plug>(easymotion-linebackward)

" vim tmux navigator -----------------------------------------------------------
NeoBundle 'christoomey/vim-tmux-navigator'
nnoremap <silent> <C-Left> :TmuxNavigateLeft<cr>
nnoremap <silent> <C-Down> :TmuxNavigateDown<cr>
nnoremap <silent> <C-Up> :TmuxNavigateUp<cr>
nnoremap <silent> <C-Right> :TmuxNavigateRight<cr>
nnoremap <silent> <C-~> :TmuxNavigatePrevious<cr>

" vim Fugitive -----------------------------------------------------------------
NeoBundle 'tpope/vim-fugitive'
nnoremap <silent> <leader>gs :Gstatus<CR>
nnoremap <silent> <leader>gd :Gdiff<CR>
nnoremap <silent> <leader>gc :Gcommit<CR>
nnoremap <silent> <leader>gb :Gblame<CR>
nnoremap <silent> <leader>gl :Glog<CR>
NeoBundle 'idanarye/vim-merginal'
map <C-g> :MerginalToggle<CR>

" Solarized --------------------------------------------------------------------
NeoBundle 'altercation/vim-colors-solarized'
let g:solarized_termtrans=1
let g:solarized_contrast="normal"
let g:solarized_visibility="normal"
set t_Co=16
set background=dark
colorscheme solarized
highlight IncSearch ctermbg=5 ctermfg=8 cterm=none

" Ctrlp ------------------------------------------------------------------------
NeoBundle 'kien/ctrlp.vim'
NeoBundle 'tacahiroy/ctrlp-funky'
let g:ctrlp_map = '<c-p>'
let g:ctrlp_user_command = {
    \ 'types': {
    \ 1: ['.git', 'cd %s && git ls-files . --cached --exclude-standard --others'],
        \ },
    \ 'fallback': 'find %s -type f'
    \ }
set runtimepath^=~/.vim/bundle/ctrlp.vim
let g:ctrlp_extensions = ['funky']
nnoremap <Leader>fu :CtrlPFunky<Cr>
nnoremap U <c-r>
noremap <c-r> :CtrlPFunky<Cr>
noremap <c-u> :CtrlPBuffer<Cr>

" NERDTree ---------------------------------------------------------------------
NeoBundle 'scrooloose/nerdtree'
NeoBundle 'jistr/vim-nerdtree-tabs'
"autocmd vimenter * NERDTree
map <C-e> <plug>NERDTreeTabsToggle<CR>
map <leader>e :NERDTreeFind<CR>
nmap <leader>nt :NERDTreeFind<CR>
let NERDTreeShowBookmarks=1
let NERDTreeIgnore=['\.pyc', '\~$', '\.swo$', '\.swp$', '\.git', '\.hg', '\.svn', '\.bzr', 'node_modules']
let NERDTreeChDirMode=0
let NERDTreeMouseMode=2
let NERDTreeShowHidden=1
let NERDTreeKeepTreeInNewTab=1
let g:nerdtree_tabs_open_on_gui_startup=0

" Airline ----------------------------------------------------------------------
NeoBundle 'bling/vim-airline'
set showmode
let g:airline_powerline_fonts = 1
let g:airline#extensions#tabline#enabled = 1
if has('statusline')
    set laststatus=2
    set statusline=%<%f\                     " Filename
    set statusline+=%w%h%m%r                 " Options
    set statusline+=%{fugitive#statusline()} " Git Hotness
    set statusline+=\ [%{&ff}/%Y]            " Filetype
    set statusline+=\ [%{getcwd()}]          " Current dir
    set statusline+=%=%-14.(%l,%c%V%)\ %p%%  " Right aligned file nav info
endif

" GitGutter --------------------------------------------------------------------
NeoBundle 'airblade/vim-gitgutter'
highlight clear SignColumn
let g:CSApprox_hook_post = ['hi clear SignColumn']

" NeoComplete ------------------------------------------------------------------
if has('lua')
    NeoBundle 'Shougo/neocomplete.vim'
    let g:acp_enableAtStartup = 0
    let g:neocomplete#enable_at_startup = 1
    let g:neocomplete#enable_smart_case = 1
    let g:neocomplete#sources#syntax#min_keyword_length = 3
    let g:neocomplete#lock_buffer_name_pattern = '\*ku\*'
    let g:neocomplete#sources#dictionary#dictionaries = {
        \ 'default' : '',
        \ 'vimshell' : $HOME.'/.vimshell_hist',
        \ 'scheme' : $HOME.'/.gosh_completions'
            \ }
    if !exists('g:neocomplete#keyword_patterns')
        let g:neocomplete#keyword_patterns = {}
    endif
    let g:neocomplete#keyword_patterns['default'] = '\h\w*'
    inoremap <expr><C-g>   neocomplete#undo_completion()
    inoremap <expr><C-l>   neocomplete#complete_common_string()
    inoremap <expr><TAB>   pumvisible() ? "\<C-n>" : "\<TAB>"
    inoremap <expr><C-h>   neocomplete#smart_close_popup()."\<C-h>"
    inoremap <expr><BS>    neocomplete#smart_close_popup()."\<C-h>"
    inoremap <expr><C-y>   neocomplete#close_popup()
    inoremap <expr><C-e>   neocomplete#cancel_popup()
    inoremap <expr><Left>  neocomplete#close_popup() . "\<Left>"
    inoremap <expr><Right> neocomplete#close_popup() . "\<Right>"
    inoremap <expr><Up>    neocomplete#close_popup() . "\<Up>"
    inoremap <expr><Down>  neocomplete#close_popup() . "\<Down>"
    autocmd FileType css setlocal omnifunc=csscomplete#CompleteCSS
    autocmd FileType html,markdown setlocal omnifunc=htmlcomplete#CompleteTags
    autocmd FileType javascript setlocal omnifunc=javascriptcomplete#CompleteJS
    autocmd FileType python setlocal omnifunc=pythoncomplete#Complete
    autocmd FileType xml setlocal omnifunc=xmlcomplete#CompleteTags
    let g:neocomplete#sources#omni#input_patterns = {}
endif

call neobundle#end()
filetype plugin indent on
NeoBundleCheck


" Appearance ===================================================================
scriptencoding utf-8
set shortmess+=filmnrxoOtT          " Abbrev. of messages (avoids 'hit enter')
set hidden                          " Allow buffer switching without saving
set showmatch
set winminheight=0
set spell
syntax on


" Appearance ===================================================================
set number
set nowrap
set cursorline
highlight CursorLine cterm=none ctermbg=8
au BufNewFile,BufRead *.mxml set filetype=javascript
au BufNewFile,BufRead *.as set filetype=javascript
set list
set listchars=tab:›\ ,trail:•,extends:#,nbsp:.


" Max Columns ==================================================================
set fo-=t
set colorcolumn=81
highlight ColorColumn ctermbg=8


" Cursor =======================================================================
set iskeyword-=.                    " '.' is an end of word designator
set iskeyword-=#                    " '#' is an end of word designator
set iskeyword-=-                    " '-' is an end of word designator
set iskeyword-=_                    " '-' is an end of word designator
set virtualedit=onemore             " Allow for cursor beyond last character
" Restore cursor to file position in previous editing session
function! ResCur()
    if line("'\"") <= line("$")
        normal! g`"
        return 1
    endif
endfunction
augroup resCur
    autocmd!
    autocmd BufWinEnter * call ResCur()
augroup END


" Autocomplete =================================================================
set wildmenu
set wildmode=list:longest,full


" Mouse ========================================================================
"set mouse=a
"set mousehide


" Keybindings ==================================================================
let mapleader = ','
set backspace=indent,eol,start
set whichwrap=b,s,h,l,<,>,[,]
set scrolljump=5
set scrolloff=3
nmap <silent> <leader>d :bp\|bd #<CR>
cmap w!! w !sudo tee % >/dev/null
nmap cp :let @+ = expand("%:p")<CR>


" Tabs =========================================================================
noremap <leader>1 1gt
noremap <leader>2 2gt
noremap <leader>3 3gt
noremap <leader>4 4gt
noremap <leader>5 5gt
noremap <leader>6 6gt
noremap <leader>7 7gt
noremap <leader>8 8gt
noremap <leader>9 9gt
noremap <leader>0 :tablast<cr>
map <leader>tn :tabnew<cr>
map <leader>to :tabonly<cr>
map <leader>tc :tabclose<cr>
map <leader>tm :tabmove
map <leader>tt :tabnext<cr>


" Splits =======================================================================
set splitright
set splitbelow


" Whitespace ===================================================================
autocmd BufNewFile,BufRead * :highlight BadForm ctermbg=11 ctermfg=8
autocmd BufNewFile,BufRead * :match BadForm /\s\+$/
set tabstop=4
set softtabstop=4
set expandtab
set shiftwidth=4
set autoindent
set smartindent
set linespace=0
set nojoinspaces
vnoremap < <gv
vnoremap > >gv
vnoremap . :normal .<CR>


" Search =======================================================================
set ignorecase
set smartcase
set incsearch
"set hlsearch


" Metadata =====================================================================
set backup
set history=1000
set backupdir=$HOME/.vim/backups
set directory=$HOME/.vim/swaps
set undodir=$HOME/.vim/undo
if has('persistent_undo')
    set undofile
    set undolevels=1000
    set undoreload=10000
endif
" Always switch to the current file directory
autocmd BufEnter * if bufname("") !~ "^\[A-Za-z0-9\]*://" | lcd %:p:h | endif


" Git ==========================================================================
" Instead of reverting the cursor to the last position in the buffer, we
" set it to the first line when editing a git commit message
au FileType gitcommit au! BufEnter COMMIT_EDITMSG call setpos('.', [0, 1, 1, 0])
map <leader>fc /\v^[<\|=>]{7}( .*\|$)<CR>


" Wipeout ======================================================================
function! Wipeout()
    " list of *all* buffer numbers
    let l:buffers = range(1, bufnr('$'))

    " what tab page are we in?
    let l:currentTab = tabpagenr()
    try
        " go through all tab pages
        let l:tab = 0
        while l:tab < tabpagenr('$')
            let l:tab += 1

            " go through all windows
            let l:win = 0
            while l:win < winnr('$')
                let l:win += 1
                " whatever buffer is in this window in this tab, remove it from
                " l:buffers list
                let l:thisbuf = winbufnr(l:win)
                call remove(l:buffers, index(l:buffers, l:thisbuf))
            endwhile
        endwhile

        " if there are any buffers left, delete them
        if len(l:buffers)
            execute 'bwipeout' join(l:buffers)
        endif
    finally
        " go back to our original tab page
        execute 'tabnext' l:currentTab
    endtry
endfunction
