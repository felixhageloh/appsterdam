class MembersController < ApplicationController
  allow_access(:authenticated, :only => [:edit, :update, :destroy]) { @authenticated.id == Integer(params[:id]) }
  allow_access :all, :only => [:index, :new, :create]
  allow_access :admin

  include Twitter

  def index
    @selection = Selection.new(params)
    if @selection.empty?
      unless params[:page]
        params[:started_at_page] = params[:page] = Member.random_start_page
      end
    end
    @members = Member.selection(@selection).order(:id).page(params[:page])
    respond_to do |format|
      format.js { render :partial => 'page', :content_type => 'text/html' }
      format.html
    end
  end
  
  def new
    start_token_request(:oauth_callback => create_members_url)
  end
  
  def create
    process_authorization_response do
      @member = Member.create_with_twitter_user_attributes(user_attributes)
      if @member.errors.empty?
        redirect_to edit_member_url(@member)
      else
        @member = Member.find_by_twitter_id(user_attributes['id'])
        render :exists
      end
    end
  end

  def update
    if @authenticated.admin?
      if params[:member].has_key?(:marked_as_spam)
        Member.unscoped.find(params[:id]).update_attribute(:marked_as_spam, params[:member][:marked_as_spam])
      end
      redirect_to spam_markings_url
    else
      @authenticated.update_attributes(params[:member].slice(*Member::ACCESSIBLE_ATTRS))
      redirect_to edit_member_url(@authenticated)
    end
  end

  def destroy
    @authenticated.delete
    logout
    redirect_to members_url
  end

  private

  def user_attributes
    twitter_client.info
  end
end
