# frozen_string_literal: true

class HomeController < ApplicationController
  layout "v2/application"

  def index
    return render :index if user_signed_in?

    @season_top_work = GuestTopPageService.season_top_work
    @season_works = GuestTopPageService.season_works
    @top_work = GuestTopPageService.top_work
    @works = GuestTopPageService.works
    @cover_image_work = GuestTopPageService.cover_image_work
    @activities = GuestTopPageService.activities unless browser.mobile?

    render :index_guest
  end
end
