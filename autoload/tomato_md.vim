" Save user settings.
let s:save_cpo = &cpo
set cpo&vim


" Rewrite header line.
function! tomato_md#rewrite()
ruby << EOC
  pat_tomatos = /\((done:[\d\.]+,.*total:[\d\.]+)\)/
  @pat_ranges = /(([\d\.]+m?\-[\d\.]+m?)(\s*,\s*[\d\.]+m?\-[\d\.]+m?)*)/
  @now_pivot = nil

  # Count number of done, todo pomodoros.
  def count_tomatos(start_line_number)
    another_day = /^# /
    done = /\[x\]/
    todo = /\[@?\]/

    ln = start_line_number + 1
    line = $curbuf[ln]

    counts = { :done => 0, :todo => 0 }
    while line && !(line =~ another_day)
      counts[:done] += line.scan(done).size
      counts[:todo] += line.scan(todo).size
      ln += 1
      line = $curbuf[ln] rescue break
    end

    counts
  end

  # Parse time ranges
  def parse_ranges(line, total_only = false)
    results = {}
    if line.empty?
      results[:total] = 0
    elsif line =~ @pat_ranges
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
      %w[done lost todo free total].map do |key|
        "#{key}:#{values[key.to_sym].round}"
      end
    updated = "(%s)" % parts.join(', ')
    $curbuf[line_number] = $curbuf[line_number].gsub(pat_tomatos, updated)
  end

  def find_matching_line(pattern)
    line_number = $curbuf.line_number
    while (line_number > 0 && $curbuf[line_number] !~ pattern)
      line_number -= 1
    end
    [line_number, $1]
  end

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
      :lost  => (ranges[:past]   * 2 - counts[:done]),
      :free  => (ranges[:future] * 2 - counts[:todo])
    )
    replace_line(pat_tomatos, values, line_number)
  else
    VIM::message("No status found.")
  end
EOC
endfunction

" Activate tomato_md in the current buffer.
function! tomato_md#activate()
  highlight PomodoroDaySeparator ctermbg=green guifg=black guibg=yellow
  match PomodoroDaySeparator /^# ====\+\|\[@\]/
endfunction


" Restore user settings.
let &cpo = s:save_cpo
