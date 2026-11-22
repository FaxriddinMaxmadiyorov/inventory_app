class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception

  around_action :switch_locale
  around_action :use_browser_time_zone
  before_action :configure_permitted_parameters, if: :devise_controller?

  helper_method :current_theme, :ransack_params

  rescue_from ActiveRecord::RecordNotFound do
    respond_to do |format|
      format.html { render "shared/not_found", status: :not_found }
      format.any { head :not_found }
    end
  end

  private

  def switch_locale(&action)
    locale = current_user&.locale || cookies[:locale]
    locale = I18n.default_locale unless I18n.available_locales.map(&:to_s).include?(locale.to_s)
    I18n.with_locale(locale, &action)
  end

  # The browser reports its time zone in a cookie (see application.js), so dates
  # are shown in the visitor's local time.
  def use_browser_time_zone(&action)
    zone = ActiveSupport::TimeZone[cookies[:tz].to_s] if cookies[:tz].present?
    Time.use_zone(zone || Time.zone, &action)
  end

  def current_theme
    theme = current_user&.theme || cookies[:theme]
    User::THEMES.include?(theme) ? theme : "light"
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:name])
    devise_parameter_sanitizer.permit(:account_update, keys: [:name])
  end

  def require_admin!
    return if current_user&.admin?

    redirect_to root_path, alert: t("flash.forbidden")
  end

  def forbidden!
    respond_to do |format|
      format.html { redirect_back fallback_location: root_path, alert: t("flash.forbidden") }
      format.any { head :forbidden }
    end
  end

  # Ransack parameters (filters and sorting) from the query string, as a plain hash.
  # Anything that is not a hash, for example ?q=text typed by hand, is ignored.
  def ransack_params(key = :q)
    value = params[key]
    value.respond_to?(:to_unsafe_h) ? value.to_unsafe_h : {}
  end

  # Optimistic locking for bulk actions. Every checkbox carries "id:lock_version";
  # only records that still have the version the user saw are matched.
  # Returns [relation, number_of_requested_records].
  def versioned(scope, tokens)
    pairs = Array(tokens).map { |token| token.to_s.split(":") }
                         .select { |pair| pair.size == 2 }.map { |pair| pair.map(&:to_i) }.uniq
    return [scope.none, 0] if pairs.empty?

    table = scope.klass.arel_table
    condition = pairs.map { |id, version| table[:id].eq(id).and(table[:lock_version].eq(version)) }.reduce(:or)
    [scope.where(condition), pairs.size]
  end

  def bulk_delete_message(deleted, requested)
    message = t("flash.deleted", count: deleted)
    message += " " + t("flash.delete_conflict", count: requested - deleted) if deleted < requested
    message
  end
end
