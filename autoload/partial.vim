" partial.vim
" Author: yasunori-kirin0418
" License: MIT

let g:partial#comment_out_symbols = {
  \ 'vim': '"',
  \ 'lua': '--',
  \ }
let g:partial#head_string = ' <% '
let g:partial#tail_string = ' %>'
let g:partial#partial_path_prefix = 'partial_path: '
let g:partial#origin_path_prefix = 'origin_path: '
" open_type(edit, vsplit, split, tabedit)
let g:partial#open_type = 'edit'

" Name: partial#_filetype_surround_pattern
" Description: Generates a pattern of enclosing characters for the part to be a partial file according to the comment out for each language.
" Params: string(filetype)
" Return: dict{head_pattern, tail_pattern}
function! partial#_filetype_surround_pattern(filetype) abort
  return {
        \ 'head_pattern': g:partial#comment_out_symbols[a:filetype] . g:partial#head_string . g:partial#partial_path_prefix,
        \ 'tail_pattern': g:partial#comment_out_symbols[a:filetype] . g:partial#tail_string,
        \ }
endfunction

" Name: partial#_get_range
" Description:  Get the line number of the range you want to partial file.
" Params: string(filetype)
" Return: dict{ origin_path, origin_directory, startline, endline, surround_patterns, filetype }
function! partial#_get_range(filetype) abort
  let surround_patterns = partial#_filetype_surround_pattern(a:filetype)
  let startline = search(surround_patterns.head_pattern, 'bcW')
  let endline = search(surround_patterns.tail_pattern, 'nW')
  let origin_path = fnamemodify(bufname('%'), ':p')
  let origin_directory = fnamemodify(origin_path, ':p:h')

  if startline == 0 || endline == 0
    echohl WarningMsg
    echomsg 'Not found partial tag.'
    echohl None

    return {}
  endif

  return {
        \ 'origin_path': origin_path,
        \ 'origin_directory': origin_directory,
        \ 'startline': startline,
        \ 'endline': endline,
        \ 'surround_patterns': surround_patterns,
        \ 'filetype': a:filetype,
        \ }
endfunction

" Name: partial#_get_file_path
" Description: Extract the file path specified in the startline.
" Params: dict(_get_range)
" Return: string(path)
function! partial#_get_file_path(range) abort
  let head_string = getline(a:range.startline)
  let path_string = substitute(head_string, a:range.surround_patterns.head_pattern, '', '')

  if partial#_is_absolute_path(path_string)
    return path_string
  else

    if g:partial#use_os_type ==# 'posix'
      return a:range.origin_directory . '/' . path_string
    elseif g:partial#use_os_type ==# 'windows'
      return a:range.origin_directory . '\' . path_string
    endif
  endif
endfunction

" Name: partial#_is_absolute_path
" Description: Neovim does not have an isabsolutepath, so prepare it as a helper.
" Params: string(path)
" Return: boolean
function! partial#_is_absolute_path(path) abort
  let posix_absolute_pattern = '/'
  let windows_absolute_pattern = '\u:\'

  if g:partial#use_os_type ==# 'posix'
    return match(a:path, posix_absolute_pattern) == 0
  elseif g:partial#use_os_type ==# 'windows'
    return match(a:path, windows_absolute_pattern) == 0
  endif
endfunction

" Name: partial#_get_line
" Description: Get the string of the partial range as an array.
" Params: dict(_get_range)
" Return: list[...]
function! partial#_get_line(range) abort
  let origin_lines = getline(a:range.startline + 1, a:range.endline - 1)
  let partial_head_string = g:partial#comment_out_symbols[a:range.filetype]
                          \ . g:partial#head_string
                          \ . g:partial#origin_path_prefix
                          \ . a:range.origin_path->substitute(expand(g:partial#home_dir), g:partial#home_dir, '')

  call insert(origin_lines, partial_head_string)
  return origin_lines
endfunction

" Name: partial#open
" Description: Create a file containing the code to be partial and open it in a new buffer.
" Params: string(filetype)
" Return: void
function! partial#open(filetype) abort
  let partial_range = partial#_get_range(a:filetype)
  if empty(partial_range)
    return
  endif
  let partial_file_path = partial#_get_file_path(partial_range)
  let partial_directory = fnamemodify(partial_file_path, ':h')

  if !isdirectory(partial_directory)
    call mkdir(partial_directory)
  endif

  if !filereadable(partial_file_path)
    call partial#_get_line(partial_range)->writefile(partial_file_path, 'b')
  endif

  if g:partial#open_type =~# 'edit\|vsplit\|split\|tabedit'
    execute g:partial#open_type partial_file_path
  else
    echohl WarningMsg
    echomsg 'Wrong g:partial#open_type => ' . g:partial#open_type
    echohl None
  endif
endfunction
