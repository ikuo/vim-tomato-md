" Save user settings.
let s:save_cpo = &cpo
set cpo&vim

ruby << EOC
module TomatoMd
  PATTERNS = {
    :tomatos => /\((todo:[\d\.]+,.*total:[\d\.]+)\)/,
    :day => /^# /,
    :ranges => /(([\d\.]+m?\-[\d\.]+m?)(\s*,\s*[\d\.]+m?\-[\d\.]+m?)*)/,
    :day_separator => /^# ====/
  }.freeze

  module Helper
    # Public: Update cursor position.
    def update_cursor
      row, col = yield($curwin.cursor)
      $curwin.cursor = [row, col]
    end

    # Public: Update cursor to the target line.
    def update_cursor_to(target_line)
      rows = [
        find_line(:direction => :up)   {|line| line == target_line },
        find_line(:direction => :down) {|line| line == target_line },
      ]
      distance = rows.map {|row| (row - $curbuf.line_number).abs }
      target_row = (distance[0] < distance[1]) ? rows[0] : rows[1]

      update_cursor {|row, col| [target_row, col] }
    end

    # Public: Let cursor position follow the chang of the give block.
    def preserve_cursor_position
      cursor_line = $curbuf.line
      yield
      update_cursor_to(cursor_line)
    end

    # Public: Move lines (<line_start> .. <line_end>) after line <append_to>
    def move_lines(line_start, line_end, append_to)
      VIM::message("Moving L:#{line_start}-#{line_end} after L:#{append_to}")
      range = (line_start .. line_end)
      n_lines = line_end - line_start
      lines = range.map {|n| $curbuf[n] }
      range.each {|n| $curbuf.delete(line_start) }

      (0 .. n_lines).each do |line_num|
        $curbuf.append(append_to + line_num, lines[line_num])
      end

      row, col = $curwin.cursor
      $curwin.cursor = [row + n_lines, col]
    end

    # Public: Find specified pattern.
    #
    # Returns an array of [line number, matched string]
    def find_matching_line(pattern, options = {})
      line_number = options[:start] || $curbuf.line_number
      while (
        (line_number > 0) &&
          (line_number <= $curbuf.count) &&
          ($curbuf[line_number] !~ pattern)
      )
        if options[:direction] == :down
          line_number += 1
        else
          line_number -= 1
        end
      end
      [line_number, $1]
    end

    # Public: Find line that matches the given block.
    #
    # Examples:
    #
    #   find_line(:direction => :down) do |line|
    #     (line == '# ========')
    #   end
    #   # => 15
    #
    # Returns number of the matched line.
    def find_line(options)
      line_number = options[:start] || $curbuf.line_number
      while (
        (line_number > 0) && (line_number <= $curbuf.count) &&
          !yield($curbuf[line_number])
      )
        if options[:direction] == :down
          line_number += 1
        else
          line_number -= 1
        end
      end
      line_number
    end
  end

  class RewriteDayHeader
    include TomatoMd::Helper

    def initialize
      @now_pivot = nil
    end

    def run
      pat_tomatos = TomatoMd::PATTERNS[:tomatos]

      line_number, match_data = find_matching_line(pat_tomatos)

      if line_number > 0
        line = $curbuf[line_number]
        counts = count_tomatos(line_number)
        ranges = parse_ranges(line)
        VIM::message("now %s, (past %s hrs + future %s hrs) = %s hrs" % [
          now_pivot, ranges[:past], ranges[:future], ranges[:total]
        ])

        values = {}
        match_data.split(',').map {|part| part.split(':').map(&:strip) }.
          each do |key, val|
            values[key.to_sym] = val
          end

        values.merge!(counts).merge!(
          :total =>  ranges[:total]  * 2,
          :free  => (ranges[:future] * 2 - counts[:todo])
        )
        replace_line(pat_tomatos, values, line_number)
      else
        VIM::message("No status found.")
      end
    end

    private

    # Internal: Count number of todo pomodoros.
    def count_tomatos(start_line_number)
      another_day = TomatoMd::PATTERNS[:day]
      todo = /\[@?\]/

      ln = start_line_number + 1
      line = $curbuf[ln]

      counts = { :todo => 0 }
      while line && !(line =~ another_day)
        counts[:todo] += line.scan(todo).size
        ln += 1
        line = $curbuf[ln] rescue break
      end

      counts
    end

    # Internal: Parse time ranges
    def parse_ranges(line, total_only = false)
      results = {}
      if line.empty?
        results[:total] = 0
      elsif line =~ TomatoMd::PATTERNS[:ranges]
        str = $1
        str_ranges = str.gsub('m', '.5').split(',')
        results[:total] = str_ranges.map {|range| eval(range)}.inject(&:+).abs

        unless total_only
          timeframes = str_ranges.map {|r| r.split('-').map(&:to_f) }
          ranges = timeframes.map {|(s,e)| (s .. e) }

          past_line = make_past_ranges(str_ranges, ranges).join(',')

          results[:past] = parse_ranges(past_line, true)[:total]
          results[:future] = results[:total] - results[:past]
        end
      else
        VIM::message("No hours found for: #{line}")
      end
      results
    end

    # Internal
    def make_past_ranges(str_ranges, ranges)
      index = -1
      current_range = ranges.find {|range| index += 1; range.include?(now_pivot) }

      if current_range
        past_ranges = index.zero? ? [] : str_ranges[0 .. (index - 1)]
        past_ranges << [current_range.begin, now_pivot].join('-')
      else
        num_ranges = ranges.select {|range| range.end < now_pivot }.size
        num_ranges.zero? ? [] : str_ranges[0 .. (num_ranges - 1)]
      end
    end

    # Rounded number of now (e.g. 10.5, 11)
    def now_pivot
      @now_pivot ||= begin
        now = Time.now
        minor = ((now.min / 60.0) * 2).round / 2.0  # 0.0 or 0.5 or 1.0
        now.hour + minor
      end
    end

    # Replace line with updated values.
    def replace_line(pat_tomatos, values, line_number)
      parts =
        %w[todo free total].map do |key|
          "#{key}:#{values[key.to_sym].round}"
        end
      updated = "(%s)" % parts.join(', ')
      $curbuf[line_number] = $curbuf[line_number].gsub(pat_tomatos, updated)
    end
  end

  class RewriteRulers
    include TomatoMd::Helper
    SEPARATOR = '# ========'

    def run
      preserve_cursor_position do
        delete_separators
      end
      add_separators
    end

    private

    def delete_separators
      line_num = 1
      while (line_num <= $curbuf.length) do
        if $curbuf[line_num] =~ TomatoMd::PATTERNS[:day_separator]
          $curbuf.delete(line_num)
          $curbuf.delete(line_num) if $curbuf[line_num].empty?
        else
          line_num += 1
        end
      end
    end

    def add_separators
      pat_tomatos = TomatoMd::PATTERNS[:tomatos]

      preserve_cursor_position do
        before, _ = find_matching_line(pat_tomatos)
        $curbuf.append(before - 1, '')
        $curbuf.append(before - 1, SEPARATOR)
      end

      after,  _ = find_matching_line(pat_tomatos, :direction => :down)
      $curbuf.append(after  - 1, '')
      $curbuf.append(after  - 1, SEPARATOR)
    end
  end
end
EOC

" Rewrite header line.
function! tomato_md#rewrite()
ruby << EOC
  TomatoMd::RewriteDayHeader.new.run
  TomatoMd::RewriteRulers.new.run
EOC
endfunction

" Mark current task as complete.
function! tomato_md#complete()
ruby << EOC
  new_line = $curbuf.line.gsub('[@]', '[x]')
  $curbuf.line = new_line if (new_line != $curbuf.line)
EOC
endfunction

" Postpone visual-selected text to the next day.
function! tomato_md#postpone() range
ruby << EOC
  include TomatoMd::Helper

  # Public: Find first subsection line from tommorrow area.
  # Returns found line number.
  def find_append_target
    pat_tomatos = TomatoMd::PATTERNS[:tomatos]

    tommorow, _ = find_matching_line(pat_tomatos)
    tommorow, _ = find_matching_line(pat_tomatos, :start => (tommorow - 1))
    sub_section_line, _ =
      find_matching_line(/^#/, :start => (tommorow + 1), :direction => :down)

    target = sub_section_line - 1
    $curbuf[target].empty? ? (target - 1) : target
  end

  # Public: Find the subsection until it reaches the end of the day.
  # Returns found line number. nil if not found.
  def find_merge_target(subsection, start_line)
    line_number =
      find_line(:direction => :down, :start => start_line) do |line|
        (line == subsection) ||
          (line =~ TomatoMd::PATTERNS[:day])
      end

    ($curbuf[line_number] == subsection) ? line_number : nil
  end

  def merge_if_possible(first_line, last_line, append_target)
    merge_target = find_merge_target($curbuf[first_line], append_target + 1)
    if merge_target
      $curbuf.delete(first_line)  # delete duplicate subsection header
      last_line = last_line - 1
      append_target = merge_target
    end
    [first_line, last_line, append_target]
  end

  first_line, last_line, append_target =
    merge_if_possible(
      VIM::evaluate('a:firstline'),
      VIM::evaluate('a:lastline'),
      find_append_target
    )

  move_lines(first_line, last_line, append_target)
EOC
endfunction

" Activate tomato_md in the current buffer.
function! tomato_md#activate()
  highlight PomodoroDaySeparator ctermbg=green guifg=black guibg=yellow
  match PomodoroDaySeparator /^# ====\+\|\[@\]/
endfunction


" Restore user settings.
let &cpo = s:save_cpo
