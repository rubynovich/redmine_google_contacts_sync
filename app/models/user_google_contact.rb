# coding: UTF-8
class UserGoogleContact < Person
  unloadable

  cattr_accessor :google_contacts
  cattr_accessor :google_group_id
  cattr_accessor :google_group_uri
  cattr_accessor :google_group_title

  scope :must_update, lambda{ where(:must_google_sync => true).where("login <> ''").where(:status=>[1,3]).where(["users.last_google_sync_at <= ?", (Time.now - Setting[:plugin_redmine_google_contacts_sync][:minimal_interval_for_sync].to_i.seconds) ]) }
  scope :by_ids, lambda{|ids| where(:id=>ids)}

  def self.auth!(args={})
    args_gc = {}
    [:email].each do |key|
      args_gc[key] = args[key].dup if args[key].present?
      args.delete(key)
    end

    self.check_settings!
    unless self.google_contacts.present? || Setting[:plugin_redmine_google_contacts_sync][:account_login].blank? || Setting[:plugin_redmine_google_contacts_sync][:account_password].blank?
      begin
        self.google_contacts = GoogleContacts::Auth::UserLogin.new(Setting[:plugin_redmine_google_contacts_sync][:account_login], Setting[:plugin_redmine_google_contacts_sync][:account_password], args).google_contacts(args_gc)
      rescue
      end
    end
    self.google_contacts
  end


  def self.sync_all!(options={})
    principal = Principal.where(id: Setting[:plugin_redmine_google_contacts_sync][:group].to_i).first
    if principal.try(:type) == 'Group'
      ids = principal.user_ids
    elsif principal.try(:type) == 'User'
      ids = [principal.id]
    else
      ids = []
    end
    self.auth!
    self.create_group! unless self.group_exists?
    (options[:force] ? self.by_ids(ids).all : self.by_ids(ids).must_update).each do |user_google_contact|
      begin
        user_google_contact.sync!
      rescue => e
        Rails.logger.info "Error google sync at #{Time.now.to_s} - #{user_google_contact.inspect} - #{e.inspect} "
      end
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
      @@google_group_uri = nil
      @@google_group_id = nil
      @@google_group_title = ""
    end
    @@google_group_id
  end


  def self.group_exists?
    self.google_group_id.present? && self.google_contacts.get(self.google_group_id, :api_type => :groups).present?
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

  def self.clear_google_contacts!
    self.auth!
    self.google_group_id
    gc = self.google_contacts
    list = gc.all
    list.each do |contact|
      if (contact.group_ids.is_a?(Array) && contact.group_ids.include?(self.google_group_uri)) || (self.google_group_uri.nil? && contact.group_id = nil)
        contact.delete
      end
    end
    gc.batch!(list)
  end

  def sync!(options={})
    self.class.auth!
    self.google_group_id
    gc = self.class.google_contacts
    if self.google_contact_id.present?
      contact = gc.get(self.google_contact_id)
      action = self.status == 1 ? :update : :destroy
    end
    if contact.nil? && (self.status == 1)
      contact = GoogleContacts::Element.new
      action = :create
    end
    if contact.present?
      contact.category = "contact"
      User.no_set_google_sync ||= []
      User.no_set_google_sync << self.id
      self.must_google_sync = false
      self.last_google_sync_at = Time.now
      if [:create, :update].include?(action)
        contact.data = {}
        contact.title = self.name
        contact.data["gd:name"] = {
            #"gd:fullName" => self.name,
            "gd:givenName" => self.firstname,
            "gd:familyName" => self.lastname
        }

        if self.address.present?
          city = 'Москва' if self.address.gsub(/\s/,'').mb_chars.downcase =~ /москва/
          city = 'Санкт-Петербург' if self.address.gsub(/\s/,'').mb_chars.downcase =~ /петербург/
          item = {"gd:formattedAddress"=>self.address, "@rel"=>"http://schemas.google.com/g/2005#work"}
          item["gd:city"=>city] if city.present?
          contact.data["gd:structuredPostalAddress"] = [item]
        end


        contact.birthday = self.birthday if self.birthday.present?


        contact.add_org_info(self.department.try(:name), self.job_title)
        contact.etag = '*'
        contact.data["gd:name"]["gd:additionalName"] = self.middlename unless self.middlename.nil? || (self.middlename == '')
        contact.group_ids = [ self.google_group_uri ] if self.google_group_id.present? && action == :create
        contact.add_email(self.email, :work, :primary=>true)
        contact.add_im(self.email, :google_talk)
        contact.add_im(self.skype, :skype) if self.skype.present?
        self.phones.each do |phone|
          phone.gsub!(/^8/,'+7')
          contact.add_phone(phone, (phone.gsub(/\D/,'').size == 11) && (phone.gsub(/\D/,'') =~ /^79/) ? :mobile : :work )
        end
      end



      if action == :create
        contact = gc.create!(contact)
        self.google_contact_id = File.basename(contact.id)
      elsif action == :update
        gc.update!(contact, URI("https://www.google.com/m8/feeds/contacts/default/full/#{self.google_contact_id}"), :put)
      elsif action == :destroy
        gc.delete!(contact)
        self.google_contact_id = nil
      end
      self.must_google_sync = false
      if self.save
        User.no_set_google_sync.delete(self.id) if User.no_set_google_sync.is_a?(Array)
      else
        if self.errors.count > 0
          puts self.errors.inspect
        end
      end
      if self.avatar && [:create, :update].include?(action)
        gc.update_photo!(contact, self.avatar.diskfile) if File.exist?(self.avatar.diskfile)
      elsif gc.get_photo(contact) || action == :destroy
        gc.delete_photo!(contact)
      end
    end
  end

  private
  def self.check_settings!
    if Setting[:plugin_redmine_google_contacts_sync] === false
      raise t(:setup_settings_first)
    end
  end


end
