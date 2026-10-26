# frozen_string_literal: true

require "fileutils"

module SnailNetwork
  # Графики в SVG. Ни ImageMagick, ни Graphviz не нужны: файл открывается
  # браузером. Схема топологии тоже собирается в SVG, без Graphviz.
  module Chart
    module_function

    PALETTE = %w[
      #1f77b4 #ff7f0e #2ca02c #d62728 #9467bd #8c564b
      #e377c2 #7f7f7f #bcbd22 #17becf #393b79 #637939
      #8c6d31 #843c39 #7b4173 #3182bd #e6550d #31a354
    ].freeze

    # Ломаные по рядам одинаковой длины. Ось X — номер точки.
    # @param series [Array<Hash>] элементы :name и :values
    # @param filename [String]
    # @return [String] путь к файлу
    def line(series, filename, title: nil)
      lists = Array(series).map { |item| { name: item[:name].to_s, values: Array(item[:values]).map(&:to_f) } }
      raise ArgumentError, "Нет рядов для графика" if lists.empty?
      raise ArgumentError, "Ряд графика пуст" if lists.any? { |item| item[:values].empty? }

      length = lists.first[:values].size
      unless lists.all? { |item| item[:values].size == length }
        raise ArgumentError, "Ряды графика разной длины"
      end

      write(filename, line_svg(lists, title))
    end

    # Столбики. Подпись и число на каждый столбец.
    # @param rows [Array<Hash>] элементы :label и :value
    # @param filename [String]
    # @return [String]
    def bars(rows, filename, title: nil)
      items = Array(rows).map { |item| { label: item[:label].to_s, value: item[:value].to_f } }
      raise ArgumentError, "Нет столбцов для графика" if items.empty?

      write(filename, bars_svg(items, title))
    end

    def write(filename, body)
      FileUtils.mkdir_p(File.dirname(filename))
      File.write(filename, body)
      filename
    end

    def line_svg(lists, title)
      legend_row = 14
      top = title ? 34 : 16
      bottom = 32
      left = 52
      legend_w = lists.size > 1 ? 76 : 8
      plot_h = [lists.size * legend_row + 8, 280].max
      width = 720
      height = top + plot_h + bottom
      plot_w = width - left - legend_w - 12
      y_min, y_max = padded_range(lists.flat_map { |item| item[:values] })
      x_max = [lists.first[:values].size - 1, 1].max

      parts = frame(width, height, title)
      5.times do |tick|
        value = y_min + ((y_max - y_min) * tick / 4.0)
        y = top + plot_h - ((value - y_min) / (y_max - y_min) * plot_h)
        parts << %(<line x1="#{left}" y1="#{round(y)}" x2="#{left + plot_w}" y2="#{round(y)}" class="grid"/>)
        parts << %(<text x="#{left - 6}" y="#{round(y + 4)}" text-anchor="end" class="tick">#{format_tick(value)}</text>)
      end
      parts << %(<line x1="#{left}" y1="#{top}" x2="#{left}" y2="#{top + plot_h}" class="axis"/>)
      parts << %(<line x1="#{left}" y1="#{top + plot_h}" x2="#{left + plot_w}" y2="#{top + plot_h}" class="axis"/>)
      parts << %(<text x="#{left}" y="#{height - 8}" class="tick">0</text>)
      parts << %(<text x="#{left + plot_w}" y="#{height - 8}" text-anchor="end" class="tick">#{x_max}</text>)

      lists.each_with_index do |item, index|
        color = PALETTE[index % PALETTE.size]
        points = item[:values].each_with_index.map do |value, step|
          x = left + (step.to_f / x_max * plot_w)
          y = top + plot_h - ((value - y_min) / (y_max - y_min) * plot_h)
          "#{round(x)},#{round(y)}"
        end
        parts << %(<polyline points="#{points.join(' ')}" fill="none" stroke="#{color}" stroke-width="1.6"/>)
        next if lists.size == 1

        legend_y = top + (index * legend_row)
        legend_x = left + plot_w + 14
        parts << %(<line x1="#{legend_x}" y1="#{legend_y}" x2="#{legend_x + 14}" y2="#{legend_y}" stroke="#{color}" stroke-width="2"/>)
        parts << %(<text x="#{legend_x + 18}" y="#{legend_y + 4}" class="legend">#{escape(item[:name])}</text>)
      end
      wrap(width, height, parts)
    end

    def bars_svg(items, title)
      top = title ? 34 : 16
      bottom = 28
      left = 108
      right = 16
      row_h = 22
      width = 640
      height = top + (items.size * row_h) + bottom
      plot_w = width - left - right
      peak = items.map { |item| item[:value].abs }.max
      peak = 1.0 if peak.nil? || peak < 1e-12

      parts = frame(width, height, title)
      parts << %(<line x1="#{left}" y1="#{top}" x2="#{left}" y2="#{top + (items.size * row_h)}" class="axis"/>)
      items.each_with_index do |item, index|
        y = top + (index * row_h) + 4
        bar_w = item[:value].abs / peak * plot_w
        color = item[:value].negative? ? "#d62728" : "#1f77b4"
        parts << %(<text x="#{left - 8}" y="#{y + 12}" text-anchor="end" class="legend">#{escape(item[:label])}</text>)
        parts << %(<rect x="#{left}" y="#{y}" width="#{round(bar_w)}" height="14" fill="#{color}"/>)
        parts << %(<text x="#{left + bar_w + 4}" y="#{y + 12}" class="tick">#{format_tick(item[:value])}</text>)
      end
      wrap(width, height, parts)
    end

    def frame(width, height, title)
      parts = [%(<rect width="#{width}" height="#{height}" fill="#fff"/>)]
      parts << %(<text x="16" y="22" class="title">#{escape(title)}</text>) if title
      parts
    end

    def wrap(width, height, parts)
      <<~SVG
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" width="#{width}" height="#{height}" viewBox="0 0 #{width} #{height}">
        <style>text{font-family:sans-serif}.title{font-size:14px;fill:#222}.tick,.legend{font-size:11px;fill:#333}.grid{stroke:#ececec}.axis{stroke:#444}</style>
        #{parts.join("\n")}
        </svg>
      SVG
    end

    def padded_range(values)
      min = values.min
      max = values.max
      min = [min, 0.0].min
      max = [max, 0.0].max
      return [min - 1.0, max + 1.0] if (max - min).abs < 1e-9

      pad = (max - min) * 0.08
      [min - pad, max + pad]
    end

    def format_tick(value)
      format("%.2f", value)
    end

    def round(value)
      format("%.2f", value)
    end

    def escape(text)
      text.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
    end
  end
end
