class EventsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index, :show]
  def index
    @today_events = Event.where("starttime between ? and ?", DateTime.now().to_date, (DateTime.now() + 1).to_date)
    @next_events = Event.where("starttime between ? and ?", (DateTime.now() + 1).to_date, (DateTime.now() + 7).to_date)
  end

  def show
    @event = Event.find(params[:id])
    @participants = @event.users
    @participant = Participant.where(event: @event, user: current_user)[0]

    @paths = []
      route = @event.route
      @nodes = route.nodes
      @markers = []
      @nodes.each do |node|
        @markers << {
          lat: node.latitude,
          lng: node.longitude
        } if node.real
      end
      if route.form == "Circular"
        @nodes.each_with_index do |node, index|
          response = RestClient.get "https://api.mapbox.com/directions/v5/mapbox/cycling/#{@nodes[index-1].longitude},#{@nodes[index-1].latitude};#{node.longitude},#{node.latitude}?geometries=geojson&exclude=ferry&access_token=#{ENV['MAPBOX_API_KEY']}"
          repos = JSON.parse(response) # => repos is an `Array` of `Hashes`.
          @paths << (repos['routes'].first['geometry']['coordinates'])
        end
      else
        number = 1
        while number < @nodes.length do
          response = RestClient.get "https://api.mapbox.com/directions/v5/mapbox/cycling/#{@nodes[number-1].longitude},#{@nodes[number-1].latitude};#{@nodes[number].longitude},#{@nodes[number].latitude}?geometries=geojson&exclude=ferry&access_token=#{ENV['MAPBOX_API_KEY']}"
          repos = JSON.parse(response) # => repos is an `Array` of `Hashes`.
          @paths << (repos['routes'].first['geometry']['coordinates'])
          number += 1
        end
      end

  end

  def create
    params[:event][:route] = Route.find(params[:event][:route])
    event = Event.new(require_params)
    event.route = params[:event][:route]
    participant = Participant.new
    if event.save
      participant.user = current_user
      participant.event = event
      participant.save
      redirect_to event_path(event)
    else
      render profile_path
    end
  end
  
  private
  def require_params
    params.require(:event).permit([:title, :description, :starttime, :route, :photo])
  end
end
