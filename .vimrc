let mapleader = ','

" Bundle =======================================================================
if empty(glob('~/.vim/autoload/plug.vim'))
    silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs
        \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
    autocmd VimEnter * PlugInstall | source $MYVIMRC
endif

call plug#begin('~/.vim/plugged')

Plug 'pangloss/vim-javascript', { 'for': 'javascript' }
Plug 'mattn/emmet-vim',         { 'for': ['html', 'javascript', 'css']}
Plug 'tpope/vim-commentary'
Plug 'tpope/vim-surround'
Plug 'godlygeek/tabular'
Plug 'Raimondi/delimitMate'
Plug 'digitaltoad/vim-jade',    { 'for': 'jade' }
Plug 'scrooloose/syntastic'
Plug 'blueyed/vim-diminactive'
Plug 'Shougo/vimproc.vim',      { 'do': 'make' }

Plug 'simnalamburt/vim-mundo'
nnoremap <leader>u :GundoToggle<CR>

Plug 'elzr/vim-json'
let g:vim_json_syntax_conceal = 0

Plug 'fatih/vim-go',            { 'for': 'go' }
let g:go_fmt_command = "goimports"

Plug 'christoomey/vim-tmux-navigator'
nnoremap <silent> <C-Left>  :TmuxNavigateLeft<cr>
nnoremap <silent> <C-Down>  :TmuxNavigateDown<cr>
nnoremap <silent> <C-Up>    :TmuxNavigateUp<cr>
nnoremap <silent> <C-Right> :TmuxNavigateRight<cr>
nnoremap <silent> <C-~>     :TmuxNavigatePrevious<cr>

Plug 'tpope/vim-fugitive'
nnoremap <silent> <leader>gs :Gstatus<CR>
nnoremap <silent> <leader>gd :Gdiff<CR>
nnoremap <silent> <leader>gc :Gcommit<CR>
nnoremap <silent> <leader>gb :Gblame<CR>
nnoremap <silent> <leader>gl :Glog<CR>

Plug 'altercation/vim-colors-solarized'
let g:solarized_termtrans=1
let g:solarized_contrast="normal"
let g:solarized_visibility="normal"
set t_Co=16
set background=dark
colorscheme solarized
highlight IncSearch ctermbg=5 ctermfg=8 cterm=none

Plug 'kien/ctrlp.vim'
Plug 'tacahiroy/ctrlp-funky'
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
noremap  <c-r>      :CtrlPFunky<Cr>
noremap  <c-u>      :CtrlPBuffer<Cr>

Plug 'scrooloose/nerdtree',     { 'on':  'NERDTreeTabsToggle' }
Plug 'jistr/vim-nerdtree-tabs', { 'on':  'NERDTreeTabsToggle' }
map  <C-e>      :NERDTreeTabsToggle<CR>
map  <leader>e  :NERDTreeFind<CR>
nmap <leader>nt :NERDTreeFind<CR>
let NERDTreeShowBookmarks=1
let NERDTreeIgnore=['\.pyc', '\~$', '\.swo$', '\.swp$', '\.git', '\.hg', '\.svn', '\.bzr', 'node_modules']
let NERDTreeChDirMode=0
let NERDTreeMouseMode=2
let NERDTreeShowHidden=1
let NERDTreeKeepTreeInNewTab=1
let g:nerdtree_tabs_open_on_gui_startup=0

Plug 'bling/vim-airline'
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

Plug 'airblade/vim-gitgutter'
highlight clear SignColumn
let g:CSApprox_hook_post = ['hi clear SignColumn']
let g:gitgutter_max_signs = 1000

Plug 'Valloric/YouCompleteMe', { 'do': './install.py' }
let g:ycm_complete_in_strings = 0
let g:ycm_seed_identifiers_with_syntax = 1

call plug#end()
filetype plugin indent on


" Appearance ===================================================================
scriptencoding utf-8
syntax on
set shortmess+=filmnrxoOtT          " Abbrev. of messages (avoids 'hit enter')
set hidden                          " Allow buffer switching without saving
set showmatch                       " Highlight matches on search
set winminheight=0                  " Allow windows to collapse entirely
set spell                           " Enable spellcheck
set number                          " Enable line numbers
set nowrap                          " Don't wrap long lines
set lazyredraw                      " Speed up display
" Highlight the current line
set cursorline
highlight CursorLine cterm=none ctermbg=8
" Show whitespace
set list
set listchars=tab:›\ ,trail:•,extends:#,nbsp:.
autocmd BufNewFile,BufRead * :highlight BadForm ctermbg=11 ctermfg=8
autocmd BufNewFile,BufRead * :match BadForm /\s\+$/
" Highlight flex files like Javascript
au BufNewFile,BufRead *.mxml set filetype=javascript
au BufNewFile,BufRead *.as set filetype=javascript
" Highlight 80th collumn
set fo-=t
set colorcolumn=81
highlight ColorColumn ctermbg=0


" Folding ======================================================================
set foldenable
set foldlevelstart=10
set foldnestmax=10
set foldmethod=syntax


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


" Keybindings ==================================================================
set backspace=indent,eol,start
set whichwrap=b,s,h,l,<,>,[,]
set scrolljump=5
set scrolloff=3
nmap <silent> <leader>d :bp\|bd #<CR>
cmap w!! w !sudo tee % >/dev/null
nmap cp :let @+ = expand("%:p")<CR>
nnoremap gp `[v`]


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
set splitright                          " Open new splits to right of current
set splitbelow                          " Open new splits below current


" Whitespace ===================================================================
" 4 space tabs
set tabstop=4
set softtabstop=4
set shiftwidth=4
set expandtab
set autoindent                          " Indent on paste
set smartindent                         " Indent intelligently
set nojoinspaces                        " Collapse spaces after sentences
" Don't exit visual mode when indenting
vnoremap < <gv
vnoremap > >gv


" Search =======================================================================
set ignorecase
set smartcase
set incsearch
set hlsearch
" Remove search highlights on Esc
nnoremap <silent> <esc> :noh<cr><esc>


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
