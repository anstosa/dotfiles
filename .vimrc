" Colors & Display
syntax enable
set number
filetype on
filetype plugin on
set nowrap

" Column max if supported
if v:version >= 730
    set colorcolumn=80
endif

" Keybindings
set pastetoggle=<F2>
let mapleader = ","
let g:mapleader = ","
let g:ctrlp_map = '<c-p>'

" tabs
map <leader>tn :tabnew<cr>
map <leader>to :tabonly<cr>
map <leader>tc :tabclose<cr>
map <leader>tm :tabmove 
map <leader>t<leader> :tabnext 

nmap <silent> <A-Up> :wincmd k<CR>
nmap <silent> <A-Down> :wincmd j<CR>
nmap <silent> <A-Left> :wincmd h<CR>
nmap <silent> <A-Right> :wincmd l<CR>

" Indentation
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

" backup
set backup
set backupdir=$HOME/.vim/backups
set directory=$HOME/.vim/swaps

set runtimepath^=~/.local/lib/python2.7/site-packages/powerline/bindings/vim
set runtimepath^=~/.vim/bundle/ctrlp.vim
