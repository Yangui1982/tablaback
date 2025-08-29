class Api::V1::HealthController < ApplicationController
  skip_before_action :authenticate_user!
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  def show
    db_ok    = ActiveRecord::Base.connection.active? rescue false
    redis_ok = (Redis.new.ping == "PONG") rescue false
    storage_ok = ActiveStorage::Blob.service.respond_to?(:bucket) || ActiveStorage::Blob.service.present? rescue false
    render json: { ok: db_ok && redis_ok && storage_ok, db: db_ok, redis: redis_ok, storage: storage_ok }
  end
end
