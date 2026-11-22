# Language and theme. Saved in the user's profile, and in a cookie for guests.
class PreferencesController < ApplicationController
  def update
    changes = {}
    changes[:locale] = params[:locale] if I18n.available_locales.map(&:to_s).include?(params[:locale])
    changes[:theme] = params[:theme] if User::THEMES.include?(params[:theme])

    changes.each { |key, value| cookies.permanent[key] = value }
    current_user&.update(changes) if changes.any?

    redirect_back fallback_location: root_path
  end
end
