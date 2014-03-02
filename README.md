vim-tomato-md
=============

A Vim plugin to write daily pomodoro memo in markdown.
It counts total pomodoros in `daily.md` and update todo/free/total numbers.

# Requirements
- [NeoBundle](https://github.com/Shougo/neobundle.vim)
- vim ruby interface `if_ruby` (Enabled if `:echo has('ruby')` returns `1`)

# Install
Write the following settings to your .vimrc

```vimrc
" tomato_md {{{
  NeoBundle 'ikuo/vim-tomato-md'

  " Activate tomato_md when daily.md is opened.
  augroup TomatoMdActivate
    au!
    au BufWinEnter,BufRead,BufNewFile daily.md call tomato_md#activate()
  augroup END

  " Rewrite day-header on Ctrl-p.
  nnoremap <C-p> :call tomato_md#rewrite()<CR>

  " (optional) Quickly find day separators.
  nnoremap <C-n> /# ====<CR>
" }}}
```

Install vim-tomato-md with neobundle.

```
:NeoBundleInstall
```

# Usage
Save the following markdown as `daily.md` into your favorite directory:

```md
# ====
# 10/31 Mon 9m-11, 12-18m (todo:0, free:0, total:0)
- Task1 [@][]
- Task2 [][][]

# ====
```

Write your daily.md according to the format described in the following section.
When you type Ctrl-p, counts of todo pomodoros will be updated in the day header.

## Format of daily.md
`daily.md` describes a list of day sections. Each day section has pomodoros.

### Pomodoro
- `[]` is a pomodoro to do.
- `[x]` is a pomodoro done.
- `[@]` is a pomodoro to highlight. e.g. current or next.

### Day Section Header
The line begins with `# ====` separates days.
Each day has a header line of the following format:

```md
# <any date string> <time spans to work> (todo:0, free:0, total:0)
```

<time spans to work> is a comma separated list of a time span of the format "<begin>`-`<end>".
<begin> or <end> is a number of a clock optioally suffixed by `m` that means 'a half after the oclock'.
For example `9m-11, 12-18m` means that "I'm going to work 9:30 to 11:00, and 12:00 to 18:30".

The meanings of elements of the latter part are:

- `todo`: Number of pomodoros to do (Count of `[]`)
- `free`: Number of pomodoros that can be done in the rest of this day.
- `total`: Number of pomodoros that can be done in this day.
