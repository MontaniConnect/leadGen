class CreatePipelineRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :pipeline_runs do |t|
      t.string :kind, null: false
      t.string :status, null: false, default: "running"
      t.string :halted_reason
      t.datetime :started_at, null: false
      t.datetime :finished_at
      t.timestamps
    end
  end
end
