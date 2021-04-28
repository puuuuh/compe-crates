if exists('g:loaded_compecrates') | finish | endif

let s:save_cpo = &cpo
set cpo&vim

if !has('nvim')
    echohl Error
    echom "Sorry this plugin only works with versions of neovim that support lua"
    echohl clear
    finish
endif

lua require'compe'.register_source('crates', require'compe-crates')
lua require'compe-crates':load()

command! CompeCratesUpdate lua require'compe-crates'.force_update()

let g:loaded_compecrates = 1

let &cpo = s:save_cpo
unlet s:save_cpo
