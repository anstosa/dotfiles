"NeoBundle Scripts-----------------------------
if has('vim_starting')
  set nocompatible               " Be iMproved
  filetype off          " turn this off for a minute

  " Required:
  set runtimepath+=/home/tgrosinger/.vim/bundle/neobundle.vim/
endif

" Required:
call neobundle#begin(expand('/home/tgrosinger/.vim/bundle'))

" Let NeoBundle manage NeoBundle
" Required:
NeoBundleFetch 'Shougo/neobundle.vim'

" My Bundles here:
NeoBundle 'gmarik/Vundle.vim'
NeoBundle 'tpope/vim-surround'
NeoBundle 'tpope/vim-commentary'
NeoBundle 'tpope/vim-repeat'
NeoBundle 'tacahiroy/ctrlp-funky'
NeoBundle 'terryma/vim-multiple-cursors'
NeoBundle 'Lokaltog/vim-easymotion'
NeoBundle 'nathanaelkane/vim-indent-guides'
NeoBundle 'osyo-manga/vim-over'
NeoBundle 'reedes/vim-litecorrect'
NeoBundle 'reedes/vim-wordy'
NeoBundle 'scrooloose/syntastic'
NeoBundle 'tpope/vim-fugitive'
NeoBundle 'scrooloose/nerdcommenter'
NeoBundle 'godlygeek/tabular'
NeoBundle 'Valloric/YouCompleteMe'
NeoBundle 'sirver/ultisnips'
NeoBundle 'tpope/vim-fugitive'
NeoBundle 'airblade/vim-gitgutter'

" Color Scheme
NeoBundle 'altercation/vim-colors-solarized'

" Tagbar
NeoBundle 'majutsushi/tagbar'
nnoremap <F8> :TagbarToggle<cr> " Toggle the tagbar

" Nerdtree
NeoBundle 'scrooloose/nerdtree'
NeoBundle 'jistr/vim-nerdtree-tabs'
let g:nerdtree_tabs_open_on_console_startup=1
nnoremap <F7> :NERDTreeTabsToggle<cr> " Toggle the NERDTree

" Airline
NeoBundle 'bling/vim-airline'
let g:airline_powerline_fonts = 1
let g:airline#extensions#tabline#enabled = 1 " Tab bar at top
set t_Co=256
if !exists('g:airline_symbols')
      let g:airline_symbols = {}
  endif
  let g:airline_symbols.space = "\ua0"
if has('statusline')
    set laststatus=2
    set statusline=%<%f\                     " Filename
    set statusline+=%w%h%m%r                 " Options
    set statusline+=%{fugitive#statusline()} " Git Hotness
    set statusline+=\ [%{&ff}/%Y]            " Filetype
    set statusline+=\ [%{getcwd()}]          " Current dir
    set statusline+=%=%-14.(%l,%c%V%)\ %p%%  " Right aligned file nav info
endif

" UndoTree
NeoBundle 'mbbill/undotree'
nnoremap <F5> :UndotreeToggle<cr> " Show the undo tree
let g:undotree_SplitWidth = 30

" Golang Support
NeoBundle 'fatih/vim-go'
au FileType go nmap <Leader>gb <Plug>(go-doc)
au FileType go nmap <Leader>gd <Plug>(go-def-tab)

" Python Support
NeoBundle 'klen/python-mode'
au FileType python let g:pymode_doc_bind = "<Leader>gb"
au FileType python let g:pymode_rope_goto_definition_bind = "<Leader>gd"

" Ctrl+P
NeoBundle 'kien/ctrlp.vim'
let g:ctrlp_custom_ignore = '\v[\/]\.(git|hg|svn)$'
set wildignore+=*/tmp/*,*.so,*.swp,*.zip
let g:ctrlp_user_command = {
    \ 'types': {
        \ 1: ['.git', 'cd %s && git ls-files'],
        \ },
    \ 'fallback': 'find %s -type f'
    \ }

" Required:
call neobundle#end()

" Required:
filetype plugin indent on

" If there are uninstalled bundles found on startup,
" this will conveniently prompt you to install them.
NeoBundleCheck
"End NeoBundle Scripts-------------------------

syntax on                 " Turn on syntax highlighting
set spell                 " Turn on spellchecking
set number                " Turn on line numbers
set showmode              " Display the current mode

set history=1000          " Greatly increase the size of the history (from 20)
set iskeyword-=.          " '.' is an end of word designator
set iskeyword-=#          " '#' is an end of word designator
set iskeyword-=-          " '-' is an end of word designator

" Enable Ctrl+hjkl navigation between splits
map <C-J> <C-W>j<C-W>_
map <C-K> <C-W>k<C-W>_
map <C-H> <C-W>h<C-W>_
map <C-L> <C-W>l<C-W>_

let g:clang_user_options='|| exit 0'

cmap w!! w !sudo tee % >/dev/null

" JSON Support
nmap <leader>jt <Esc>:%!python -m json.tool<CR><Esc>:set filetype=json<CR>
let g:vim_json_syntax_conceal = 0

"""
" Git Related Settings
"""

highlight clear SignColumn      " SignColumn should match background
highlight clear LineNr          " Current line number row will have same background color in relative mode

" Instead of reverting the cursor to the last position in the buffer, we
" set it to the first line when editing a git commit message
au FileType gitcommit au! BufEnter COMMIT_EDITMSG call setpos('.', [0, 1, 1, 0])

""
" Look and Feel
"""

set background=dark
set cursorline                  " Highlight the current line
set showmatch                   " Show matching brackets/parenthesis
set hlsearch                    " Highlight search terms

highlight clear SignColumn      " SignColumn should match background
highlight clear LineNr          " Current line number row will have same background color in relative mode
let g:CSApprox_hook_post = ['hi clear SignColumn']
highlight clear CursorLineNr    " Remove highlight color from current line number
set textwidth=80
set colorcolumn=+1

set list                        " Highlight white-space characters
set listchars=tab:›\ ,trail:•,extends:#,nbsp:. " but only the ones we don't want

set pastetoggle=<F6>

if filereadable(expand("~/.vim/bundle/vim-colors-solarized/colors/solarized.vim"))
    let g:solarized_termcolors=256
    let g:solarized_termtrans=1
    let g:solarized_contrast="normal"
    let g:solarized_visibility="normal"
    color solarized
endif
highlight ColorColumn ctermbg=24

" Command line
set wildmenu                    " Show a menu rather than auto-completing

" leader
let mapleader = ","
let g:mapleader = ","

" some shortcuts
:nmap \n :setlocal number!<CR>
:nmap \p :set paste!<CR>

" tabs
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

" backup
set backup
set backupdir=$HOME/.vim/backups
set directory=$HOME/.vim/swaps
set undodir=$HOME/.vim/undo

if has('persistent_undo')
    set undofile                " So is persistent undo ...
    set undolevels=1000         " Maximum number of changes that can be undone
    set undoreload=10000        " Maximum number lines to save for undo on a buffer reload
endif

" indenting
set tabstop=4
set softtabstop=4
set expandtab
set shiftwidth=4
set autoindent
set smartindent

" autocompletion
:inoremap <C-j> <Esc>/[)}"'\]>]<CR>:nohl<CR>a
" Enable omni completion.
autocmd FileType css setlocal omnifunc=csscomplete#CompleteCSS
autocmd FileType html,markdown setlocal omnifunc=htmlcomplete#CompleteTags
autocmd FileType javascript setlocal omnifunc=javascriptcomplete#CompleteJS
autocmd FileType python setlocal omnifunc=pythoncomplete#Complete
autocmd FileType xml setlocal omnifunc=xmlcomplete#CompleteTags
autocmd FileType ruby setlocal omnifunc=rubycomplete#Complete
autocmd FileType haskell setlocal omnifunc=necoghc#omnifunc

" search
set ignorecase
set smartcase
set incsearch

