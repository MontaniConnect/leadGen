# Builds a large export in the background.
class ExportJob < ApplicationJob
  queue_as :default
  discard_on ActiveRecord::RecordNotFound

  def perform(export_id, runner: Exports::Runner.new)
    runner.call(Export.find(export_id))
  end
end
