# frozen_string_literal: true

require "logger"
require "fileutils"

module SnailNetwork
  # Схема топологии в SVG. Раскладка силовая, без Graphviz и без PNG:
  # файл открывается браузером. На плотных графах подписи весов не ставятся,
  # иначе они закрывают рёбра. Переворот знака остаётся красным.
  class Visualizer
    NODE_RADIUS = 14

    def initialize(logger: nil)
      @logger = logger || Logger.new($stdout)
    end

    # @param network [SnailNetwork]
    # @param filename [String] .svg; суффикс .png заменяется на .svg
    # @return [Boolean]
    def visualize(network, filename)
      path = filename.sub(/\.png\z/i, ".svg")
      path += ".svg" unless path.downcase.end_with?(".svg")
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, render(network))
      @logger.info("Схема сохранена в #{path}")
      true
    end

    def render(network)
      positions = place(network)
      width = 640
      height = 480
      parts = [%(<rect width="#{width}" height="#{height}" fill="#fff"/>)]
      parts << %(<style>text{font-family:sans-serif;font-size:11px;fill:#222}</style>)
      directed = network.synapses.to_h { |synapse| [[synapse.source.index, synapse.target.index], true] }

      network.synapses.each do |synapse|
        source = synapse.source.index
        target = synapse.target.index
        # Знак изгиба не переворачиваем: у встречного ребра направление
        # уже противоположное, и перпендикуляр сам уходит на другую сторону.
        bend = directed[[target, source]] ? 18 : 0
        parts << edge_svg(positions[source], positions[target], synapse, bend, network.synapses.size <= 24)
      end

      network.neurons.each do |neuron|
        x, y = positions[neuron.index]
        parts << %(<circle cx="#{fmt(x)}" cy="#{fmt(y)}" r="#{NODE_RADIUS}" fill="#{node_color(network, neuron.index)}" stroke="#444"/>)
        parts << %(<text x="#{fmt(x)}" y="#{fmt(y + 4)}" text-anchor="middle">#{neuron.index}</text>)
      end

      <<~SVG
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" width="#{width}" height="#{height}" viewBox="0 0 #{width} #{height}">
        #{parts.join("\n")}
        </svg>
      SVG
    end

    private

    def place(network)
      count = network.neurons.size
      positions = Array.new(count) do |index|
        angle = 2 * Math::PI * index / count
        [Math.cos(angle), Math.sin(angle)]
      end
      edges = network.synapses.map { |synapse| [synapse.source.index, synapse.target.index] }

      90.times do
        force = Array.new(count) { [0.0, 0.0] }
        count.times do |left|
          (left + 1).upto(count - 1) do |right|
            dx = positions[left][0] - positions[right][0]
            dy = positions[left][1] - positions[right][1]
            distance = Math.hypot(dx, dy)
            distance = 0.05 if distance < 0.05
            push = 0.8 / (distance * distance)
            force[left][0] += dx / distance * push
            force[left][1] += dy / distance * push
            force[right][0] -= dx / distance * push
            force[right][1] -= dy / distance * push
          end
        end
        edges.each do |source, target|
          dx = positions[target][0] - positions[source][0]
          dy = positions[target][1] - positions[source][1]
          distance = Math.hypot(dx, dy)
          distance = 0.05 if distance < 0.05
          pull = distance * 0.08
          force[source][0] += dx / distance * pull
          force[source][1] += dy / distance * pull
          force[target][0] -= dx / distance * pull
          force[target][1] -= dy / distance * pull
        end
        count.times do |index|
          positions[index][0] += force[index][0].clamp(-0.4, 0.4)
          positions[index][1] += force[index][1].clamp(-0.4, 0.4)
        end
      end

      xs = positions.map(&:first)
      ys = positions.map(&:last)
      min_x, max_x = xs.minmax
      min_y, max_y = ys.minmax
      span = [max_x - min_x, max_y - min_y, 1e-6].max
      positions.map do |x, y|
        [
          48 + ((x - min_x) / span) * 544,
          40 + ((y - min_y) / span) * 400
        ]
      end
    end

    def edge_svg(from, to, synapse, bend, labeled)
      sx, sy, mx, my, ex, ey = curve(from, to, bend)
      color = synapse.flip_sign ? "#d62728" : "#444"
      path = %(<path d="M #{fmt(sx)} #{fmt(sy)} Q #{fmt(mx)} #{fmt(my)} #{fmt(ex)} #{fmt(ey)}" fill="none" stroke="#{color}" stroke-width="1.2"/>)
      head = arrow(mx, my, ex, ey, color)
      return path + head unless labeled

      label = synapse.flip_sign ? format("−%.2f", synapse.weight.abs) : format("%.2f", synapse.weight)
      text = %(<text x="#{fmt(mx)}" y="#{fmt(my - 4)}" text-anchor="middle" fill="#{color}">#{label}</text>)
      path + head + text
    end

    def curve(from, to, bend)
      dx = to[0] - from[0]
      dy = to[1] - from[1]
      length = Math.hypot(dx, dy)
      length = 1.0 if length < 1.0
      ux = dx / length
      uy = dy / length
      sx = from[0] + (ux * NODE_RADIUS)
      sy = from[1] + (uy * NODE_RADIUS)
      ex = to[0] - (ux * NODE_RADIUS)
      ey = to[1] - (uy * NODE_RADIUS)
      mx = ((sx + ex) / 2.0) - (uy * bend)
      my = ((sy + ey) / 2.0) + (ux * bend)
      [sx, sy, mx, my, ex, ey]
    end

    def arrow(mx, my, ex, ey, color)
      dx = ex - mx
      dy = ey - my
      length = Math.hypot(dx, dy)
      length = 1.0 if length < 1.0
      ux = dx / length
      uy = dy / length
      left_x = ex - (ux * 8) + (uy * 3.5)
      left_y = ey - (uy * 8) - (ux * 3.5)
      right_x = ex - (ux * 8) - (uy * 3.5)
      right_y = ey - (uy * 8) + (ux * 3.5)
      %(<polygon points="#{fmt(ex)},#{fmt(ey)} #{fmt(left_x)},#{fmt(left_y)} #{fmt(right_x)},#{fmt(right_y)}" fill="#{color}"/>)
    end

    def node_color(network, index)
      input = network.input_indices.include?(index)
      output = network.output_indices.include?(index)
      return "#fee391" if input && output
      return "#c6dbef" if input
      return "#c7e9c0" if output

      "#fff"
    end

    def fmt(value)
      format("%.1f", value)
    end
  end
end
