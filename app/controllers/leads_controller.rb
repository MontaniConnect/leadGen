class LeadsController < ApplicationController
  helper_method :filter_params, :queue, :queue_companies, :neighbours

  def index
    @lead = queue_companies.first
    render :show
  end

  def show
    @lead = Company.preload(:evaluations, :selected_contact, :messages).find(params[:id])
    queue_companies
  end

  private

  def queue
    @queue ||= Leads::Queue.new(tier: params[:tier], status: params[:status], reply: params[:reply], batch: params[:batch])
  end

  def queue_companies
    @queue_companies ||= queue.companies
  end

  def filter_params
    queue.filters.symbolize_keys
  end

  # [previous, next] leads relative to the current one in the queue, for J/K navigation.
  def neighbours(lead)
    index = queue_companies.index(lead)
    return [ nil, queue_companies.first ] unless index

    [ index.positive? ? queue_companies[index - 1] : nil, queue_companies[index + 1] ]
  end
end
