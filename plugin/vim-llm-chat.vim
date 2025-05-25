" LLM Chat Plugin for Vim (Vimscript only, no Neovim dependencies)

if exists('g:loaded_llmchat')
  finish
endif
let g:loaded_llmchat = 1

let s:llmchat_bufnr = -1

function! s:OpenChatBuffer()
  if bufexists('LLMChat')
    execute 'buffer ' . bufnr('LLMChat')
    let s:llmchat_bufnr = bufnr('LLMChat')
  else
    new
    setlocal buftype=nofile bufhidden=hide nobuflisted noswapfile
    file LLMChat
    let s:llmchat_bufnr = bufnr('%')
    call setline(1, ['LLM Chat', 'Type your message below the separator, then run :LLMSend'])
    call append(line('$'), '---')
    normal! G
  endif
endfunction

function! s:GetCurrentFileContent()
  return join(getbufline(bufnr('#'), 1, '$'), "\n")
endfunction

function! s:GetFileList()
  let l:gitdir = finddir('.git', expand('%:p:h').';')
  if empty(l:gitdir)
    let l:dir = expand('%:p:h')
  else
    let l:dir = fnamemodify(l:gitdir, ':h')
  endif
  return split(glob(l:dir . '/*', 0, 1), '\n')
endfunction

function! s:SendToLLMChat()
  let l:lines = getbufline(s:llmchat_bufnr, 1, '$')
  let l:sepidx = index(l:lines, '---')
  if l:sepidx == -1
    call appendbufline(s:llmchat_bufnr, '$', '---')
    let l:sepidx = len(l:lines)
  endif
  let l:user_input = join(l:lines[(l:sepidx+1):], "\n")
  if empty(trim(l:user_input))
    echo "No message to send."
    return
  endif

  let l:file_content = s:GetCurrentFileContent()
  let l:file_list = s:GetFileList()
  let l:payload = {
        \ 'question': l:user_input,
        \ 'file_content': l:file_content,
        \ 'file_list': l:file_list
        \ }
  let l:json = json_encode(l:payload)
  let l:api_url = get(g:, 'llmchat_api_url', 'https://your-llm-api.com/chat')
  let l:auth = get(g:, 'llmchat_api_auth_header', '')

  let l:cmd = 'curl -s -X POST -H "Content-Type: application/json"'
  if !empty(l:auth)
    let l:cmd .= ' -H ' . shellescape(l:auth)
  endif
  let l:cmd .= ' --data ' . shellescape(l:json) . ' ' . shellescape(l:api_url)
  let l:response = system(l:cmd)

  " Append chat history
  call appendbufline(s:llmchat_bufnr, l:sepidx, 'User: ' . l:user_input)
  call appendbufline(s:llmchat_bufnr, l:sepidx + 1, 'LLM: ' . l:response)
  " Reset input area
  call deletebufline(s:llmchat_bufnr, l:sepidx+2, '$')
  call appendbufline(s:llmchat_bufnr, '$', '---')
  call cursor(s:llmchat_bufnr, line('$'), 1)
endfunction

command! LLMChat call s:OpenChatBuffer()
command! LLMSend call s:SendToLLMChat()
