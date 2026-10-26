# Plot — рисунки SVG и текстовые спарклайны без внешних гемов.

require 'fileutils'

module SmLab
  module Plot
    module_function

    def sparkline(values, width: 42)
      glyphs = [' ', '▁', '▂', '▃', '▄', '▅', '▆', '▇', '█']
      return '' if values.nil? || values.empty?

      window = values.size <= width ? values : downsample(values, width)
      min, max = window.minmax
      span = max - min
      window.map do |value|
        index = span < 1e-9 ? 0 : (((value - min) / span) * (glyphs.size - 1)).round
        glyphs[index.clamp(0, glyphs.size - 1)]
      end.join
    end

    def series_svg(series, path, title:, x_label: 'Шаг', y_label: 'Уровень')
      write_svg(path, series_document(series, title: title, x_label: x_label, y_label: y_label))
    end

    def heatmap_svg(rows, path, title:, y_label: 'шаг')
      write_svg(path, heatmap_document(rows, title: title, y_label: y_label))
    end

    def trail_svg(points, path, title:, target: nil)
      write_svg(path, trail_document(points, title: title, target: target))
    end

    def downsample(values, width)
      bucket = values.size.to_f / width
      width.times.map do |index|
        slice = values[(index * bucket).floor, bucket.ceil] || []
        slice.empty? ? 0.0 : slice.sum.fdiv(slice.size)
      end
    end

    def write_svg(path, document)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, document)
      path
    end

    def escape(text)
      text.to_s.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')
    end

    def series_document(series, title:, x_label:, y_label:)
      width = 720
      height = 360
      left = 56
      right = 24
      top = 48
      bottom = 46
      plot_w = width - left - right
      plot_h = height - top - bottom
      names = series.keys
      lengths = names.map { |name| series[name].size }
      steps = lengths.max || 0
      flat = names.flat_map { |name| series[name] }
      y_min, y_max = flat.minmax
      y_min ||= 0.0
      y_max ||= 1.0
      y_min -= 0.05
      y_max += 0.05
      span = (y_max - y_min).abs
      span = 1.0 if span < 1e-9
      colors = %w[#1f4d3a #b4532a #24527a]

      polylines = names.each_with_index.map do |name, index|
        points = series[name].each_with_index.map do |value, step|
          x = left + (steps <= 1 ? plot_w / 2.0 : (step.to_f / (steps - 1)) * plot_w)
          y = top + (1.0 - ((value - y_min) / span)) * plot_h
          format('%.2f,%.2f', x, y)
        end.join(' ')
        %(<polyline fill="none" stroke="#{colors[index % colors.size]}" stroke-width="2" points="#{points}"/>)
      end.join("\n")

      legend = names.each_with_index.map do |name, index|
        y = 22
        x = 240 + index * 150
        %(<rect x="#{x}" y="#{y - 10}" width="14" height="4" fill="#{colors[index % colors.size]}"/>) +
          %(<text x="#{x + 20}" y="#{y}" font-size="13">#{escape(name)}</text>)
      end.join

      <<~SVG
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" width="#{width}" height="#{height}" viewBox="0 0 #{width} #{height}">
          <rect width="100%" height="100%" fill="#fbfaf6"/>
          <text x="24" y="28" font-family="Georgia, serif" font-size="18">#{escape(title)}</text>
          #{legend}
          <line x1="#{left}" y1="#{top}" x2="#{left}" y2="#{top + plot_h}" stroke="#222" stroke-width="1"/>
          <line x1="#{left}" y1="#{top + plot_h}" x2="#{left + plot_w}" y2="#{top + plot_h}" stroke="#222" stroke-width="1"/>
          <text x="16" y="#{top + 12}" font-size="12">#{format('%.2f', y_max)}</text>
          <text x="16" y="#{top + plot_h}" font-size="12">#{format('%.2f', y_min)}</text>
          <text x="#{left + plot_w / 2 - 20}" y="#{height - 12}" font-size="13">#{escape(x_label)}</text>
          <text x="18" y="#{top - 8}" font-size="13">#{escape(y_label)}</text>
          #{polylines}
        </svg>
      SVG
    end

    def heatmap_document(rows, title:, y_label: 'шаг')
      steps = rows.size
      neurons = rows.first&.size || 0
      cell_w = [[640.0 / [neurons, 1].max, 8].min, 36].min
      cell_h = [[280.0 / [steps, 1].max, 4].min, 18].min
      width = (neurons * cell_w + 80).ceil
      height = (steps * cell_h + 70).ceil
      rects = rows.each_with_index.flat_map do |row, y|
        row.each_with_index.map do |value, x|
          shade = value.to_f.clamp(0.0, 1.0)
          color = mix('#f4efe6', '#1f4d3a', shade)
          %(<rect x="#{48 + x * cell_w}" y="#{48 + y * cell_h}" width="#{cell_w}" height="#{cell_h}" fill="#{color}"/>)
        end
      end.join

      <<~SVG
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" width="#{width}" height="#{height}" viewBox="0 0 #{width} #{height}">
          <rect width="100%" height="100%" fill="#fbfaf6"/>
          <text x="16" y="28" font-family="Georgia, serif" font-size="18">#{escape(title)}</text>
          <text x="48" y="#{height - 12}" font-size="12">нейрон →</text>
          <text x="8" y="60" font-size="12">#{escape(y_label)}</text>
          #{rects}
        </svg>
      SVG
    end

    def trail_document(points, title:, target:)
      xs = points.map(&:first)
      ys = points.map(&:last)
      xs << target.first if target
      ys << target.last if target
      min_x, max_x = xs.minmax
      min_y, max_y = ys.minmax
      pad = 0.6
      min_x -= pad
      max_x += pad
      min_y -= pad
      max_y += pad
      span_x = [max_x - min_x, 0.1].max
      span_y = [max_y - min_y, 0.1].max
      left = 40
      top = 48
      plot = 420

      mapped = points.map do |x, y|
        px = left + ((x - min_x) / span_x) * plot
        py = top + (1.0 - ((y - min_y) / span_y)) * plot
        [px, py]
      end
      poly = mapped.map { |x, y| format('%.1f,%.1f', x, y) }.join(' ')
      target_dot = ''
      if target
        tx = left + ((target.first - min_x) / span_x) * plot
        ty = top + (1.0 - ((target.last - min_y) / span_y)) * plot
        target_dot = %(<circle cx="#{tx.round(1)}" cy="#{ty.round(1)}" r="6" fill="#b4532a"/>)
      end
      start = mapped.first
      finish = mapped.last

      <<~SVG
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" width="500" height="520" viewBox="0 0 500 520">
          <rect width="100%" height="100%" fill="#fbfaf6"/>
          <text x="16" y="28" font-family="Georgia, serif" font-size="18">#{escape(title)}</text>
          <polyline fill="none" stroke="#1f4d3a" stroke-width="2" points="#{poly}"/>
          <circle cx="#{start[0].round(1)}" cy="#{start[1].round(1)}" r="4" fill="#24527a"/>
          <circle cx="#{finish[0].round(1)}" cy="#{finish[1].round(1)}" r="4" fill="#1f4d3a"/>
          #{target_dot}
        </svg>
      SVG
    end

    def mix(from_hex, to_hex, t)
      from = hex_rgb(from_hex)
      to = hex_rgb(to_hex)
      rgb = from.zip(to).map { |a, b| (a + ((b - a) * t)).round }
      format('#%02x%02x%02x', *rgb)
    end

    def hex_rgb(hex)
      value = hex.delete_prefix('#')
      [value[0..1], value[2..3], value[4..5]].map { |pair| pair.to_i(16) }
    end
  end
end
