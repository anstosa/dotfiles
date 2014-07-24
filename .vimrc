set nocompatible      " be iMproved
filetype off          " turn this off for a minute

" set the runtime path to include Vundle and initialize
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()

" List of Vundle plugins
Plugin 'gmarik/Vundle.vim'
Plugin 'scrooloose/nerdtree'
Plugin 'altercation/vim-colors-solarized'
Plugin 'tpope/vim-surround'
Plugin 'tpope/vim-commentary'
Plugin 'tpope/vim-repeat'
Plugin 'tacahiroy/ctrlp-funky'
Plugin 'terryma/vim-multiple-cursors'
Plugin 'Lokaltog/powerline'
Plugin 'Lokaltog/vim-easymotion'
Plugin 'jistr/vim-nerdtree-tabs'
Plugin 'mbbill/undotree'
Plugin 'nathanaelkane/vim-indent-guides'
Plugin 'osyo-manga/vim-over'
Plugin 'reedes/vim-litecorrect'
Plugin 'reedes/vim-wordy'
Plugin 'scrooloose/syntastic'
Plugin 'tpope/vim-fugitive'
Plugin 'scrooloose/nerdcommenter'
Plugin 'godlygeek/tabular'
Plugin 'majutsushi/tagbar'
Plugin 'Valloric/YouCompleteMe'
Plugin 'sirver/ultisnips'
Plugin 'myusuf3/numbers.vim'

" Golang Support
Plugin 'fatih/vim-go'
au FileType go nmap <Leader>gb <Plug>(go-doc)
au FileType go nmap <Leader>gd <Plug>(go-def-tab)

" Python Support
Plugin 'klen/python-mode'
au FileType python let g:pymode_doc_bind = "<Leader>gb"
au FileType python let g:pymode_rope_goto_definition_bind = "<Leader>gd"

" JSON Support
nmap <leader>jt <Esc>:%!python -m json.tool<CR><Esc>:set filetype=json<CR>
let g:vim_json_syntax_conceal = 0

" Ctrl+P
Plugin 'kien/ctrlp.vim'
let g:ctrlp_custom_ignore = '\v[\/]\.(git|hg|svn)$'
set wildignore+=*/tmp/*,*.so,*.swp,*.zip
let g:ctrlp_user_command = {
    \ 'types': {
        \ 1: ['.git', 'cd %s && git ls-files'],
        \ },
    \ 'fallback': 'find %s -type f'
    \ }

call vundle#end()

filetype plugin indent on " okay we can turn it back on
syntax on                 " Turn on syntax highlighting
set spell                 " Turn on spellchecking
set number                " Turn on line numbers
set showmode              " Display the current mode

set history=1000          " Greatly increase the size of the history (from 20)
set iskeyword-=.          " '.' is an end of word designator
set iskeyword-=#          " '#' is an end of word designator
set iskeyword-=-          " '-' is an end of word designator

let g:nerdtree_tabs_open_on_console_startup=1

let g:clang_user_options='|| exit 0'

"""
" Git Related Settings
"""

" Instead of reverting the cursor to the last position in the buffer, we
" set it to the first line when editing a git commit message
au FileType gitcommit au! BufEnter COMMIT_EDITMSG call setpos('.', [0, 1, 1, 0])

"""
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

if filereadable(expand("~/.vim/bundle/vim-colors-solarized/colors/solarized.vim"))
    let g:solarized_termtrans=1
    let g:solarized_contrast="normal"
    let g:solarized_visibility="normal"
    color solarized
endif
highlight ColorColumn ctermbg=2

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

