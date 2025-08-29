class Api::V1::ProjectsController < ApplicationController
  include Sortable
  include Filterable

  before_action :set_project, only: %i[show update destroy]

  def index
    scope = policy_scope(Project)
    scope = apply_query(scope, on: "title")
    scope = apply_sort(
      scope,
      allowed: %w[created_at updated_at title],
      default: "created_at",
      dir_default: "desc"
    )

    page = params[:page].to_i
    per  = params[:per].to_i
    page = 1   if page <= 0
    per  = 20  if per <= 0
    per  = 100 if per > 100

    @pagy, records = pagy(scope, items: per, page: page)

    render json: {
      data: ActiveModelSerializers::SerializableResource.new(records, each_serializer: ProjectSerializer),
      meta: {
        page:  @pagy.page,
        pages: @pagy.pages,
        count: @pagy.count,
        per:   @pagy.items
      }
    }
  end

  def show
    authorize @project
    render json: @project
  end

  def create
    @project = current_user.projects.new(project_params)
    authorize @project
    if @project.save
      render json: @project, status: :created
    else
      render_error("validation_error", @project.errors.full_messages, status: :unprocessable_entity)
    end
  end

  def update
    authorize @project
    if @project.update(project_params)
      render json: @project
    else
      render_error("validation_error", @project.errors.full_messages, status: :unprocessable_entity)
    end
  end

  def destroy
    authorize @project
    @project.destroy!
    head :no_content
  end

  private

  def set_project
    @project = policy_scope(Project).find(params[:id])
  end

  def project_params
    params.require(:project).permit(:title)
  end
end
