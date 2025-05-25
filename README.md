# LLM Chat for Vim

**LLM Chat for Vim** is a pure Vimscript plugin that brings a chat-like interface powered by any LLM (Large Language Model) API directly into Vim. Ask questions, get code explanations, and plan work—all from within your editor. The plugin sends your current file and project directory context to your LLM and displays responses in a chat buffer.

---

## Features

- Chat interface in a special Vim buffer
- Sends current file contents and file list for context
- Displays conversational history inline
- Works with any LLM API that accepts JSON POST requests
- Pure Vimscript—works with Vim (8.0+) and Neovim

---

## Installation

### Vundle

Add this to your `.vimrc`:

```vim
Plugin 'DavidRagone/vim-llm-chat'
```

Then run:

```
:source ~/.vimrc
:PluginInstall
```

### vim-plug

```vim
Plug 'DavidRagone/vim-llm-chat'
```

Then:

```
:source ~/.vimrc
:PlugInstall
```

### Pathogen

```
git clone https://github.com/DavidRagone/vim-llm-chat ~/.vim/bundle/vim-llm-chat
```

### Manual

Download `plugin/vim-llm-chat.vim` and place it in `~/.vim/plugin/`.

---

## Setup

Add your LLM API endpoint (and, if needed, authorization header) to your `.vimrc`:

```vim
let g:llmchat_api_url = 'https://your-llm-api.com/chat'
let g:llmchat_api_auth_header = 'Authorization: Bearer YOUR_TOKEN'   " If needed
```

---

## Usage

1. Open any file in Vim.
2. Run `:LLMChat` to open the chat buffer.
3. Type your question **below the separator line (`---`)**.
4. Run `:LLMSend` to send your question and context to the LLM.
5. The LLM's response and your question will appear in the chat buffer.

You can continue the conversation by repeating steps 3-5.

---

## Requirements

- Vim 8.0+ with `+channel` or `+job` support (Neovim supported as well)
- `curl` available in your system PATH
- An LLM API endpoint that accepts JSON POST requests and returns a plain text response

---

## Security

**Never send private code or sensitive data to a third-party API without verifying the endpoint and reviewing its privacy policy.**

---

## Customization

You can customize the plugin commands or buffer name by modifying `plugin/llmchat.vim`.

---

## License

MIT

---

## Contributing

Pull requests and issues are welcome!

---

