defmodule MechanicalTurkdown.MechanicalTurk do
  @moduledoc """
  A module for interacting with MechanicalTurk for our specific tasks.
  """

  # We have to interact with the mturk_hit record from the erlcloud library, so
  # we'll extract it.
  require Record
  import Record, only: [defrecord: 2, extract: 2]

  defrecord :mturk_hit, extract(:mturk_hit, from_lib: "erlcloud/include/erlcloud_mturk.hrl")
  defrecord :mturk_money, extract(:mturk_money, from_lib: "erlcloud/include/erlcloud_mturk.hrl")
  defrecord :mturk_qualification_requirement, extract(:mturk_qualification_requirement, from_lib: "erlcloud/include/erlcloud_mturk.hrl")
  defrecord :mturk_question, extract(:mturk_question, from_lib: "erlcloud/include/erlcloud_mturk.hrl")
  defrecord :mturk_question_form, extract(:mturk_question_form, from_lib: "erlcloud/include/erlcloud_mturk.hrl")
  defrecord :mturk_free_text_answer, extract(:mturk_free_text_answer, from_lib: "erlcloud/include/erlcloud_mturk.hrl")
  defrecord :aws_config, extract(:aws_config, from_lib: "erlcloud/include/erlcloud_aws.hrl")

  @doc """
  Submit a HIT for a markdown to html translation, because it's a totally
  reasonable thing to do.
  """
  @spec submit_markdown(String.t) :: list()
  def submit_markdown(markdown) do
    markdown
      |> markdown_conversion_hit
      |> :erlcloud_mturk.create_hit(mturk_config())
  end

  @doc """
  Get the assignments for the HIT we submitted earlier.
  """
  # NOTE: We aren't handling "elixir-ifying" the API, but we probably should.
  @spec get_assignments(charlist()) :: list()
  def get_assignments(hit_id) do
    :erlcloud_mturk.get_assignments_for_hit(to_charlist(hit_id), mturk_config())
  end

  @doc """
  Approve the assignment with the given assignment_id
  """
  @spec approve(charlist()) :: :ok
  def approve(assignment_id) do
    assignment_id
      |> :erlcloud_mturk.approve_assignment('', mturk_config())
  end

  @doc false
  def mturk_config() do
    aws_config(
      # NOTE: We should really get these from Application.get_env ultimately
      access_key_id: System.get_env("AWS_ACCESS_KEY_ID"),
      secret_access_key: System.get_env("AWS_SECRET_ACCESS_KEY"),
      # NOTE: And we would put this in Application.get_env so we could switch
      # per-env configuration easily, as well as support changing it with
      # conform
      mturk_host: 'mechanicalturk.sandbox.amazonaws.com'
    )
  end

  defp markdown_conversion_hit(markdown) do
    mturk_hit(
      reward: mturk_money(
        amount: '0.01',
        currency_code: 'USD',
        formatted_price: '$0.01'
      ),
      lifetime_in_seconds: 60 * 60, # 1 hour
      assignment_duration_in_seconds: 60 * 60, # 1 hour
      title: 'convert some markdown to html',
      description: 'convert some markdown to html',
      keywords: ['transcription'],
      question: mturk_question_form(
        content: [
          mturk_question(
            question_identifier: 'mturkdown1',
            display_name: 'some display name',
            question_content: [
              {:text, to_charlist(markdown)}
            ],
            answer_specification: mturk_free_text_answer(
              number_of_lines_suggestion: 40
            )
          )
        ]
      )
    )
  end
end
