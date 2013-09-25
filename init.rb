Redmine::Plugin.register :redmine_google_contacts_sync do
  name 'Redmine Google Contacts Sync plugin'
  author 'Maksim Koritskiy'
  description 'Synchronize corporate redmine account data to Google Contacts with account login'
  version '0.0.1'
  url 'https://bitbucket.org/mxgks/redmine_google_contacts_sync'
  author_url 'http://maksim.koritskiy.ru'
  settings :partial => 'google_contacts_sync/settings'
end


