defmodule PageProducer do
  use GenStage
  require Logger

  def start_link(_args) do
    GenStage.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(state) do
    Logger.info("PageProducer init")
    {:producer, state}
  end

  def handle_cast({:pages, pages}, state) do
    {:noreply, pages, state}
  end

  def handle_demand(demand, state) do
    Logger.info("PageProducer received demand for #{demand} pages")
    {:noreply, [], state}
  end

  def scrape_pages(pages) when is_list(pages) do
    GenStage.cast(__MODULE__, {:pages, pages})
  end
end
