class Api::V1::ProjectsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_project, only: %i[show update destroy]

  def index
    projects = policy_scope(Project).order(created_at: :desc)
    render json: projects  end

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
      render json: { errors: @project.errors.full_messages }, status: :unprocessable_content
    end
  end

  def update
    authorize @project
    if @project.update(project_params)
      render json: @project
    else
      render json: { errors: @project.errors.full_messages }, status: :unprocessable_content
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
