" LLMChat: FZF-based Chat UI for Vim with LLM backend
" Requires fzf.vim and simonw/llm CLI installed and available in your $PATH

if exists('g:loaded_llmchat')
  finish
endif
let g:loaded_llmchat = 1

" In-memory chat history (as a List of strings)
let s:llmchat_history = []

" Write chat history to a temp file, return the filename
function! s:WriteHistoryToFile()
  let l:file = '/tmp/llmchat_history_' . printf('%d', localtime()) . '_' . printf('%d', rand())
  call writefile(s:llmchat_history, l:file)
  call system('chmod 644 ' . shellescape(l:file))
  return l:file
endfunction

" Call the LLM backend with the given prompt, return the response as string
function! s:AskLLM(prompt)
  let l:llm_cmd = get(g:, 'llmchat_llm_command', 'llm')
  let l:model_arg = get(g:, 'llmchat_llm_model_arg', '')
  let l:cmd = l:llm_cmd
  if !empty(l:model_arg)
    let l:cmd .= ' -m ' . shellescape(l:model_arg)
  endif
  return system(l:cmd, a:prompt)
endfunction

" FZF chat main entry point
function! LLMChat()
  " Use global so user can keep chat between invocations
  if exists('g:llmchat_history')
    let s:llmchat_history = g:llmchat_history
  else
    let s:llmchat_history = []
  endif
  call s:LLMChatFZF()
endfunction

" Main FZF chat loop (called after each turn)
function! s:LLMChatFZF()
  let l:history_file = s:WriteHistoryToFile()
  let l:opts = [
        \ '--prompt=You: ',
        \ '--layout=reverse',
        \ '--info=inline',
        \ '--preview', 'cat ' . shellescape(l:history_file),
        \ '--preview-window', 'up:70%:wrap',
        \ '--no-sort',
        \ '--no-multi',
        \ '--bind', 'enter:accept',
        \ '--print-query'
        \ ]
  let l:spec = {
        \ 'source': [' '],
        \ 'sink*': function('s:OnFZFChatSend'),
        \ 'options': l:opts,
        \ 'window': {
        \   'width': 80,
        \   'height': &lines - 2,
        \   'xoffset': 1,
        \   'yoffset': 0,
        \   'highlight': 'Normal',
        \   'border': 'none'
        \ }}
  call fzf#run(l:spec)
endfunction

" Handler: user submits message via FZF
function! s:OnFZFChatSend(lines)
  if len(a:lines) == 0
    return
  endif

  " First line is the user's typed input (from --print-query)
  let l:input = a:lines[0]
  if !empty(trim(l:input))
    call add(s:llmchat_history, 'You: ' . l:input)
    redraw | echo "Waiting for LLM..."
    let l:response = s:AskLLM(l:input)
    call add(s:llmchat_history, 'LLM: ' . substitute(l:response, '\n\+$', '', ''))
    let g:llmchat_history = s:llmchat_history
    call s:LLMChatFZF()
  endif
endfunction

" Command to start chat
command! LLMChat call LLMChat()
