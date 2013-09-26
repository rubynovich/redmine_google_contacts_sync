class UserGoogleContact < Person
  unloadable

  cattr_accessor :google_contacts
  cattr_accessor :google_group_id
  cattr_accessor :google_group_uri
  cattr_accessor :google_group_title
  #UserGoogleContact.auth!

  scope :must_update, lambda{ where(:must_google_sync => true).where(["users.last_google_sync_at <= ?", (Time.now - Setting[:plugin_redmine_google_contacts_sync][:minimal_interval_for_sync].to_i.seconds) ]) }


  def self.auth!
    self.check_settings!
    unless self.google_contacts.present? || Setting[:plugin_redmine_google_contacts_sync][:account_login].blank? || Setting[:plugin_redmine_google_contacts_sync][:account_password].blank?
      begin
        self.google_contacts = GoogleContacts::Auth::UserLogin.new(Setting[:plugin_redmine_google_contacts_sync][:account_login], Setting[:plugin_redmine_google_contacts_sync][:account_password]).google_contacts
      rescue
      end
    end
    self.google_contacts
  end

  def self.sync_all!
    self.auth!
    self.create_group! unless self.group_exists?
    self.must_update.each do |user_google_contact|
      user_google_contact.sync
    end
  end

  def self.google_group_id
    if (@@google_group_id.nil? && Setting[:plugin_redmine_google_contacts_sync][:google_group_title].present?) || ((@@google_group_title != Setting[:plugin_redmine_google_contacts_sync][:google_group_title]) && Setting[:plugin_redmine_google_contacts_sync][:google_group_title].present?)
      self.check_settings!
      self.google_contacts.all(:api_type => :groups).each do |google_group|
        if google_group.title.to_s.mb_chars.downcase == Setting[:plugin_redmine_google_contacts_sync][:google_group_title].to_s.mb_chars.downcase
          @@google_group_uri = google_group.id
          @@google_group_id = File.basename(google_group.id)
          @@google_group_title = google_group.title
          break
        end
      end
      if @@google_group_id.nil?
        self.create_group!
      end
    end
    if Setting[:plugin_redmine_google_contacts_sync][:google_group_title].blank?
      @@google_group_uri
      @@google_group_id = nil
      @@google_group_title = ""
    end
    @@google_group_id
  end


  def self.group_exists?
    self.google_group_id.present? && self.google_contacts.get(@@google_group_id, :api_type => :groups).present?
  end

  def self.create_group!
    group = GoogleContacts::Element.new
    group.category = "group"
    group.title = Setting[:plugin_redmine_google_contacts_sync][:google_group_title]
    group = self.google_contacts.create!(group)
    @@google_group_id = File.basename(group.id)
    @@google_group_uri = group.id
    @@google_group_title = group.title
  end

  def sync
    gc = self.class.google_contacts
    if self.google_contact_id.present?
      contact = gc.get(self.google_contact_id)
    else
      contact = GoogleContacts::Element.new
    end
    contact.category = "contact"

    contact.title = self.name

    self.no_set_google_sync = true
    self.must_google_sync = false
    self.last_google_sync_at = Time.now
    self.save
  end

  private
  def self.check_settings!
    if Setting[:plugin_redmine_google_contacts_sync] === false
      raise t(:setup_settings_first)
    end
    #if self.google_contacts.nil?
    #  self.auth!
    #end
  end


end
