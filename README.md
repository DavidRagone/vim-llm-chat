# LLM Chat for Vim (with simonw/llm CLI)

**LLM Chat for Vim** is a pure Vimscript plugin that brings a chat-like AI interface directly into Vim, powered by the [llm](https://github.com/simonw/llm) command-line tool. Ask questions, get code explanations, and plan work—all from within your editor. The plugin sends your current file and project directory context to your local LLM, and displays responses in a chat buffer.

---

## Features

- Chat interface in a special Vim buffer
- Sends current file contents and file list for context
- Displays conversational history inline
- Uses [llm](https://llm.datasette.io/) command-line tool for local or API-backed LLMs
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

```sh
git clone https://github.com/DavidRagone/vim-llm-chat ~/.vim/bundle/vim-llm-chat
```

### Manual

Download `plugin/vim-llm-chat` and place it in `~/.vim/plugin/`.

---

## Requirements

- Vim 8.0+ with `+channel` or `+job` support (Neovim supported as well)
- [`llm` CLI](https://llm.datasette.io/en/stable/installation.html) installed and configured
- Any models or API keys you want to use with `llm` (see [llm setup docs](https://llm.datasette.io/))

---

## Setup

Optionally, set the LLM model to use in your `.vimrc`:

```vim
let g:llmchat_llm_command = 'llm'              " Path to your llm executable (default: 'llm')
let g:llmchat_llm_model_arg = 'gpt-4-turbo'    " Optional: specify model, e.g. 'gpt-3.5-turbo'
```
If you omit `llmchat_llm_model_arg`, the default model configured in your `llm` tool will be used.

---

## Usage

1. Open any file in Vim.
2. Run `:LLMChat` to open the chat buffer.
3. Type your question **below the separator line (`---`)**.
4. Run `:LLMSend` to send your question and context to the LLM.
5. The LLM's response and your question will appear in the chat buffer.

You can continue the conversation by repeating steps 3-5.

---

## How It Works

- The plugin assembles a prompt containing your question, the current file contents, and a list of files in your project directory.
- The prompt is sent to the `llm` tool, which returns a response using your chosen model/API.
- The conversation history appears in the chat buffer.

---

## Security

Your code and questions are sent to the `llm` tool. Depending on your model configuration, this may result in your data being sent to remote APIs (OpenAI, etc.) or processed locally. **Check your `llm` configuration and privacy preferences.**

---

## Customization

You can customize the plugin commands or buffer name by modifying `plugin/vim-llm-chat`.

---

## License

MIT

---

## Contributing

Pull requests and issues are welcome!

---

## Credits

Built on top of the workflow inspired by GitHub Copilot Chat and [llm](https://llm.datasette.io/).

