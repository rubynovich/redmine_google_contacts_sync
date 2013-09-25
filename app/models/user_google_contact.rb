class UserGoogleContact < Person
  unloadable

  cattr_accessor :google_contacts
  cattr_accessor :google_group_id

  #UserGoogleContact.auth!

  scope :must_update, lambda{ where(:must_google_sync => true).where(["users.last_google_sync_at <= ?", (Time.now - Setting[:plugin_redmine_google_contacts_sync][:minimal_interval_for_sync].to_i.seconds) ]) }

  def self.google_contact_get(id, options={})
    self.auth!
    begin
      contact = self.google_contacts
    rescue Unauthorized
      self.google_contacts = nil
      self.get(id, options={})
    end
    contact
  end

  def self.auth!
    if self.google_contacts
      #check session
      begin
        self.google_contacts.get('test_auth')
      rescue Unauthorized
        self.google_contacts = nil
      rescue InvalidRequest
        return self.google_contacts
      end
    end
    unless (! self.google_contacts) || Setting[:plugin_redmine_google_contacts_sync][:account_login].blank? || Setting[:plugin_redmine_google_contacts_sync][:account_password].blank?
      begin
        self.google_contacts = GoogleContacts::Auth::UserLogin.new(Setting[:plugin_redmine_google_contacts_sync][:account_login], Setting[:plugin_redmine_google_contacts_sync][:account_password]).google_contacts
      rescue
      end
    end
    self.google_contacts
  end

  def self.sync_all!
    self.auth!
    self.must_update.each do |user_google_contact|
      user_google_contact.sync
    end
  end

  def self.google_group_id
    self.class.google_contacts.all(:api_type => :groups).each do ||
  end

  def sync
    gc = self.class.google_contacts
    if self.google_contact_id.present?
      contact = gc.get(self.google_contact_id)
    else
      contact = GoogleContacts::Element.new
    end



    self.no_set_google_sync = true
    self.must_google_sync = false
    self.last_google_sync_at = Time.now
    self.save
  end




end
