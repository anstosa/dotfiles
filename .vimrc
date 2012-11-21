syntax on
filetype on
filetype plugin on  
set number

set background=dark
colorscheme solarized

" leader
let mapleader = ","
let g:mapleader = ","

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

" plugins
set runtimepath^=~/.vim/bundle/ctrlp.vim
