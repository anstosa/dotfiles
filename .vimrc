syntax enable
set background=dark
colorscheme solarized
filetype on
filetype plugin on
set number
set ts=4
set nowrap
set softtabstop=4
set expandtab
set shiftwidth=4
set autoindent
set smartindent
set pastetoggle=<F2>
" search
set ignorecase
set smartcase
set incsearch

" backup
set backup
set backupdir=$HOME/.vim/backups
set directory=$HOME/.vim/swaps

" tabs
map <C-o> :tabnext<CR>
map <C-i> :tabprevious<CR>
map t :tabnew
