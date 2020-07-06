---
title: Vim 配置 Golang 开发
date: 2017-11-03 22:11:55
tags: 
    - vim
    - Golang
photos:
    - https://oa7ktymto.qnssl.com/vim-golang.png
---

把 vim 打造成一个 Golang 开发的 IDE 
<!--more-->

### 0x001

首先，我们来看下最终的 VIM 是长下面这个样子的：

![](https://oa7ktymto.qnssl.com/vim-golang.png)

中间的那个框就是我们可以选择的函数列表，通过`tab`可以往下翻。接下来我们需要的是：
- vim 这个当然是必须的啦。版本最好是最新的版本，最好是支持 lua
- [vim-go](https://github.com/fatih/vim-go) 用vim写 golang 必备的插件
- [pathogen.vim](https://github.com/tpope/vim-pathogen) 这个用来处理`runtimepath`
- [ctrlp.vim](https://github.com/kien/ctrlp.vim) 这个是文件搜索工具可以从 buf, mru, files 三个地方作为文件源
- [mru](https://github.com/yegappan/mru) 最近经常编辑的文件列表
- [neocomplete](https://github.com/Shougo/neocomplete.vim) 刚刚我们看到的那个选函数的框就是它
- [netrw.vim](https://github.com/vim-scripts/netrw.vim) 左边的文件选择窗口
- [tagbar](https://github.com/majutsushi/tagbar) 右边的函数==的窗口

### pathogen.vim

安装：

直接下载到`~/.vim/autoload/pathogen.vim`。或者
```
mkdir -p ~/.vim/autoload ~/.vim/bundle && \
curl -LSso ~/.vim/autoload/pathogen.vim https://tpo.pe/pathogen.vim
```
然后在你的`vimrc`里面添加：
```
execute pathogen#infect()
```
这个插件的作用是把`~/.vim/bundle`下面的所有文件夹作为 vim 的`runtimepath(不知道的童鞋自行 Google)`。


### vim-go

安装：

```
git clone https://github.com/fatih/vim-go.git ~/.vim/bundle/vim-go
```

对，你没有看错这样就已经安装完`vim-go`了。 只是它还会去安装一些第三方的东西比如：godef 等等


## 2019-04-12 UPDATE 

### 源码编译 VIM8 (with-python3)
1. 下载最新的源码，`git clone git@github.com:vim/vim.git`
2. cd vim/src
3. `./configure --enable-multibyte --enable-perlinterp=dynamic --enable-rubyinterp=dynamic --with-ruby-command=/usr/local/bin/ruby --enable-python3interp --enable-cscope --enable-gui=auto --with-features=huge --with-x --enable-fontset --enable-largefile --disable-netbeans --with-compiledby="yourname" --enable-fail-if-missing`
4. make && make install

### 需要的插件
- [pathogen.vim](https://github.com/tpope/vim-pathogen/blob/master/autoload/pathogen.vim) (直接放在 `~/.vim/autoload` 目录里面)
- [ctrlp.vim (Fuzzy file, buffer, mru, tag, etc finder)](https://github.com/kien/ctrlp.vim) (git clone 放在 `~/.vim/bundle` 目录)
- [deoplete-go (自动补全)](https://github.com/deoplete-plugins/deoplete-go) (git clone 放在 `~/.vim/bundle` 目录)
- [deoplete.nvim (自动补全)](https://github.com/Shougo/deoplete.nvim) (git clone 放在 `~/.vim/bundle` 目录)
- [mru (Most Recently Used (MRU) files)](https://github.com/vim-scripts/mru.vim) (git clone 放在 `~/.vim/bundle` 目录)
- [netrw.vim](https://github.com/vim-scripts/netrw.vim) (git clone 放在 `~/.vim/bundle` 目录)
- [nvim-yarp](https://github.com/roxma/nvim-yarp) (git clone 放在 `~/.vim/bundle` 目录)
- [tagbar](https://github.com/majutsushi/tagbar) (git clone 放在 `~/.vim/bundle` 目录) 
- [vim-gitgutter](https://github.com/airblade/vim-gitgutter) (git clone 放在 `~/.vim/bundle` 目录)
- [vim-go](https://github.com/fatih/vim-go) (git clone 放在 `~/.vim/bundle` 目录)
- [vim-godef](https://github.com/dgryski/vim-godef) (git clone 放在 `~/.vim/bundle` 目录)
- [vim-hug-neovim-rpc](https://github.com/roxma/vim-hug-neovim-rpc) (git clone 放在 `~/.vim/bundle` 目录)

### 出现以下 ERROR 解决办法
>ERROR: [vim-hug-neovim-rpc] Vim(pythonx):Traceback (most recent call last):
>ERROR: [vim-hug-neovim-rpc] Vim(pythonx):/must>not&exist/foo:1: DeprecationWarning: the imp module is deprecated in favour of importlib; see the module's documentation for alternative uses

命令行执行 `pip3 install --user --no-binary :all: pynvim`

## 2020-04-13 UPDATE

### 下载最新的 vim8

### 需要的插件 plug.vim

### 抄以下的 .vimrc
```
call plug#begin('~/.vim/plugged')
Plug 'fatih/vim-go'
Plug 'neoclide/coc.nvim', {'do': 'yarn install --frozen-lockfile'}
Plug 'kien/ctrlp.vim'
Plug 'vim-scripts/mru.vim'
Plug 'vim-scripts/netrw.vim'
Plug 'airblade/vim-gitgutter'
Plug 'jalvesaq/Nvim-R'
call plug#end()

set shell=/bin/sh
set autoread
" Personal setting
" =======================================  start  =======================================
" With a map leader it's possible to do extra key combinations
let mapleader = ","
let g:mapleader = ","
se cursorline
set foldcolumn=1

" disable vim-go goto definition
let g:go_def_mapping_enabled = 0

" golang highlight
let g:go_fold_enable = ['block', 'import', 'varconst', 'package_comment']
let g:go_highlight_functions = 1
let g:go_highlight_operators = 1
let g:go_highlight_function_calls = 1


" coc.vim default config
" =================================================
" Use tab for trigger completion with characters ahead and navigate.
" Use command ':verbose imap <tab>' to make sure tab is not mapped by other plugin.
inoremap <silent><expr> <TAB>
      \ pumvisible() ? "\<C-n>" :
      \ <SID>check_back_space() ? "\<TAB>" :
      \ coc#refresh()
inoremap <expr><S-TAB> pumvisible() ? "\<C-p>" : "\<C-h>"

function! s:check_back_space() abort
  let col = col('.') - 1
  return !col || getline('.')[col - 1]  =~# '\s'
endfunction

" Use <c-space> to trigger completion.
inoremap <silent><expr> <c-space> coc#refresh()

" Use `[c` and `]c` to navigate diagnostics
nmap <silent> [c <Plug>(coc-diagnostic-prev)
nmap <silent> ]c <Plug>(coc-diagnostic-next)
" Remap keys for gotos
nmap <silent> <c-]> <Plug>(coc-definition)
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gr <Plug>(coc-references)
" Use U to show documentation in preview window
nnoremap <silent> U :call <SID>show_documentation()<CR>

" Remap for rename current word
nmap <leader>rn <Plug>(coc-rename)

" Remap for format selected region
vmap <leader>f  <Plug>(coc-format-selected)
nmap <leader>f  <Plug>(coc-format-selected)
" Show all diagnostics
nnoremap <silent> <leader>a  :<C-u>CocList diagnostics<cr>
" Manage extensions
nnoremap <silent> <leader>e  :<C-u>CocList extensions<cr>
" Show commands
nnoremap <silent> <leader>c  :<C-u>CocList commands<cr>
" Find symbol of current document
nnoremap <silent> <leader>o  :<C-u>CocList outline<cr>
" Search workspace symbols
nnoremap <silent> <leader>s  :<C-u>CocList -I symbols<cr>
" Do default action for next item.
nnoremap <silent> <leader>j  :<C-u>CocNext<CR>
" Do default action for previous item.
nnoremap <silent> <leader>k  :<C-u>CocPrev<CR>
" Resume latest coc list
nnoremap <silent> <leader>p  :<C-u>CocListResume<CR>
"====================================================
" gi go install
nmap gi <ESC>:GoInstall<CR>

" line numbers
set relativenumber
set nu

" Enable filetype plugins
"
syntax on
filetype on
filetype plugin on
filetype indent on

imap sw <ESC>:w<CR>
nmap sw <ESC>:w<CR>
noremap qq <ESC>:q!<CR>
imap jj <ESC>
nmap 1t 1gt
nmap 2t 2gt
nmap 3t 3gt
nmap 4t 4gt
nmap 5t 5gt
colorscheme desert

"Always show current position
set ruler

" A buffer becomes hidden when it is abandoned
set hid

" Set 7 lines to the cursor - when moving vertically using j/k
set so=7

" Use spaces instead of tabs
set expandtab

" Be smart when using tabs ;)
set smarttab

" 1 tab == 4 spaces
set shiftwidth=4
set tabstop=4

" Height of the command bar
set cmdheight=2

" Highlight search results
set hlsearch

" Makes search act like search in modern browsers
set incsearch

" Don't redraw while executing macros (good performance config)
set lazyredraw

" For regular expressions turn magic on
set magic

" Show matching brackets when text indicator is over them
set showmatch

" backspace acts as it should act
set backspace=eol,start,indent
set whichwrap+=<,>,h,l

" Returns true if paste mode is enabled
function! HasPaste()
    if &paste
        return 'PASTE MODE  '
    en
    return ''
endfunction

" Always show the status line
set laststatus=2

" Format the status line
set statusline=\ %{HasPaste()}%F%m%r%h\ %w\ \ CWD:\ %r%{getcwd()}%h\ \ \ Line:\ %l\ \ \ Column:\ %c,

" move between windows
nmap <C-j> <C-W>j
nmap <C-k> <C-W>k
nmap <C-h> <C-W>h
nmap <C-l> <C-W>l


" tabline
if has('gui')
  set guioptions-=e
endif
if exists("+showtabline")
  function MyTabLine()
    let s = ''
    let t = tabpagenr()
    let i = 1
    while i <= tabpagenr('$')
      let buflist = tabpagebuflist(i)
      let winnr = tabpagewinnr(i)
      let s .= '%' . i . 'T'
      let s .= (i == t ? '%1*' : '%2*')
      let s .= ' '
      let s .= i . ':'
      let s .= winnr . '/' . tabpagewinnr(i,'$')
      let s .= ' %*'
      let s .= (i == t ? '%#TabLineSel#' : '%#TabLine#')
      let bufnr = buflist[winnr - 1]
      let file = bufname(bufnr)
      let buftype = getbufvar(bufnr, 'buftype')
      if buftype == 'nofile'
        if file =~ '\/.'
          let file = substitute(file, '.*\/\ze.', '', '')
        endif
      else
        let file = fnamemodify(file, ':p:t')
      endif
      if file == ''
        let file = '[No Name]'
      endif
      let s .= file
      let i = i + 1
    endwhile
    let s .= '%T%#TabLineFill#%='
    let s .= (tabpagenr('$') > 1 ? '%999XX' : 'X')
    return s
  endfunction
  set stal=2
  set tabline=%!MyTabLine()
  map    <C-Tab>    :tabnext<CR>
  imap   <C-Tab>    <C-O>:tabnext<CR>
  map    <C-S-Tab>  :tabprev<CR>
  imap   <C-S-Tab>  <C-O>:tabprev<CR>
endif

" Remap VIM 0 to first non-blank character
map 0 ^

" Linebreak on 500 characters
set lbr
set tw=500

set ai "Auto indent
set si "Smart indent
set wrap "Wrap lines

" Map <Space> to / (search) and Ctrl-<Space> to ? (backwards search)
map <space> /
map <c-space> ?

" Super useful when editing files in the same directory
map <leader>te :tabedit <c-r>=expand("%:p:h")<cr>/

" Switch CWD to the directory of the open buffer
map <leader>cd :cd %:p:h<cr>:pwd<cr>

" Set utf8 as standard encoding and en_US as the standard language
set encoding=utf8

" Use Unix as the standard file type
set ffs=unix,dos,mac

" Turn backup off, since most stuff is in SVN, git et.c anyway...
set nobackup
set nowb
set noswapfile

" Remap VIM 0 to first non-blank character
map 0 ^

" Move a line of text using ALT+[jk] or Comamnd+[jk] on mac
nmap <M-j> mz:m+<cr>`z
nmap <M-k> mz:m-2<cr>`z
vmap <M-j> :m'>+<cr>`<my`>mzgv`yo`z
vmap <M-k> :m'<-2<cr>`>my`<mzgv`yo`z

if has("mac") || has("macunix")
  nmap <D-j> <M-j>
  nmap <D-k> <M-k>
  vmap <D-j> <M-j>
  vmap <D-k> <M-k>
endif

" close tab
nmap cw <ESC>:tabc<CR>

" Return to last edit position when opening files (You want this!)
autocmd BufReadPost *
     \ if line("'\"") > 0 && line("'\"") <= line("$") |
     \   exe "normal! g`\"" |
     \ endif

" Set extra options when running in GUI mode
if has("gui_running")
    set guioptions-=T
    set guioptions-=e
    set t_Co=256
    set guitablabel=%M\ %t
endif

" ================================ end ================================

" netrw config
"
set nocp
nnoremap <Leader><Leader> :Tlist<CR><C-W>h<C-W>s:e .<CR><C-W>l:let g:netrw_chgwin=winnr()<CR><C-W>h
let g:netrw_browse_split = 4
let g:netrw_altv = 1
let g:netrw_winsize = 55
let g:netrw_liststyle=0         " thin (change to 3 for tree)
let g:netrw_banner=0            " no banner
let g:netrw_altv=1              " open files on right
let g:netrw_preview=1           " open previews vertically

augroup ProjectDrawer
  autocmd!
  autocmd VimEnter * :Vexplore
augroup END

" gopls mode
" let g:go_def_mode='gopls'
" let g:go_info_mode='gopls'

" CTRL-P
let g:ctrlp_working_path_mode = 0
let g:ctrlp_map = '<c-f>'
map <leader>j :CtrlP<cr>
map <c-b> :CtrlPBuffer<cr>
let g:ctrlp_max_height = 20
let g:ctrlp_custom_ignore = 'node_modules\|^\.DS_Store\|^\.git\|^\.coffee'

" golint
" set rtp+=/Users/wentx/momaek/src/golang.org/x/lint/misc/vim
" autocmd BufWritePost,FileWritePost *.go execute 'Lint' | cwindow
```
