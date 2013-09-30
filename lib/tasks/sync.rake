desc 'Sync all google contacts'
namespace :google_contacts_sync do
  task :all => :environment do
    UserGoogleContact.sync_all!(:force=>true)
  end

  task :cron => :environment do
    UserGoogleContact.sync_all!
  end

  task :destroy_all => :environment do
    UserGoogleContact.clear_google_contacts!
  end
end
