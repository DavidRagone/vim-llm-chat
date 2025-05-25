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
        \ '--preview-window', 'up:50%:wrap',
        \ '--no-sort',
        \ '--no-multi',
        \ '--bind', 'enter:accept'
        \ ]
  " Show fzf with chat lines as the candidate list, using prompt for next message
  call fzf#run(fzf#wrap({
        \ 'source': l:history_file,
        \ 'sink*': function('s:OnFZFChatSend'),
        \ 'options': l:opts,
        \ 'down': '60%'
        \ }))
endfunction

" Handler: user submits message via FZF
function! s:OnFZFChatSend(lines)
  " fzf passes a list of selected lines; user's message is in <q-args>
  " But fzf#wrap does not pass prompt input, so we have to grab from input()
  " Instead, prompt user for message after fzf closes
  let l:input = input('You: ')
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
