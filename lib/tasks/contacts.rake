namespace :contacts do
  desc "Select the best contact for each prefilter-passed company"
  task select: :environment do
    tally = Contacts::Runner.new.call
    puts "selected: #{tally['selected']}  not_found (fallback queue): #{tally['not_found']}"
  end
end
