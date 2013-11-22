#! encoding: utf-8
module GoogleContactsSyncPlugin
  module UserPatch
    extend ActiveSupport::Concern
    included do
      before_save :set_to_google_contacts_sync
      after_save :run_google_sync, if: ->(o) {o.go_sync }
      cattr_accessor :no_set_google_sync
      attr_accessor :old_attributes
      attr_accessor :go_sync
    end

    private
      def set_to_google_contacts_sync
        if (User.no_set_google_sync.nil? || (! User.no_set_google_sync.include?(self.id)))
          #check change attributes
          changed = false
          [:address, :birthday, :department, :job_title, :middlename, :firstname, :lastname, :email, :skype, :phones, :avatar_id].each do |attr|
            changed = changed_attr(attr)
            if defined?(IS_DEBUG) && IS_DEBUG
              if changed
                puts "CHANGED ATTR IS #{attr}"
              else
                puts "NO CHANGE ATTR IS #{attr}"
              end
            end
            break if changed
          end
          if changed
            self.go_sync = true
            self.must_google_sync = true
          end
        end
      end

      def run_google_sync
        puts "RUN, id is #{self.id}" if defined?(IS_DEBUG) && IS_DEBUG
        if (User.no_set_google_sync.nil? || (! User.no_set_google_sync.include?(self.id))) && Setting[:plugin_redmine_google_contacts_sync] && (Setting[:plugin_redmine_google_contacts_sync][:sync_after_save].to_i == 1)
          UserGoogleContact.sync_all!
        end
      end

      def changed_attr(attr)
        if self.id
          new_val = self.attributes.try(:[],attr.to_s)
          unless self.old_attributes
            @old_attributes = User.where(:id=>self.id).first.try(:attributes)
          end
          (new_val != @old_attributes.try(:[], attr.to_s))
        else
          true
        end
      end

  end
end