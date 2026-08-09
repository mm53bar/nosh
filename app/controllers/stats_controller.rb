class StatsController < ApplicationController
  def show
    render json: {
      cuisine_counts: Recipe.group(:cuisine).count,
      top_rated: Recipe.where.not(rating: nil).order(rating: :desc).limit(10).as_json(only: [ :id, :title, :rating ]),
      recent: Recipe.order(created_at: :desc).limit(10).as_json(only: [ :id, :title, :created_at ])
    }
  end
end
