module GoogleContactsSyncPlugin
  module UserPatch
    extend ActiveSupport::Concern
    included do
      before_save :set_to_google_contacts_sync
      after_save :run_google_sync
      attr_accessor :no_set_google_sync
    end

    private
      def set_to_google_contacts_sync
        self.must_google_sync = true unless self.no_set_google_sync
      end

      def run_google_sync
        if Setting[:plugin_redmine_google_contacts_sync] && Setting[:plugin_redmine_google_contacts_sync][:sync_after_update]
          UserGoogleContact.sync_all!
        end
      end

  end
end