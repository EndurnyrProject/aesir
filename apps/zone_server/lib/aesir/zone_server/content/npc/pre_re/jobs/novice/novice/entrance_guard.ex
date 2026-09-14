defmodule Aesir.ZoneServer.Content.Npc.PreRe.Jobs.Novice.Novice.EntranceGuard do
  @moduledoc """
  Controls entry to novice field combat training and handles retry supplies.

  ## Behavior

  - Requires combat instruction before admitting a trainee.
  - Provides first-attempt supplies and handles supplied or healed retries.
  - Sets the training savepoint and transfers trainees to the combat grounds.

  ## Credits

  - Original from rAthena, authors: Dr.Evil and MasterOfMuppets.
  - Elixir adaptation: transpiled and refactored by an LLM.
  """

  use Aesir.ZoneServer.Npc,
    scope: :pre_renewal,
    spawn: [
      %{
        map: "new_1-2",
        x: 38,
        y: 182,
        dir: 3,
        sprite: 92,
        name: "Entrance Guard",
        unique_name: "Entrance Guard#nv"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    state = get_char_var(ctx, :nov_2nd_cos, 0)

    cond do
      state == 0 -> deny_entry(ctx)
      state in 1..20 -> offer_first_attempt(ctx, state)
      state in 21..30 -> offer_supplied_retry(ctx, state)
      state > 30 -> offer_healed_retry(ctx)
      true -> ctx
    end
  end

  defp deny_entry(ctx) do
    ctx
    |> mes("[Muriel]")
    |> mes(
      "I'm sorry, but I can't let anybody who hasn't been instructed on fighting enter the Field Combat Training Grounds."
    )
    |> next()
    |> mes("[Muriel]")
    |> mes(
      "Why don't you speak to the Helper to the left side of this room first, so that you can receive some battle instruction?"
    )
    |> close()
  end

  defp offer_first_attempt(ctx, state) do
    {ctx, choice} =
      ctx
      |> mes("[Muriel]")
      |> mes(
        "Field Combat Training is an actual fight class where you can gain basic fighting skills that you can use to defend yourself in Midgard."
      )
      |> next()
      |> mes("[Muriel]")
      |> mes(
        "Please kill as many monsters as you can to increase your base level at least 2 times."
      )
      |> next()
      |> mes("[Muriel]")
      |> mes(
        "Gaining 2 base levels is required to complete your Field Combat Training. Although the monsters are all weak and easy to kill, I hope you will be careful."
      )
      |> next()
      |> mes("[Muriel]")
      |> mes("Do you wish")
      |> mes("to take the test")
      |> mes("right away?")
      |> next()
      |> select(["Yes", "I need more time."])

    case choice do
      1 -> begin_first_attempt(ctx, state)
      2 -> ask_to_return_when_ready(ctx, :first_attempt)
      _ -> close(ctx)
    end
  end

  defp begin_first_attempt(ctx, state) do
    ctx
    |> mes("[Muriel]")
    |> mes("Please make sure you")
    |> mes(
      "talk to the staff at the North after you increase your base level by 2 levels through battle."
    )
    |> next()
    |> mes("[Muriel]")
    |> mes(
      "I'm going to give you some useful supplies, so please use them in case of an emergency."
    )
    |> set_first_attempt_state(state)
    |> give_item(602, 1)
    |> give_item(601, 9)
    |> give_item(1243, 1)
    |> give_item(2112, 1)
    |> give_item(611, 2)
    |> give_item(569, 300)
    |> close()
    |> savepoint("new_1-2", 23, 188)
    |> warp("new_1-3", 96, 21)
  end

  defp set_first_attempt_state(ctx, state) when state in 12..18,
    do: set_char_var(ctx, :nov_2nd_cos, state + 10)

  defp set_first_attempt_state(ctx, _state), do: set_char_var(ctx, :nov_2nd_cos, 29)

  defp offer_supplied_retry(ctx, state) do
    {ctx, choice} =
      ctx
      |> mes("[Muriel]")
      |> mes("Oh well, I told you to be careful. Cheer up! It's not a big deal.")
      |> mes(" ")
      |> mes("Failure teaches success.")
      |> mes("You have many chances")
      |> mes("to re-take the test.")
      |> next()
      |> mes("[Muriel]")
      |> mes("Do you wish")
      |> mes("to try again?")
      |> next()
      |> select(["Yes.", "Can I have more time?"])

    case choice do
      1 -> begin_supplied_retry(ctx, state)
      2 -> ask_to_return_when_ready(ctx, :supplied_retry)
      _ -> ctx
    end
  end

  defp begin_supplied_retry(ctx, state) do
    ctx
    |> mes("[Muriel]")
    |> mes("I will give you")
    |> mes("some supplies again.")
    |> mes("Please be careful!")
    |> advance_retry(state)
    |> percent_heal(hp: 100, sp: 0)
    |> give_item(569, 50)
    |> close()
    |> warp("new_1-3", 96, 21)
  end

  defp advance_retry(ctx, 22), do: ctx |> set_char_var(:nov_2nd_cos, 33) |> getexp(16, 0)
  defp advance_retry(ctx, 23), do: ctx |> set_char_var(:nov_2nd_cos, 34) |> getexp(25, 0)
  defp advance_retry(ctx, 24), do: ctx |> set_char_var(:nov_2nd_cos, 35) |> getexp(36, 0)
  defp advance_retry(ctx, 25), do: ctx |> set_char_var(:nov_2nd_cos, 36) |> getexp(77, 0)
  defp advance_retry(ctx, 26), do: ctx |> set_char_var(:nov_2nd_cos, 37) |> getexp(112, 0)
  defp advance_retry(ctx, 27), do: ctx |> set_char_var(:nov_2nd_cos, 38) |> getexp(153, 0)
  defp advance_retry(ctx, 28), do: ctx |> set_char_var(:nov_2nd_cos, 39) |> getexp(200, 0)
  defp advance_retry(ctx, 29), do: ctx |> set_char_var(:nov_2nd_cos, 40) |> getexp(200, 0)
  defp advance_retry(ctx, _state), do: ctx

  defp offer_healed_retry(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Muriel]")
      |> mes("Oh well, I told you to be careful. Cheer up! It's not a big deal.")
      |> mes(" ")
      |> mes("Failure teaches success.")
      |> mes("You have many chances to re-take the test.")
      |> next()
      |> mes("[Muriel]")
      |> mes("Do you wish to try again?")
      |> next()
      |> select(["Yes", "Can I have more time?"])

    case choice do
      1 -> begin_healed_retry(ctx)
      2 -> ask_to_return_when_ready(ctx, :healed_retry)
      _ -> ctx
    end
  end

  defp begin_healed_retry(ctx) do
    ctx
    |> mes("[Muriel]")
    |> mes("I will restore")
    |> mes("your HP. Please")
    |> mes("be careful!")
    |> percent_heal(hp: 100, sp: 0)
    |> close()
    |> warp("new_1-3", 96, 21)
  end

  defp ask_to_return_when_ready(ctx, :first_attempt) do
    ctx
    |> mes("[Muriel]")
    |> mes("No problem.")
    |> mes(
      "If you're not sure if you can pass the test or not, why don't you go talk to the Helper to the left one more time? Please come back"
    )
    |> mes("when you're ready.")
    |> close()
  end

  defp ask_to_return_when_ready(ctx, :supplied_retry),
    do: ask_to_return_when_ready(ctx, :first_attempt)

  defp ask_to_return_when_ready(ctx, :healed_retry) do
    ctx
    |> mes("[Muriel]")
    |> mes("No problem.")
    |> mes(
      "If you're not sure if you can pass the test or not, why don't you go talk to the Helper to the left one more time? Please come back when you're ready."
    )
    |> close()
  end
end
