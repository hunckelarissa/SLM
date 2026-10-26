# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Обучение" do
  it "не ухудшает лучшую особь эволюционного поиска" do
    network = SnailNetwork::Topologies::Ring.new(
      seed: 3,
      population_size: 5,
      mutation_rate: 0.4,
      settle_steps: 10,
      log: false
    )
    inputs, targets = SnailNetwork::Tasks.parity_bipolar(2, 2)
    stats = network.train(inputs, targets, epochs: 6)

    expect(stats[:history].size).to eq(6)
    expect(stats[:final_mse]).to eq(stats[:history].last)
    expect(stats[:history].each_cons(2).all? { |previous, current| current <= previous + 1e-12 }).to be true
  end

  it "снижает ошибку линии задержки обратным проходом по времени" do
    episodes = SnailNetwork::Tasks.shift_episodes(delay: 3)
    network = SnailNetwork::Applications::LearnedDelay.build
    before = network.sequence_mse(episodes)
    stats = network.train_sequence(episodes, epochs: 15, learning_rate: 0.25)

    expect(stats[:history].size).to eq(15)
    expect(stats[:final_mse]).to be < before
    expect { network.sequence_mse([]) }.to raise_error(ArgumentError, /эпизод/)
  end

  it "выключает прямой штраф на кадрах с нулевым весом маски" do
    episodes = SnailNetwork::Tasks.shift_episodes(delay: 3)
    network = SnailNetwork::Applications::LearnedDelay.build

    expect(network.sequence_mse(episodes, mask: [0, 0, 0, 0])).to eq(0.0)
    expect { network.sequence_mse(episodes, mask: [1, 0]) }.to raise_error(ArgumentError, /Маска длины/)
  end

  it "отделяет высоту цели от амплитуды импульса" do
    frames, targets = SnailNetwork::Tasks.impulse(delay: 3, amplitude: 1.0, peak: 0.5)

    expect(frames[0]).to eq([1.0])
    expect(targets[3]).to eq([0.5])
    expect(targets[0, 3]).to eq([[0.0], [0.0], [0.0]])

    longer, later = SnailNetwork::Tasks.impulse(delay: 3, amplitude: 1.0, tail: 2)
    expect(longer.size).to eq(6)
    expect(later[3]).to eq([1.0])
    expect(later[4..]).to eq([[0.0], [0.0]])
    expect { SnailNetwork::Tasks.impulse(delay: 3, amplitude: 1.0, tail: -1) }.to raise_error(ArgumentError, /tail/)
  end

  it "учит удержанный вход обратным проходом сквозь такты" do
    network = SnailNetwork::Topologies::Ring.new(
      size: 6, input_indices: [0], output_indices: [3],
      activation: :tanh, settle_steps: 4, seed: 1, log: false
    )
    inputs = [[0.0], [0.5], [-0.5]]
    before = network.mean_squared_error(inputs, inputs)
    stats = network.train_settled(inputs, inputs, epochs: 40, learning_rate: 0.3)

    expect(stats[:history].size).to eq(40)
    expect(stats[:final_mse]).to be < before
    expect(stats[:final_mse]).to be < 0.01
    expect { network.train_settled(inputs, inputs, steps: 0) }.to raise_error(ArgumentError, /тактов/)
  end

  it "ставит два импульса через заданный промежуток" do
    frames = SnailNetwork::Tasks.paired_frames(delay: 3, gap: 2)

    expect(frames).to eq([[1.0], [0.0], [1.0], [0.0], [0.0], [0.0]])
    expect { SnailNetwork::Tasks.paired_frames(delay: 0, gap: 2) }.to raise_error(ArgumentError, /delay/)
  end

  it "даёт биполярной задаче полную таблицу без повторов" do
    inputs, targets = SnailNetwork::Tasks.parity_bipolar(2, 2)
    expect(inputs).to eq([[0.0, 0.0], [1.0, 0.0], [0.0, 1.0], [1.0, 1.0]])
    expect(targets.map(&:first)).to eq([-1.0, 1.0, 1.0, -1.0])
    expect(targets.map(&:last)).to eq([-1.0, -1.0, -1.0, 1.0])

    signed, signed_targets = SnailNetwork::Tasks.parity_bipolar(2, 2, level: :sign)
    expect(signed).to eq([[-1.0, -1.0], [1.0, -1.0], [-1.0, 1.0], [1.0, 1.0]])
    expect(signed_targets).to eq(targets)
    expect { SnailNetwork::Tasks.parity_bipolar(2, 1, level: :raw) }.to raise_error(ArgumentError, /Уровень/)
  end
end
