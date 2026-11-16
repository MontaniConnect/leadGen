# The "look for contacts on their websites" button on the prefilter page.
class ContactResearchController < ApplicationController
  RECHECK_AFTER = 30.days

  def create
    ids = lookup_scope.pluck(:id)
    ids.each { |id| FindContactJob.perform_later(id) }
    notice = if ids.empty?
      "Nothing to look up: every company that passed already has a contact or was checked recently."
    else
      "Looking for contacts on #{ids.size} company #{'website'.pluralize(ids.size)}. This takes a few seconds each: refresh this page in a minute."
    end
    redirect_to dashboard_path, notice: notice
  end

  def self.lookup_scope
    Company.prefilter_passed.where.not(contact_status: "selected").where.not(domain: nil)
           .where("contact_researched_at IS NULL OR contact_researched_at < ?", RECHECK_AFTER.ago)
  end

  private

  def lookup_scope = self.class.lookup_scope
end
