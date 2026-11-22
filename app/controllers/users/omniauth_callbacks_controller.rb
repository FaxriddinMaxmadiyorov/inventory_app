module Users
  class OmniauthCallbacksController < Devise::OmniauthCallbacksController
    def google_oauth2
      authenticate_with_provider
    end

    def github
      authenticate_with_provider
    end

    def failure
      redirect_to new_user_session_path, alert: t("devise.omniauth_callbacks.failure", kind: "OAuth", reason: failure_message)
    end

    private

    def authenticate_with_provider
      user = User.from_omniauth(request.env["omniauth.auth"])

      if user&.persisted?
        sign_in_and_redirect user, event: :authentication
      else
        redirect_to new_user_session_path, alert: t("flash.oauth_failed")
      end
    end
  end
end
