# Braitenberg — машина с двумя глазами и двумя моторами.
#
# Левый глаз возбуждает правый мотор и наоборот. Свет сбоку
# ускоряет дальний борт, и тело доворачивает к источнику.
# Это транспортное средство Брайтенберга №2 на четырёх нейронах.

module SmLab
  class Braitenberg < Network
    def initialize(name: 'Braitenberg', neuron_count: 4)
      raise ArgumentError, 'Braitenberg uses 4 neurons' unless neuron_count == 4

      super(
        name: name,
        neuron_count: 4,
        neuron_options: {
          bias: 0.15,
          slope: 1.8,
          threshold: 0.4,
          fatigue_gain: 0.015,
          fatigue_sensitivity: 0.2,
          fatigue_pull: 0.0
        },
        recover_rate: 0.1,
        homeostasis_rate: 0.0
      )
    end

    def build_topology
      # 0 левый глаз, 1 правый глаз, 2 левый мотор, 3 правый мотор.
      # Перекрёстное возбуждение и слабое торможение своей стороны.
      @weights = [
        [0.15, 0.0, 0.0, 0.0],
        [0.0, 0.15, 0.0, 0.0],
        [-1.1, 3.2, 0.15, -0.4],
        [3.2, -1.1, -0.4, 0.15]
      ]
    end
  end

  class BraitenbergVehicle
    def initialize(light: [6.0, 2.0], x: 0.0, y: 0.0, theta: Math::PI)
      @light = light
      @x = x
      @y = y
      @theta = theta
      @brain = Braitenberg.new
      @brain.build_topology
    end

    attr_reader :x, :y, :theta, :light

    def self.demo(steps: 220, plot: false)
      vehicle = new
      result = vehicle.run(steps)
      ok = result[:min_distance] < 0.8 && result[:finish] < 1.2
      plot_path = nil
      if plot
        plot_path = Plot.trail_svg(
          result[:trail],
          File.expand_path('../../plots/examples/phototaxis.svg', __dir__),
          title: 'Фототаксис: след машины и источник света',
          target: vehicle.light
        )
      end

      text = <<~TEXT
        Фототаксис, машина Брайтенберга
          свет #{format_point(vehicle.light)}, старт в (0, 0), курс развёрнут от света
          дистанция #{result[:start].round(2)} → #{result[:finish].round(2)}, минимум #{result[:min_distance].round(2)}
          финиш #{format_point([result[:x], result[:y]])}
          #{ok ? 'дошла до света' : 'свет потерян'}
      TEXT
      result.merge(ok: ok, title: 'Фототаксис', text: text, plot: plot_path)
    end

    def run(steps)
      start = distance
      min_distance = start
      trail = [[@x, @y]]
      steps.times do
        left, right = eyes
        # В темноте левый борт чуть сильнее: машина ищет дугой.
        # Как только глаза видят свет, крен снимается и рулит перекрёст.
        search = (left + right) < 0.45 ? 0.7 : 0.0
        @brain.step!(external_input: [left, right, 0.1 + search, 0.1], homeostasis: false)
        left_motor = @brain.neurons[2].activation
        right_motor = @brain.neurons[3].activation
        gap = distance
        arrive = gap / (gap + 0.55)
        turn = gap < 0.9 ? 0.35 : 1.15
        speed = (left_motor + right_motor) * 0.18 * arrive
        @theta += (right_motor - left_motor) * turn
        @x += Math.cos(@theta) * speed
        @y += Math.sin(@theta) * speed
        min_distance = [min_distance, distance].min
        trail << [@x, @y]
      end
      {
        start: start,
        finish: distance,
        min_distance: min_distance,
        trail: trail,
        x: @x,
        y: @y,
        theta: @theta
      }
    end

    def eyes
      [eye_signal(0.45), eye_signal(-0.45)]
    end

    def eye_signal(offset)
      eye_x = @x + Math.cos(@theta + offset) * 0.25
      eye_y = @y + Math.sin(@theta + offset) * 0.25
      dx = @light[0] - eye_x
      dy = @light[1] - eye_y
      dist = Math.hypot(dx, dy)
      return 4.0 if dist < 1e-6

      facing = (dx * Math.cos(@theta + offset) + dy * Math.sin(@theta + offset)) / dist
      facing = 0.0 if facing.negative?
      (4.0 * facing) / (0.35 + dist)
    end

    def distance
      Math.hypot(@light[0] - @x, @light[1] - @y)
    end

    def self.format_point(point)
      "(#{point[0].round(2)}, #{point[1].round(2)})"
    end
  end
end
