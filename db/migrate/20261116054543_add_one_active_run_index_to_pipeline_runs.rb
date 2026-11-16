class AddOneActiveRunIndexToPipelineRuns < ActiveRecord::Migration[8.1]
  # At most one scoring run and one drafting run can be "running" at once, enforced by the database,
  # so a double click (or a click during a command-line run) can never spend twice. Batches are exempt:
  # they intentionally stay "running" until collected.
  def change
    add_index :pipeline_runs, :kind, unique: true, where: "status = 'running' AND kind IN ('score', 'draft')",
                                     name: "index_pipeline_runs_one_active_per_kind"
  end
end
