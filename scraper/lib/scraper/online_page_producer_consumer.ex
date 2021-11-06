defmodule OnlinePageProducerConsumer do
  use GenStage
  require Logger

  def start_link(id) do
    GenStage.start_link(__MODULE__, [], name: via(id))
  end

  @impl true
  def init(state) do
    Logger.info("OnlinePageProducerConsumer init")

    subscriptions = [
      {PageProducer, min_demand: 0, max_demand: 1}
    ]

    {:producer_consumer, state, subscribe_to: subscriptions}
  end

  @impl true
  def handle_events(events, _from, state) do
    Logger.info("OnlinePageProducerConsumer received #{inspect(events)}")

    events = Enum.filter(events, &Scraper.online?/1)

    {:noreply, events, state}
  end

  def via(id) do
    {:via, Registry, {ScraperRegistry, id}}
  end
end
