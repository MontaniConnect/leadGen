# The pilot: a small, reproducible slice of the real export, run through the whole flow by hand
# before committing to all rows. The slice is remembered in the settings table as pilot.company_ids.
module Pilot
  def self.scope
    Company.where(id: Array(Setting.get("pilot.company_ids")))
  end
end
