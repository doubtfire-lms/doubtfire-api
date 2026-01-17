class NotificationsApi < Grape::API
  helpers AuthenticationHelpers
  helpers AuthorisationHelpers

  before do
    authenticated?
  end

  desc 'Get current user notifications'
  get '/notifications' do
    notifications = current_user.notifications.order(created_at: :desc)
    # Return array of notifications as JSON (id and message only)
    notifications.as_json(only: [:id, :message])
  end

  desc 'Delete user notification by id'
  delete '/notifications/:id' do
    notification = current_user.notifications.find_by(id: params[:id])
    error!({ error: 'Notification not found' }, 404) unless notification
    notification.destroy
    status 204
  end

  desc 'Delete all user notifications'
  delete '/notifications' do
    current_user.notifications.delete_all
    status 204
  end
end
