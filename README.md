vim-tomato-md
=============

A Vim plugin to write daily pomodoro memo in markdown.
It counts total pomodoros in `daily.md` and update done/todo/free/total numbers.

# Usage
## 1. Activate highlight and keymap
Write the following settings to your .vimrc

```vimrc
" tomato_md {{{
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

## 2. Write and update daily.md
Save the following markdown as `daily.md` into your favorite directory:

```md
# ====
# 1/2 Mon 9m-11, 12-18m (done:0, lost:0, todo:0, free:0, total:0)
- Task1 [@][]
- Task2 [][][]

# ====
```

Write your daily.md according to the format described in the following section.
When you type Ctrl-p, counts of done/todo pomodoros will be updated in the day header.

# Format of daily.md
## Pomodoros
- `[]` is a pomodoro to do.
- `[x]` is a pomodoro done.
- `[@]` is a pomodoro to highlight. e.g. current or next.

## Headers
The line begins with `# ====` separates days.
Each day has a header line of the following format:

```md
# <any date string> <time spans to work> (done:0, lost:0, todo:0, free:0, total:0)
```

<time spans to work> is a comma separated list of a time span of the format "<begin>`-`<end>".
<begin> or <end> is a number of a clock optioally suffixed by `m` that means 'a half after the oclock'.
For example `9m-11, 12-18m` means that "I'm going to work 9:30 to 11:00, and 12:00 to 18:30".

The meanings of elements of the latter part are:

- `done`: Number of finished pomodoros (Count of `[x]`)
- `lost`: (todo: document it)
- `todo`: Number of pomodoros to do (Count of `[]`)
- `free`: Number of pomodoros that can be done in the rest of this day.
- `total`: Number of pomodoros that can be done in this day.

# Example

```md
# ====
# 1/8 Sun. 14-18, 19-21 (done:1, lost:1, todo:6, free:4, total:12)
## Task1
- [x][@][][] Subtask1
- [][][] Subtask2

# ====
# 1/7 Sun. 14-18, 19-21 (done:7, lost:3, todo:0, free:2, total:12)
...
