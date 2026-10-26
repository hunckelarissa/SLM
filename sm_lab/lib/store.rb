# Store — один SQLite-журнал для прогонов и покадровых состояний.
# Раньше runner и generate_data писали в разные файлы и разные таблицы.

require 'fileutils'
require 'sqlite3'

module SmLab
  class Store
    def self.default_path
      File.expand_path('../data/smlab.db', __dir__)
    end

    def initialize(path = self.class.default_path)
      @path = path
      FileUtils.mkdir_p(File.dirname(path))
      @db = SQLite3::Database.new(path)
      migrate
    end

    attr_reader :path

    def clear!
      @db.execute('DELETE FROM samples')
      @db.execute('DELETE FROM runs')
    end

    def record_run(name:, neuron_count:, input_type:, frames:)
      raise ArgumentError, 'nothing to record' if frames.nil? || frames.empty?

      finals = frames.last[:state]
      activations = frames.flat_map { |frame| frame[:state].map { |item| item[:activation] } }
      avg_act = finals.sum { |item| item[:activation] }.fdiv(finals.size)
      avg_fat = finals.sum { |item| item[:fatigue] }.fdiv(finals.size)

      @db.transaction do
        @db.execute(
          'INSERT INTO runs (network_name, neuron_count, input_type, step_count, ' \
          'avg_activation_final, avg_fatigue_final, max_activation, min_activation) ' \
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
          [name, neuron_count, input_type.to_s, frames.size, avg_act, avg_fat, activations.max, activations.min]
        )
        run_id = @db.last_insert_row_id
        statement = @db.prepare(
          'INSERT INTO samples (run_id, step, neuron_id, activation, fatigue, state) VALUES (?, ?, ?, ?, ?, ?)'
        )
        frames.each do |frame|
          frame[:state].each do |item|
            statement.execute([run_id, frame[:step], item[:id], item[:activation], item[:fatigue], item[:state]])
          end
        end
        statement.close
        run_id
      end
    end

    def latest_summaries
      @db.execute(<<~SQL)
        SELECT id, network_name, neuron_count, input_type, step_count,
               avg_activation_final, avg_fatigue_final, max_activation, min_activation
        FROM runs
        WHERE id IN (SELECT MAX(id) FROM runs GROUP BY network_name)
        ORDER BY avg_activation_final DESC
      SQL
    end

    def series(run_id)
      @db.execute(<<~SQL, [run_id])
        SELECT step, AVG(activation), AVG(fatigue)
        FROM samples
        WHERE run_id = ?
        GROUP BY step
        ORDER BY step
      SQL
    end

    def activations(run_id, step)
      @db.execute(
        'SELECT activation FROM samples WHERE run_id = ? AND step = ? ORDER BY neuron_id',
        [run_id, step]
      ).flatten
    end

    def activations_for(run_id)
      @db.execute('SELECT activation FROM samples WHERE run_id = ?', [run_id]).flatten
    end

    def empty?
      @db.get_first_value('SELECT COUNT(*) FROM runs').to_i.zero?
    end

    private

    def migrate
      @db.execute(<<~SQL)
        CREATE TABLE IF NOT EXISTS runs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          network_name TEXT NOT NULL,
          neuron_count INTEGER NOT NULL,
          input_type TEXT NOT NULL,
          step_count INTEGER NOT NULL,
          avg_activation_final REAL,
          avg_fatigue_final REAL,
          max_activation REAL,
          min_activation REAL,
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
      SQL
      @db.execute(<<~SQL)
        CREATE TABLE IF NOT EXISTS samples (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          run_id INTEGER NOT NULL,
          step INTEGER NOT NULL,
          neuron_id INTEGER NOT NULL,
          activation REAL NOT NULL,
          fatigue REAL NOT NULL,
          state TEXT
        )
      SQL
    end
  end
end
