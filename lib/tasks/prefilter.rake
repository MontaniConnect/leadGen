namespace :prefilter do
  desc "Run the prefilter over all companies and print the counts"
  task run: :environment do
    tally = Prefilter::Runner.new.call
    puts "pass: #{tally['pass']}  fail: #{tally['fail']}"
    Prefilter::Report.new.reason_counts.each { |reason, count| puts "  #{reason}: #{count}" }
  end
end
