defmodule Aesir.ZoneServer.Content.Npc.Functions.FMothermart do
  @moduledoc """
  Priest pilgrimage guide at the moc_fild07 checkpoint.

  ## Behavior

  A trainee on the first leg is sent back to the people who briefed them. On the second leg Mother
  Mathilda explains the Priest's duty, saves the respawn point at the checkpoint and advances the
  pilgrimage to its third leg. Later legs and characters without the quest are turned away.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Lupus

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script jobs/2-1/priest.txt
  - LLM-assisted Elixir refactor
  """

  import Aesir.ZoneServer.Script.Dsl

  alias Aesir.ZoneServer.Script.Ctx

  @doc "Callable rAthena global function `F_MotherMart`; throws `{:script_end, ctx}`."
  @spec call(Ctx.t(), [term()]) :: no_return()
  def call(ctx, _args) do
    case get_char_var(ctx, :PRIEST_Q, 0) do
      0 -> halt(turned_away(ctx))
      1 -> halt(wrong_checkpoint(ctx))
      2 -> halt(second_leg(ctx))
      3 -> halt(next_leg(ctx))
      _other -> halt(returned(ctx))
    end
  end

  defp wrong_checkpoint(ctx) do
    ctx
    |> mes("Hmm...")
    |> mes("It seems you're")
    |> mes("training to become")
    |> mes("a Priest.")
    |> next()
    |> mes("[Mother Mathilda]")
    |> mes(
      "However, at this point in your pilgrimage, I am not the person that you should be visiting."
    )
    |> next()
    |> mes("[Mother Mathilda]")
    |> mes(
      "Perhaps you should ask Bishop Paul or Sister Cecilia once again. Well, may God be with you..."
    )
    |> close()
  end

  defp second_leg(ctx) do
    ctx
    |> mes("Ah, are you")
    |> mes("a Priest trainee...?")
    |> mes("Welcome!")
    |> next()
    |> mes("[Mother Mathilda]")
    |> mes("We Priests are obliged to spread the message of God to")
    |> mes("the peoples of the Earth.")
    |> next()
    |> mes("[Mother Mathilda]")
    |> mes(
      "After you become a Priest, your travels may take you to the Morocc Pyramids. I hope that you may release the Undead there from the evil to which they are bound."
    )
    |> next()
    |> mes("[Mother Mathilda]")
    |> mes("Well then...")
    |> mes("I shall pray to")
    |> mes("God for safety")
    |> mes("on your journey.")
    |> close()
    |> savepoint("moc_fild07", 35, 355)
    |> set_char_var(:PRIEST_Q, 3)
  end

  defp next_leg(ctx) do
    ctx
    |> mes("Please leave soon, and")
    |> mes("continue your training.")
    |> close()
  end

  defp returned(ctx) do
    ctx
    |> mes("May I ask you the reason you came back? Please continue your training.")
    |> close()
  end

  defp turned_away(ctx) do
    ctx
    |> mes("May God")
    |> mes("be with you...")
    |> close()
  end

  defp halt(ctx), do: throw({:script_end, ctx})
end
