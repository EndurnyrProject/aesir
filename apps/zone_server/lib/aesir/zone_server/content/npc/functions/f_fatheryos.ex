defmodule Aesir.ZoneServer.Content.Npc.Functions.FFatheryos do
  @moduledoc """
  Priest pilgrimage guide at the prt_fild00 checkpoint.

  ## Behavior

  Earlier legs send the trainee back to the church, since Father Yosuke is not the person they
  should visit yet. On the third leg he saves the respawn point at the checkpoint, advances the
  pilgrimage to its fourth leg and declares the first trial complete. Later legs and characters
  without the quest are turned away.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Lupus

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script jobs/2-1/priest.txt
  - LLM-assisted Elixir refactor
  """

  import Aesir.ZoneServer.Script.Dsl

  alias Aesir.ZoneServer.Script.Ctx

  @doc "Callable rAthena global function `F_FatherYos`; throws `{:script_end, ctx}`."
  @spec call(Ctx.t(), [term()]) :: no_return()
  def call(ctx, _args) do
    case get_char_var(ctx, :PRIEST_Q, 0) do
      0 -> halt(turned_away(ctx))
      1 -> halt(send_back(ctx, ["But that's your own fault.", "Now, go back to Church, kid."]))
      2 -> halt(send_back(ctx, ["But that's your own fault. Go back to Church."]))
      3 -> halt(third_leg(ctx))
      4 -> halt(completed(ctx))
      _other -> halt(sent_away(ctx))
    end
  end

  defp send_back(ctx, closings) do
    ctx
    |> mes("Hmm...")
    |> mes("A Priest trainee, eh?")
    |> next()
    |> mes("[Father Yosuke]")
    |> mes(
      "Well, you got the wrong person. If you're supposed to meet up with me at all, it'd be later."
    )
    |> next()
    |> mes("[Father Yosuke]")
    |> then(fn ctx -> Enum.reduce(closings, ctx, &mes(&2, &1)) end)
    |> close()
  end

  defp third_leg(ctx) do
    ctx
    |> mes("Hmm.")
    |> mes("A Priest")
    |> mes("trainee, eh? ")
    |> mes("Welcome.")
    |> next()
    |> mes("[Father Yosuke]")
    |> mes("I won't say")
    |> mes("anything more.")
    |> mes("Just devote your")
    |> mes("life to God.")
    |> next()
    |> mes("[Father Yosuke]")
    |> mes("Now go back to church.")
    |> mes("Hereby, the first of")
    |> mes("your trials is now")
    |> mes("completed.")
    |> close()
    |> savepoint("prt_fild00", 206, 230)
    |> set_char_var(:PRIEST_Q, 4)
  end

  defp completed(ctx) do
    ctx
    |> mes("I told you to go back to church.")
    |> mes("Or do you want to live with me here for the rest of your life...?")
    |> close()
  end

  defp sent_away(ctx) do
    ctx
    |> mes("Just go be a Priest. This isn't a playground for kids.")
    |> close()
  end

  defp turned_away(ctx) do
    ctx
    |> mes("...Acolyte, you don't have any business with me here.")
    |> close()
  end

  defp halt(ctx), do: throw({:script_end, ctx})
end
