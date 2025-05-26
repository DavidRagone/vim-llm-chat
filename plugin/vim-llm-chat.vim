" LLMChat: A Chat UI for Vim with LLM backend
" Requires simonw/llm CLI installed and available in your $PATH

if exists('g:loaded_llmchat')
  finish
endif
let g:loaded_llmchat = 1

" In-memory chat history (as a List of strings)
let s:llmchat_history = []

" Call the LLM backend with the given prompt, return the response as string

" Ensure the history buffer exists and return its buffer number
function! s:EnsureHistoryBuffer()
  let l:bufname = '__LLMChatHistory__'
  let l:bufnr = bufnr(l:bufname)
  if l:bufnr == -1 || !bufexists(l:bufnr) " Check if buffer exists, bufnr can return a number for non-existent buffer name
    let l:bufnr = bufadd(l:bufname)
    call setbufvar(l:bufnr, '&buftype', 'nofile')
    call setbufvar(l:bufnr, '&bufhidden', 'hide')
    call setbufvar(l:bufnr, '&swapfile', 0)     " Note: Vim uses 0 for false
    call setbufvar(l:bufnr, '&buflisted', 0)    " Explicitly unlist
  endif
  return l:bufnr
endfunction

let s:history_win_id = 0 " Use 0 to indicate no window, as window numbers are > 0
let s:input_win_id = 0   " Use 0 to indicate no window
let s:input_bufnr = -1
let s:is_first_exchange_in_session = 1

" Open the chat windows (history and input)
function! s:OpenChatWindows()
  " Calculate window sizes
  let l:total_height = &lines - &cmdheight - 1 " available height
  let l:history_height = float2nr(l:total_height * 0.8)
  let l:input_height = l:total_height - l:history_height -1 " -1 for status line

  if l:input_height < 2
    let l:input_height = 2
    let l:history_height = l:total_height - l:input_height - 1
  endif

  " Ensure history buffer exists
  let l:history_bufnr = s:EnsureHistoryBuffer()

  " Create history window
  execute l:history_height . 'new'
  let s:history_win_id = winnr() " Get current window NUMBER
  execute 'buffer ' . l:history_bufnr " Associate buffer with this new window
  call setwinvar(s:history_win_id, '&winfixheight', 1)
  call setbufvar(l:history_bufnr, '&readonly', 1)
  call setbufvar(l:history_bufnr, '&wrap', 1)
  call setbufvar(l:history_bufnr, '&list', 0)
  call setbufvar(l:history_bufnr, '&spell', 0)

  " Set keymap for history window
  let l:original_winnr = winnr()
  execute s:history_win_id . "wincmd w" " Focus history window
  execute 'nnoremap <buffer><silent> q :call <SID>CloseChatWindows()<CR>'
  execute l:original_winnr . "wincmd w" " Focus original window

  " Create input window
  execute 'new' " This creates a new window and makes it current
  let s:input_win_id = winnr() " Get current window NUMBER for the new input window
  let s:input_bufname = '__LLMChatInput__' " Name for the input buffer
  let s:input_bufnr = bufnr(s:input_bufname)
  if s:input_bufnr == -1 || !bufexists(s:input_bufnr)
    let s:input_bufnr = bufadd(s:input_bufname)
  endif
  execute 'buffer ' . s:input_bufnr " Associate buffer with the new input window
  call setbufvar(s:input_bufnr, '&buftype', 'nofile')
  call setbufvar(s:input_bufnr, '&bufhidden', 'hide')
  call setbufvar(s:input_bufnr, '&swapfile', 0)
  call setbufvar(s:input_bufnr, '&buflisted', 0)
  call setbufvar(s:input_bufnr, '&modifiable', 1)

  call setwinvar(s:input_win_id, '&winfixheight', 1)
  execute 'resize ' . l:input_height

  " Set buffer-local mappings for <CR> and q in the input window
  let l:original_winnr_for_input_map = winnr()
  execute s:input_win_id . "wincmd w" " Focus input window
  execute 'nnoremap <buffer><silent> <CR> :<C-U>call <SID>SubmitInput()<CR>'
  execute 'inoremap <buffer><silent> <CR> <Esc>:<C-U>call <SID>SubmitInput()<CR>'
  execute 'nnoremap <buffer><silent> q :<C-U>call <SID>CloseChatWindows()<CR>'
  execute l:original_winnr_for_input_map . "wincmd w" " Focus original window

  " Switch focus to input window and start insert mode
  execute s:input_win_id . "wincmd w" " Focus input window
  startinsert
endfunction

" Display g:llmchat_history in the history window
function! s:DisplayHistory()
  let l:history_bufnr = s:EnsureHistoryBuffer()

  " Make buffer modifiable to clear and append lines
  call setbufvar(l:history_bufnr, '&modifiable', 1)

  " Clear the buffer
  call deletebufline(l:history_bufnr, 1, '$')

  " Append history lines
  if exists('g:llmchat_history') && !empty(g:llmchat_history)
    call appendbufline(l:history_bufnr, '$', g:llmchat_history)
  endif

  " Make buffer readonly again and reset modified status
  call setbufvar(l:history_bufnr, '&modifiable', 0)
  call setbufvar(l:history_bufnr, '&modified', 0)

  " Go to the last line in the history window
  if s:history_win_id > 0 && winbufnr(s:history_win_id) > 0 " Check if window number is valid
    let l:original_winnr_hist_scroll = winnr()
    execute s:history_win_id . "wincmd w" " Focus history window
    normal! G
    execute l:original_winnr_hist_scroll . "wincmd w" " Focus original window
  endif
endfunction

" Close the chat windows and clean up
function! s:CloseChatWindows()
  " Close history window
  if s:history_win_id > 0 && winbufnr(s:history_win_id) > 0 " Check if window number is valid
    execute s:history_win_id . 'wincmd c'
  endif
  let s:history_win_id = 0

  " Close input window
  if s:input_win_id > 0 && winbufnr(s:input_win_id) > 0 " Check if window number is valid
    execute s:input_win_id . 'wincmd c'
  endif
  let s:input_win_id = 0

  " Delete the input buffer
  if s:input_bufnr != -1 && bufexists(s:input_bufnr)
    execute 'bwipeout! ' . s:input_bufnr
  endif
  let s:input_bufnr = -1

  " Note: History buffer __LLMChatHistory__ is not wiped out here,
  " so it can persist across sessions if g:llmchat_history is saved/restored.
  " If we wanted to wipe it, we'd need s:EnsureHistoryBuffer to return its name too
  " or find it by name here and wipe it. For now, it's left as is.
endfunction

" Handle user input submission from the input window
function! s:SubmitInput()
  if s:input_bufnr == -1 || !bufexists(s:input_bufnr)
    return
  endif

  let l:input_lines = getbufline(s:input_bufnr, 1, '$')
  let l:userInput = trim(join(l:input_lines, "\n"))

  if !empty(l:userInput)
    call add(s:llmchat_history, 'You: ' . l:userInput)
    " Display the "You:" message immediately
    call s:DisplayHistory() 

    redraw | echo "Waiting for LLM..."
    let l:llm_output = s:AskLLM(l:userInput, !s:is_first_exchange_in_session)
    redraw | echo "" " Clear the waiting message

    if !empty(trim(l:llm_output))
      call add(s:llmchat_history, 'LLM: ' . substitute(l:llm_output, '\n\+$', '', ''))
      " Only set s:is_first_exchange_in_session to 0 if the command was found and executed.
      " The specific error message for "command not found" is checked.
      if stridx(l:llm_output, "Error: llm command not found or not executable:") != 0
        let s:is_first_exchange_in_session = 0
      endif
    else
      " Handle empty response (which might occur if llm command is not found and returns an empty string somehow, though unlikely with current s:AskLLM)
      " If AskLLM returns empty, it implies an issue, so don't toggle s:is_first_exchange_in_session.
    endif

    let g:llmchat_history = s:llmchat_history
    call s:DisplayHistory() " Display the "LLM:" message

    " Clear the input buffer
    call setbufvar(s:input_bufnr, '&modifiable', 1) " Ensure it's modifiable before clearing
    call deletebufline(s:input_bufnr, 1, line('$')) " Clear all lines
    call appendbufline(s:input_bufnr, 0, [''])      " Add a single empty line to start
    " call setbufvar(s:input_bufnr, '&modifiable', 1) " Buffer should remain modifiable
  endif

  " Ensure input window is in insert mode and cursor at line 1, column 1
  if s:input_win_id > 0 && winbufnr(s:input_win_id) > 0 " Vim-compatible check
    call win_execute(s:input_win_id, 'call cursor(1, 1) | startinsert')
  endif
endfunction

function! s:AskLLM(prompt, is_follow_up)
  let l:llm_cmd_base = get(g:, 'llmchat_llm_command', 'llm')

  if !executable(l:llm_cmd_base)
    return "Error: llm command not found or not executable: " . l:llm_cmd_base
  endif

  let l:model_arg = get(g:, 'llmchat_llm_model_arg', '')
  let l:cmd = l:llm_cmd_base

  if a:is_follow_up
    let l:cmd .= ' -c'
  endif

  if !empty(l:model_arg)
    let l:cmd .= ' -m ' . shellescape(l:model_arg)
  endif

  let l:response = system(l:cmd, a:prompt)
  if v:shell_error != 0
    let l:response = "LLM Error: " . l:response
  endif
  return l:response
endfunction

" Main entry point for LLMChat
function! LLMChat()
  let s:is_first_exchange_in_session = 1
  " Use global so user can keep chat between invocations
  if exists('g:llmchat_history')
    let s:llmchat_history = g:llmchat_history
  else
    let s:llmchat_history = []
  endif
  call s:OpenChatWindows()
  call s:DisplayHistory()
endfunction

" Command to start chat
command! LLMChat call LLMChat()
