# First-run setup: create the first admin from the browser (FirstRunSetup). Gone once any user exists.
class SetupsController < ApplicationController
  allow_unauthenticated_access
  before_action :require_setup_needed
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to setup_path, alert: I18n.t("flash.rate_limited") }

  def show
    if FirstRunSetup.valid_token?(params[:token])
      @user = User.new
    else
      FirstRunSetup.announce
      render :locked
    end
  end

  def create
    return redirect_to(setup_path) unless FirstRunSetup.valid_token?(params[:token])

    @user = FirstRunSetup.create_admin(params.expect(user: [ :email_address, :password, :password_confirmation ]).to_h)
    return redirect_to(new_session_path, alert: t("flash.setup.already_done")) if @user.nil?

    if @user.persisted?
      start_new_session_for @user
      redirect_to root_path, notice: t("flash.setup.done")
    else
      render :show, status: :unprocessable_entity
    end
  end

  private
    def require_setup_needed
      redirect_to new_session_path unless FirstRunSetup.needed?
    end
end
