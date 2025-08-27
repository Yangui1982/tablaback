class Api::V1::ProjectsController < ApplicationController
  def index
    render json: current_user.projects.order(created_at: :desc)
  end

  def show
    render json: current_user.projects.find(params[:id])
  end

  def create
    project = current_user.projects.new(project_params)
    if project.save
      render json: project, status: :created
    else
      render json: { errors: project.errors.full_messages }, status: :unprocessable_content
    end
  end

  def update
    project = current_user.projects.find(params[:id])
    if project.update(project_params)
      render json: project
    else
      render json: { errors: project.errors.full_messages }, status: :unprocessable_content
    end
  end

  def destroy
    current_user.projects.find(params[:id]).destroy!
    head :no_content
  end

  private
  def project_params
    params.require(:project).permit(:title)
  end
end
