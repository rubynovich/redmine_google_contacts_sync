module GoogleContactsSyncPlugin
  module UserPatch
    extend ActiveSupport::Concern
    included do
      before_save :set_to_google_contacts_sync
      after_save :run_google_sync
      cattr_accessor :no_set_google_sync
    end

    private
      def set_to_google_contacts_sync
        if (User.no_set_google_sync.nil? || (! User.no_set_google_sync.include?(self.id)))
          self.must_google_sync = true
        end
      end

      def run_google_sync
        if (User.no_set_google_sync.nil? || (! User.no_set_google_sync.include?(self.id))) && Setting[:plugin_redmine_google_contacts_sync] && (Setting[:plugin_redmine_google_contacts_sync][:sync_after_save].to_i == 1)
          UserGoogleContact.sync_all!
        end
      end

  end
end