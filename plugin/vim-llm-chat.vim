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
  let l:bufnr = bufnr('__LLMChatHistory__')
  if l:bufnr == -1
    let l:bufnr = nvim_create_buf(v:false, v:true) " buflisted=false, scratch=true
    call nvim_buf_set_name(l:bufnr, '__LLMChatHistory__')
    call setbufvar(l:bufnr, '&buftype', 'nofile')
    call setbufvar(l:bufnr, '&bufhidden', 'hide')
    call setbufvar(l:bufnr, '&swapfile', v:false)
  endif
  return l:bufnr
endfunction

let s:history_win_id = -1
let s:input_win_id = -1
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
  let s:history_win_id = win_getid()
  call win_execute(s:history_win_id, 'buffer ' . l:history_bufnr)
  call setwinvar(s:history_win_id, '&winfixheight', 1)
  call setwinvar(s:history_win_id, '&readonly', 1)
  " Set buffer options for history buffer
  call setbufvar(l:history_bufnr, '&wrap', 1) " Ensure wrap is on for the buffer
  call setbufvar(l:history_bufnr, '&list', 0) " Disable list characters
  call setbufvar(l:history_bufnr, '&spell', 0) " Disable spell checking
  call nvim_buf_set_keymap(l:history_bufnr, 'n', 'q', ':call s:CloseChatWindows()<CR>', {'noremap': v:true, 'silent': v:true})

  " Create input window
  execute 'new'
  let s:input_win_id = win_getid()
  let s:input_bufnr = nvim_create_buf(v:false, v:true) " buflisted=false, scratch=true
  call nvim_buf_set_name(s:input_bufnr, '__LLMChatInput__')
  call setbufvar(s:input_bufnr, '&buftype', 'nofile')
  call setbufvar(s:input_bufnr, '&bufhidden', 'hide')
  call setbufvar(s:input_bufnr, '&swapfile', v:false)
  call win_execute(s:input_win_id, 'buffer ' . s:input_bufnr)
  call setwinvar(s:input_win_id, '&winfixheight', 1)
  execute 'resize ' . l:input_height

  " Set buffer-local mappings for <CR> and q in the input window
  if s:input_bufnr != -1
    call nvim_buf_set_keymap(s:input_bufnr, 'n', '<CR>', ':call s:SubmitInput()<CR>', {'noremap': v:true, 'silent': v:true})
    call nvim_buf_set_keymap(s:input_bufnr, 'i', '<CR>', '<Esc>:call s:SubmitInput()<CR>', {'noremap': v:true, 'silent': v:true})
    call nvim_buf_set_keymap(s:input_bufnr, 'n', 'q', ':call s:CloseChatWindows()<CR>', {'noremap': v:true, 'silent': v:true})
    call setbufvar(s:input_bufnr, '&modifiable', 1) " Ensure buffer is modifiable
  endif

  " Switch focus to input window and start insert mode
  call win_gotoid(s:input_win_id)
  startinsert
endfunction

" Display g:llmchat_history in the history window
function! s:DisplayHistory()
  let l:history_bufnr = s:EnsureHistoryBuffer()

  " Make buffer modifiable to clear and append lines
  call nvim_buf_set_option(l:history_bufnr, 'modifiable', v:true)

  " Clear the buffer
  call nvim_buf_set_lines(l:history_bufnr, 0, -1, v:false, [])

  " Append history lines
  if exists('g:llmchat_history') && !empty(g:llmchat_history)
    call nvim_buf_set_lines(l:history_bufnr, 0, 0, v:false, g:llmchat_history)
  endif

  " Make buffer readonly again
  call nvim_buf_set_option(l:history_bufnr, 'modifiable', v:false)

  " Go to the last line in the history window
  if s:history_win_id != -1 && win_id2win(s:history_win_id) > 0
    call win_execute(s:history_win_id, 'normal! G')
  endif
endfunction

" Close the chat windows and clean up
function! s:CloseChatWindows()
  " Close history window
  if s:history_win_id != -1 && win_id2win(s:history_win_id) > 0
    call nvim_win_close(s:history_win_id, v:true) " force close
  endif
  let s:history_win_id = -1

  " Close input window and delete its buffer
  if s:input_win_id != -1 && win_id2win(s:input_win_id) > 0
    call nvim_win_close(s:input_win_id, v:true) " force close
  endif
  let s:input_win_id = -1

  if s:input_bufnr != -1 && bufexists(s:input_bufnr)
    call nvim_buf_delete(s:input_bufnr, {'force': v:true})
  endif
  let s:input_bufnr = -1
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
    call nvim_buf_set_lines(s:input_bufnr, 0, -1, v:false, [''])
  endif

  " Ensure input window is in insert mode and cursor at line 1, column 1
  if s:input_win_id != -1 && win_id2win(s:input_win_id) > 0
    call cursor(1, 1) " Position cursor at the beginning of the buffer
    call win_execute(s:input_win_id, 'startinsert')
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
