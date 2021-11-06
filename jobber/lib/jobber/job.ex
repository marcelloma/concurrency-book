defmodule Jobber.Job do
  use GenServer, restart: :transient
  require Logger

  defstruct [:work, :id, :max_retries, retries: 0, status: "new"]

  def start_link(args) do
    args = Keyword.put_new(args, :id, random_job_id())
    id = Keyword.get(args, :id)
    type = Keyword.get(args, :type)

    GenServer.start_link(__MODULE__, args, name: via(id, type))
  end

  @impl true
  def init(args) do
    id = Keyword.fetch!(args, :id)
    work = Keyword.fetch!(args, :work)
    max_retries = Keyword.get(args, :max_retries, 3)

    state = %Jobber.Job{id: id, work: work, max_retries: max_retries}

    {:ok, state, {:continue, :run}}
  end

  @impl true
  def handle_continue(:run, state) do
    state =
      state.work.()
      |> handle_job_result(state)

    if state.status == "errored" do
      Process.send_after(self(), :retry, 5000)
      {:noreply, state}
    else
      Logger.info("Job exiting: #{state.id}")
      {:stop, :normal, state}
    end
  end

  @impl true
  def handle_info(:retry, state) do
    {:noreply, state, {:continue, :run}}
  end

  defp handle_job_result({:ok, _data}, state) do
    Logger.info("Job completed: #{state.id}")

    Map.put(state, :status, "done")
  end

  defp handle_job_result(:error, %{status: "new"} = state) do
    Logger.warn("Job errored: #{state.id}")

    Map.put(state, :status, "errored")
  end

  defp handle_job_result(:error, %{status: "errored"} = state) do
    Logger.warn("Job retry failed: #{state.id}")

    state
    |> inc_retries()
    |> check_for_failure()
  end

  defp random_job_id() do
    :crypto.strong_rand_bytes(5)
    |> Base.url_encode64(padding: false)
  end

  defp check_for_failure(state) do
    if state.retries == state.max_retries,
      do: Map.put(state, :status, "failed"),
      else: state
  end

  defp inc_retries(state) do
    Map.put(state, :retries, &Kernel.+(&1, 1))
  end

  defp via(key, value) do
    {:via, Registry, {Jobber.JobRegistry, key, value}}
  end
end
