namespace :import do
  desc "Import an Apollo accounts CSV: bin/rails import:accounts[path/to/file.csv]"
  task :accounts, [ :path ] => :environment do |_, args|
    puts Imports::Summary.new(Imports::AccountsImporter.new(args.fetch(:path)).call)
  end

  desc "Import an Apollo people CSV: bin/rails import:people[path/to/file.csv]"
  task :people, [ :path ] => :environment do |_, args|
    puts Imports::Summary.new(Imports::PeopleImporter.new(args.fetch(:path)).call)
  end

  desc "Import reply results from a sheet: bin/rails import:replies[path/to/file.csv]"
  task :replies, [ :path ] => :environment do |_, args|
    puts Imports::Summary.new(Exports::RepliesImporter.new(args.fetch(:path)).call)
  end
end
