desc 'Sync all google contacts'
namespace :google_contacts_sync do
  task :all => :environment do
    UserGoogleContact.auth!
    UserGoogleContact.sync_all!(:force=>true)
  end

  task :cron => :environment do
    UserGoogleContact.auth!
    UserGoogleContact.sync_all!
  end

  task :create_group => :environment do
    UserGoogleContact.auth!
    unless UserGoogleContact.group_exists?
      UserGoogleContact.create_group!
    end
  end

  task :destroy_all => :environment do
    UserGoogleContact.auth!
    UserGoogleContact.clear_google_contacts!
  end
end
