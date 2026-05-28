# frozen_string_literal: true

module Api
  class ApplicationController < ActionController::API
    include ActionView::Rendering
    include ActionController::ImplicitRender
    include JsonErrorRenderable
  end
end
