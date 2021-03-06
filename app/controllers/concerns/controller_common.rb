# frozen_string_literal: true

module ControllerCommon
  extend ActiveSupport::Concern

  included do
    helper_method :render_jb, :locale_ja?, :locale_en?, :local_url, :discord_invite_url, :local_url_with_path,
      :localable_resources, :browser

    rescue_from ActionView::MissingTemplate do
      raise ActionController::RoutingError, "Not Found" if Rails.env.production?
      raise
    end

    if ENV.fetch("ANNICT_BASIC_AUTH") == "on"
      name = ENV.fetch("ANNICT_BASIC_AUTH_NAME")
      password = ENV.fetch("ANNICT_BASIC_AUTH_PASSWORD")
      http_basic_authenticate_with name: name, password: password
    end

    def browser
      ua = if Rails.env.production?
        request.headers["X-UA-Device"]
      else
        request.headers["User-Agent"]
      end

      @browser ||= Browser.new(ua, accept_language: request.headers["Accept-Language"])
    end

    def render_jb(path, assigns)
      ApplicationController.render("#{path}.jb", assigns: assigns)
    end

    def locale_ja?
      locale.to_s == "ja"
    end

    def locale_en?
      locale.to_s == "en"
    end

    def localable_resources(resources)
      if user_signed_in?
        localable_resources_with_own(resources)
      elsif !user_signed_in? && locale_en?
        resources.with_locale(:en)
      elsif !user_signed_in? && locale_ja?
        resources.with_locale(:ja)
      else
        resources
      end
    end

    def localable_resources_with_own(resources)
      collection = resources.with_locale(*current_user.allowed_locales)

      return resources.where(user: current_user).or(collection) if resources.column_names.include?("user_id")

      case resources.first.class.name
      when "UserlandProject"
        UserlandProject.where(id: collection.pluck(:id) + resources.merge(current_user.userland_projects).pluck(:id))
      else
        collection
      end
    end

    private

    def set_search_params
      @search = SearchService.new(params[:q])
    end

    def load_new_user
      return if user_signed_in?
      @new_user = User.new_with_session({}, session)
    end

    def redirect_to_root_domain(options = {})
      url = ENV.fetch("ANNICT_URL")
      redirect_to "#{url}#{request.path}", options
    end

    def local_url(locale: I18n.locale)
      case locale.to_s
      when "ja"
        ENV.fetch("ANNICT_JP_URL")
      else
        ENV.fetch("ANNICT_URL")
      end
    end

    def local_url_with_path(locale: I18n.locale)
      ["#{local_url(locale: locale)}#{request.path}", request.query_string].select(&:present?).join("?")
    end

    def redirect_if_unexpected_subdomain
      return unless %w(api).include?(request.subdomain)

      white_list = [
        "/sign_in",
        "/users/auth/facebook/callback",
        "/users/auth/twitter/callback",
        "/oauth/authorize"
      ]
      return if request.path.in?(white_list)

      redirect_to_root_domain(status: 301)
    end

    def switch_locale
      white_list = [
        "/users/auth/gumroad/callback"
      ]
      return if request.path.in?(white_list)

      case [request.subdomain, request.domain].select(&:present?).join(".")
      when ENV.fetch("ANNICT_DOMAIN")
        return redirect_to local_url_with_path(locale: :ja) if user_signed_in? && current_user.locale == "ja"
        I18n.locale = :en
      when ENV.fetch("ANNICT_JP_DOMAIN")
        return redirect_to local_url_with_path(locale: :en) if user_signed_in? && current_user.locale == "en"
        I18n.locale = :ja
      end
    end

    def preferred_locale
      preferred_languages = http_accept_language.user_preferred_languages
      # Chrome returns "ja", but Safari would return "ja-JP", not "ja".
      preferred_languages.any? { |lang| lang.match?(/ja/) } ? :ja : :en
    end

    def discord_invite_url
      ENV.fetch("ANNICT_DISCORD_INVITE_URL")
    end
  end
end
