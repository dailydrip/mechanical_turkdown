defmodule MechanicalTurkdown.Worker do
  @moduledoc """
  A module to help provide a synchronous interface to Mechanical Turkdown jobs.
  """

  use GenServer
  alias MechanicalTurkdown.MechanicalTurk

  # Client
  def start_link(markdown) do
    # We'll start off in a `creating` state
    GenServer.start_link(__MODULE__, {:creating, markdown})
  end

  @doc """
  A synchronous call that waits indefinitely for the Mechanical Turk HIT to have
  an assignment, then returns the HTML that was sent as the response to the
  assignment.
  """
  def check(pid) do
    # We'll call `check` on the server, then use a case statement on the response.
    reply = GenServer.call(pid, :check)
    case reply do
      :waiting ->
        # If we're still waiting, we'll check again in a second
        IO.puts "waiting!"
        Process.sleep 1_000
        check(pid)
      {:finished, html} ->
        # If we finished, we'll return the html we got back
        GenServer.stop(pid)
        IO.puts "finished!"
        to_string(html)
      other -> IO.puts "Oops, got a weird response: #{inspect other}"
    end
  end

  @doc """
  Create a worker and check for a result in a single function.
  """
  def submit_markdown(markdown) do
    # This is just an API to make it trivial to use this GenServer as a very
    # long-running function
    {:ok, pid} = start_link(markdown)
    check(pid)
  end

  # Server
  def init(state) do
    # When we initialize the server, we'll send ourselves a message that we'll
    # handle in a `handle_info` later
    send(self, :after_init)
    {:ok, state}
  end

  # When we're creating, we'll submit the work and set a timer to check its
  # results.
  def handle_info(:after_init, {:creating, markdown}) do
    IO.puts "Submitting markdown"
    hit_details = MechanicalTurk.submit_markdown(markdown)
    Process.send_after(self(), :check_assignments, 1_000)
    {:noreply, {:checking, hit_details[:hit_id]}}
  end
  def handle_info(:check_assignments, {:checking, hit_id}) do
    # When we're checking the results, we'll use a case statement on the number
    # of results - once we have one, we'll auto-accept it and return its value
    IO.puts "checking assignments"
    assignments = MechanicalTurk.get_assignments(hit_id)
    case assignments[:num_results] do
      0 ->
        # If we have no results yet, we'll create a timer to check assignments
        # again in a bit.
        IO.puts "no results, still waiting!"
        Process.send_after(self(), :check_assignments, 1_000)
        {:noreply, {:checking, hit_id}}
      _ ->
        # If we had results, we'll approve the assignment and then switch to a
        # `completed` state, collecting the returned html.
        IO.puts "got a result!"
        assignment = hd(assignments[:assignments])
        assignment[:assignment_id] |> MechanicalTurk.approve
        IO.puts "approved the result!"
        {_, _, html, _, _, _} = hd(assignment[:answers])
        {:noreply, {:completed, html}}
    end
  end

  def handle_call(:check, _from, {:completed, html}) do
    # If we had completed the work, we'll reply with it.
    {:reply, {:finished, html}, :finished}
  end
  def handle_call(:check, _from, state) do
    # Otherwise, we'll reply that we're waiting and leave the state unmodified.
    {:reply, :waiting, state}
  end
end
