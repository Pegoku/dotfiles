
" --- core ---
set nocompatible
set encoding=utf-8
set hidden
set backspace=indent,eol,start
set updatetime=300
set shortmess+=c

" --- UI ---
set number
set relativenumber
set ruler
set showcmd
set cursorline
set signcolumn=yes
set splitright
set splitbelow
set mouse=a
set wildmenu
set wildmode=longest:full,full
set background=dark
colorscheme default

" --- indent ---
set tabstop=4
set shiftwidth=4
set softtabstop=4
set expandtab
set smartindent

" --- search ---
set ignorecase
set smartcase
set incsearch
set hlsearch

" --- undo/backup (only if dirs exist) ---
if isdirectory(expand('~/.vim/undo'))
  set undofile
  set undodir=~/.vim/undo//
endif
if isdirectory(expand('~/.vim/swap'))
  set directory=~/.vim/swap//
endif
if isdirectory(expand('~/.vim/backup'))
  set backup
  set backupdir=~/.vim/backup//
endif

" --- plugins (Vundle) ---
if isdirectory(expand('~/.vim/bundle/Vundle.vim'))
  filetype off
  set rtp+=~/.vim/bundle/Vundle.vim
  call vundle#begin()
  Plugin 'VundleVim/Vundle.vim'
  Plugin 'tpope/vim-fugitive'
  Plugin 'rstacruz/sparkup', {'rtp': 'vim/'}
  Plugin 'SirVer/ultisnips'
  Plugin 'honza/vim-snippets'
  call vundle#end()
endif

syntax on
filetype plugin indent on

" --- UltiSnips ---
let g:UltiSnipsExpandTrigger = "<tab>"
let g:UltiSnipsJumpForwardTrigger = "<c-b>"
let g:UltiSnipsJumpBackwardTrigger = "<c-z>"
let g:UltiSnipsEditSplit = "vertical"

" --- clipboard (Wayland / wl-clipboard) ---
if has('clipboard')
  set clipboard=unnamedplus
endif
