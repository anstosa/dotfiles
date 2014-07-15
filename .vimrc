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
Plugin 'kien/ctrlp.vim'
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

Plugin 'fatih/vim-go'     " Golang Support
Plugin 'klen/python-mode' " Python Support

call vundle#end()

filetype plugin indent on " okay we can turn it back on
syntax on                 " Turn on syntax highlighting
set spell                 " Turn on spellchecking
set number                " Turn on line numbers
set showmode              " Display the current mode

set history=1000          " Greatly increase the size of the history (from 20)
set mouse=a               " Enable the mouse
set mousehide             " ...but hide it while typing

set iskeyword-=.          " '.' is an end of word designator
set iskeyword-=#          " '#' is an end of word designator
set iskeyword-=-          " '-' is an end of word designator


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
highlight clear SignColumn      " SignColumn should match background
highlight clear LineNr          " Current line number row will have same background color in relative mode
let g:CSApprox_hook_post = ['hi clear SignColumn']
highlight clear CursorLineNr    " Remove highlight color from current line number

if filereadable(expand("~/.vim/bundle/vim-colors-solarized/colors/solarized.vim"))
    let g:solarized_termtrans=1
    let g:solarized_contrast="normal"
    let g:solarized_visibility="normal"
    color solarized
endif


" leader
let mapleader = ","
let g:mapleader = ","

" some shortcuts
:nmap \n :setlocal number!<CR>
:nmap \p :set paste!<CR>

" tabs
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

" search
set ignorecase
set smartcase
set incsearch

