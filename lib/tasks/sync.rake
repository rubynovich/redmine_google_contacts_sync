namespace :google_contacts_sync do
  desc 'Sync all google contacts'
  task :all => :environment do
    UserGoogleContact.auth!
    UserGoogleContact.sync_all!(:force=>true)
  end

  desc 'Sync must update google contacts'
  task :cron => :environment do
    UserGoogleContact.auth!
    UserGoogleContact.sync_all!
  end

  desc 'Create group'
  task :create_group => :environment do
    UserGoogleContact.auth!
    unless UserGoogleContact.group_exists?
      UserGoogleContact.create_group!
    end
  end

  desc 'Init all contacts'
  task :destroy_all => :environment do
    Setting[:plugin_redmine_google_contacts_sync][:sync_after_save] = 0 if Setting[:plugin_redmine_google_contacts_sync]
    UserGoogleContact.auth!
    gc = UserGoogleContact.google_contacts
    gc.all.each do |contact|
      #UserGoogleContact.update_attribute(:google_contact_id, File.basename(contact.id))
    end
    #UserGoogleContact.clear_google_contacts!
    #UserGoogleContact.update_all(["google_contact_id = ?", nil])
  end

  desc 'Destroy all contacts'
  task :destroy_all => :environment do
    UserGoogleContact.auth!
    UserGoogleContact.clear_google_contacts!
    UserGoogleContact.update_all(["google_contact_id = ?", nil])
  end
end
