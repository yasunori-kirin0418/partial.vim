" partial.vim
" Author: yasunori-kirin0418
" License: MIT


" Initialize option of this plugin.
try
  for item in items(g:partial#comment_out_symbols)
    let g:partial#comment_out_symbols[item[0]] = item[1]
  endfor
catch /Undefined variable:/
  let g:partial#comment_out_symbols = {}
finally
  let g:partial#comment_out_symbols.vim = get(g:partial#comment_out_symbols, 'vim', '"')
  let g:partial#comment_out_symbols.lua = get(g:partial#comment_out_symbols, 'lua', '--')
endtry

let g:partial#head_symbol = get(g:, 'partial#head_symbol', ' <%')
let g:partial#tail_symbol = get(g:, 'partial#tail_symbol', ' %>')
let g:partial#partial_path_prefix = get(g:, 'partial#partial_path_prefix', ' partial_path: ')
let g:partial#origin_path_prefix = get(g:, 'partial#origin_path_prefix', ' origin_path: ')
" open_type(edit, vsplit, split, tabedit)
let g:partial#open_type = get(g:, 'partial#open_type', 'edit')

" Name: partial#create
" Description: Create a partial file with the range taken from the original file.
"              And return of created file name by full path.
" Note: Set the argument to true to create a file.
"       Set to false to get only the file path.
" Params: boolean(create_flag), string(filetype)
" Return: string(file_path)
function! partial#create(create_flag, filetype) abort
  let partial_range = partial#helper#get_range_from_origin(a:filetype)
  if empty(partial_range)
    return
  endif

  let partial_file_path = partial#helper#get_file_path(partial_range)
  if !a:create_flag
    if filereadable(partial_file_path)
      return partial_file_path
    else
      echohl WarningMsg
      echomsg 'Not found partial file.'
      echohl None
      return
    endif
  endif

  if has('linux') || has('mac')
    let home_dir_env = '$HOME'
  elseif has('win64')
    let home_dir_env = '$USERPROFILE'
  endif

  let origin_lines = getline(partial_range.startline, partial_range.endline - 1)
  let partial_tail_string = g:partial#comment_out_symbols[partial_range.filetype]
                        \ . g:partial#tail_symbol
                        \ . g:partial#origin_path_prefix
                        \ . partial_range.origin_path->substitute(expand(home_dir_env), home_dir_env, '')
  call add(origin_lines, partial_tail_string)

  let partial_directory = fnamemodify(partial_file_path, ':h')
  if !isdirectory(partial_directory)
    call mkdir(partial_directory, 'p')
  endif

  call writefile(origin_lines, partial_file_path)
  return partial_file_path
endfunction

" Name: partial#open
" Description: Create a file containing the code to be partial and open it in a new buffer.
"             If the file already exists, open it.
" Note: Set the first argument to true to create a file.
"       Set to false if you just want to open the file.
"       If creating a file that already exists,
"       recreate the partial file with the contents of the original file.
" Params: boolean(create_flag), string(filetype), string(open_type)
" Return: void
function! partial#open(create_flag, filetype, open_type = g:partial#open_type) abort
  let partial_file_path = partial#create(a:create_flag, a:filetype)

  if a:open_type =~# 'edit\|vsplit\|split\|tabedit'
    if !filereadable(partial_file_path)
      echomsg partial_file_path
      return
    endif
    execute a:open_type partial_file_path
  else
    echohl WarningMsg
    echomsg 'Wrong open_type => ' . a:open_type
    echohl None
  endif
endfunction

" Name: partial#update_origin
" Description: Update content from partial file to original file.
" Note: Run with the partial file open.
"       Open file for updated.
" Return: void
function! partial#update_origin() abort
  let surround_patterns = partial#helper#surround_pattern(&filetype)

  let partial_startline = search(surround_patterns.head_pattern, 'bcW')
  let partial_endline = search(surround_patterns.partial_to_origin, 'nW')

  if partial_startline == 0 || partial_endline == 0
    echohl WarningMsg
    echomsg 'This file may not be a partial file.'
    echomsg 'Or surround as a partial file may be broken.'
    echohl None
  endif

  " Inner range excluding surround.
  let partial_lines = getline(partial_startline + 1, partial_endline - 1)
  let origin_head_string = getline(partial_startline)
  let origin_path = getline(partial_endline)
                  \ ->substitute(surround_patterns.partial_to_origin, '', '')
                  \ ->substitute(g:partial#tail_symbol, '', '')
                  \ ->expand()

  if !bufloaded(origin_path)
    call bufadd(origin_path)->bufload()
  endif
  let origin_bufname = bufname(origin_path)
  execute 'buffer' origin_bufname
  let origin_startline = search(origin_head_string, 'cW')
  let origin_endline = search(surround_patterns.tail_pattern, 'nW')

  execute '%foldopen'
  call deletebufline(origin_bufname, origin_startline + 1, origin_endline - 1)
  call append(origin_startline, partial_lines)
endfunction

" Name: partial#surround
" Description: Creates an enclosure for each file type at the cursor position.
" Params: string(filetype)
" Return: void
function! partial#surround(filetype) abort
  let surround_patterns = partial#helper#surround_pattern(a:filetype)
  call append(line('.'), [
                         \ surround_patterns.head_pattern . 'change_here/path/to/partial_file',
                         \ surround_patterns.tail_pattern
                         \ ])
endfunction
