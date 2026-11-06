defmodule Aesir.ZoneServer.Content.Npc.Functions.FFatherrub do
  @moduledoc """
  Priest pilgrimage guide at the prt_fild03 checkpoint.

  ## Behavior

  A trainee on the first leg of the pilgrimage hears Father Rubalkabara's blessing, has their
  respawn point saved at the checkpoint and advances to the second leg. Later legs send them on
  their way, and anyone without the pilgrimage quest is turned away.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Lupus

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script jobs/2-1/priest.txt
  - LLM-assisted Elixir refactor
  """

  import Aesir.ZoneServer.Script.Dsl

  alias Aesir.ZoneServer.Script.Ctx

  @doc "Callable rAthena global function `F_FatherRub`; throws `{:script_end, ctx}`."
  @spec call(Ctx.t(), [term()]) :: no_return()
  def call(ctx, _args) do
    case get_char_var(ctx, :PRIEST_Q, 0) do
      0 -> halt(turned_away(ctx))
      1 -> halt(first_leg(ctx))
      2 -> halt(next_leg(ctx))
      _other -> halt(returned(ctx))
    end
  end

  defp first_leg(ctx) do
    ctx
    |> mes("Ah yes, so you're the young Acolyte who wishes to become a Priest.")
    |> next()
    |> mes("[Father Rubalkabara]")
    |> mes(
      "I've received the message from Bishop Paul. Since you made the pilgrimage, I hope you accomplish your goal of becoming a Priest."
    )
    |> next()
    |> mes("[Father Rubalkabara]")
    |> mes(
      "Also, if you have a chance, please visit this abbey again. It's a sacred place for our Church."
    )
    |> next()
    |> mes("[Father Rubalkabara]")
    |> mes(
      "Well then, please head to your next destination for your pilgrimage. Be safe in your travels."
    )
    |> close()
    |> savepoint("prt_fild03", 361, 255)
    |> set_char_var(:PRIEST_Q, 2)
  end

  defp next_leg(ctx) do
    ctx
    |> mes(
      "Please be hurry to the next destination for your pilgrimage. I hope you become a Priest soon."
    )
    |> close()
  end

  defp returned(ctx) do
    ctx
    |> mes(
      "May I ask why you have returned? Please go back and continue your religious practice."
    )
    |> close()
  end

  defp turned_away(ctx) do
    ctx
    |> mes("I have no idea what brought you here, but please excuse me.")
    |> close()
  end

  defp halt(ctx), do: throw({:script_end, ctx})
end
